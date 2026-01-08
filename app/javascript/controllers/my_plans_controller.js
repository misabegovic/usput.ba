import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "empty", "list"]

  static values = {
    plansKey: { type: String, default: "visitumo_plans" },
    activePlanKey: { type: String, default: "visitumo_active_plan" }
  }

  connect() {
    this.loadPlans()
  }

  loadPlans() {
    const plans = this.getPlans()

    if (plans.length === 0) {
      this.showEmpty()
      return
    }

    this.renderPlans(plans)
    this.showList()
  }

  getPlans() {
    try {
      const data = localStorage.getItem(this.plansKeyValue)
      if (data) {
        return JSON.parse(data)
      }

      // Migrate from old format
      const oldPlan = localStorage.getItem("visitumo_plan")
      if (oldPlan) {
        const plan = JSON.parse(oldPlan)
        const plans = [plan]
        localStorage.setItem(this.plansKeyValue, JSON.stringify(plans))
        localStorage.removeItem("visitumo_plan")
        return plans
      }

      return []
    } catch {
      return []
    }
  }

  // Extract all unique cities from a plan's experiences
  extractCities(plan) {
    const cities = new Set()

    // Try to get cities from experiences' locations
    if (plan.days && Array.isArray(plan.days)) {
      plan.days.forEach(day => {
        if (day.experiences && Array.isArray(day.experiences)) {
          day.experiences.forEach(exp => {
            if (exp.locations && Array.isArray(exp.locations)) {
              exp.locations.forEach(loc => {
                if (loc.city) cities.add(loc.city)
              })
            }
          })
        }
      })
    }

    // Fallback to plan's city_name if no cities found from experiences
    if (cities.size === 0) {
      const fallbackCity = plan.city_name || plan.city?.display_name || plan.city?.name
      if (fallbackCity) cities.add(fallbackCity)
    }

    return Array.from(cities)
  }

  // Format cities for display (show first 2, then +N)
  formatCities(cities) {
    if (cities.length === 0) return 'Nepoznat grad'
    if (cities.length <= 2) return cities.join(', ')
    return `${cities.slice(0, 2).join(', ')} <span class="text-gray-400 dark:text-gray-500">+${cities.length - 2}</span>`
  }

  renderPlans(plans) {
    if (!this.hasListTarget) return

    const activePlanId = localStorage.getItem(this.activePlanKeyValue)

    this.listTarget.innerHTML = plans.map(plan => {
      const isActive = plan.id === activePlanId
      const cities = this.extractCities(plan)
      const citiesDisplay = this.formatCities(cities)
      const primaryCity = cities[0] || 'Nepoznat grad'
      const daysWord = plan.duration_days === 1 ? 'dan' : 'dana'
      const expCount = plan.total_experiences || 0
      // Use custom_title if available, otherwise default to city - days format
      const displayTitle = plan.custom_title && plan.custom_title.trim()
        ? plan.custom_title
        : `${primaryCity} - ${plan.duration_days} ${daysWord}`

      return `
        <a href="/plans/view?id=${plan.id}"
           class="group block bg-gray-50 dark:bg-gray-700/50 rounded-xl p-4 hover:bg-teal-50 dark:hover:bg-teal-900/20 transition-all hover:shadow-md border border-transparent hover:border-teal-200 dark:hover:border-teal-800 ${isActive ? 'ring-2 ring-teal-500' : ''}"
           data-action="click->my-plans#setActivePlan"
           data-plan-id="${plan.id}">
          <div class="flex items-start gap-4">
            <!-- City icon/badge -->
            <div class="flex-shrink-0 w-12 h-12 bg-gradient-to-br from-teal-500 to-emerald-600 rounded-xl flex items-center justify-center text-white shadow-sm">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
              </svg>
            </div>

            <!-- Plan info -->
            <div class="flex-1 min-w-0">
              <!-- Title -->
              <h3 class="font-semibold text-gray-900 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors line-clamp-1">
                ${displayTitle}
              </h3>

              <!-- City name(s) -->
              <p class="text-sm text-gray-600 dark:text-gray-300 mt-0.5 truncate">
                <svg class="w-3.5 h-3.5 inline mr-1 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                </svg>
                ${citiesDisplay}
              </p>

              <!-- Meta info row -->
              <div class="flex items-center gap-3 mt-2 text-xs text-gray-500 dark:text-gray-400">
                <!-- Duration -->
                <span class="inline-flex items-center">
                  <svg class="w-3.5 h-3.5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                  </svg>
                  ${plan.duration_days} ${daysWord}
                </span>

                <!-- Experiences count -->
                ${expCount > 0 ? `
                  <span class="inline-flex items-center">
                    <svg class="w-3.5 h-3.5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    ${expCount} aktivnosti
                  </span>
                ` : ''}

                <!-- Active badge -->
                ${isActive ? `
                  <span class="inline-flex items-center text-teal-600 dark:text-teal-400">
                    <svg class="w-3.5 h-3.5 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                    </svg>
                    Aktivan
                  </span>
                ` : ''}
              </div>
            </div>

            <!-- Arrow indicator -->
            <div class="flex-shrink-0 text-gray-400 dark:text-gray-500 group-hover:text-teal-500 dark:group-hover:text-teal-400 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
              </svg>
            </div>
          </div>

          <!-- Footer with date and delete -->
          <div class="mt-3 pt-3 border-t border-gray-200 dark:border-gray-600 flex items-center justify-between">
            <span class="text-xs text-gray-400 dark:text-gray-500">
              Kreirano ${this.formatDate(plan.generated_at)}
            </span>
            <button type="button"
                    class="text-red-500 hover:text-red-600 dark:text-red-400 dark:hover:text-red-300 p-1"
                    data-action="click->my-plans#deletePlan"
                    data-plan-id="${plan.id}"
                    title="Obriši plan">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              </svg>
            </button>
          </div>
        </a>
      `
    }).join('')
  }

  formatDate(dateString) {
    if (!dateString) return ''
    try {
      const date = new Date(dateString)
      return date.toLocaleDateString('hr-HR', {
        day: 'numeric',
        month: 'long',
        year: 'numeric'
      })
    } catch {
      return ''
    }
  }

  setActivePlan(event) {
    const planId = event.currentTarget.dataset.planId
    if (planId) {
      localStorage.setItem(this.activePlanKeyValue, planId)
    }
  }

  async deletePlan(event) {
    event.preventDefault()
    event.stopPropagation()

    const planId = event.currentTarget.dataset.planId
    if (!planId) return

    if (!confirm('Jeste li sigurni da želite obrisati ovaj plan?')) {
      return
    }

    try {
      let plans = this.getPlans()
      const planToDelete = plans.find(p => p.id === planId)

      // If plan is synced/shared to database, delete it there too
      if (planToDelete) {
        const isInDatabase = planToDelete.uuid || planToDelete.synced || planToDelete.shared
        const isLoggedIn = document.querySelector('meta[name="user-logged-in"]')?.content === 'true'

        if (isInDatabase && isLoggedIn) {
          const serverPlanId = planToDelete.uuid || planToDelete.id
          try {
            const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
            await fetch(`/user/plans/${serverPlanId}`, {
              method: "DELETE",
              headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {}
            })
          } catch (e) {
            console.error("Server delete error:", e)
          }
        }
      }

      plans = plans.filter(p => p.id !== planId)
      localStorage.setItem(this.plansKeyValue, JSON.stringify(plans))

      // Update active plan if needed
      const activePlanId = localStorage.getItem(this.activePlanKeyValue)
      if (activePlanId === planId) {
        if (plans.length > 0) {
          localStorage.setItem(this.activePlanKeyValue, plans[0].id)
        } else {
          localStorage.removeItem(this.activePlanKeyValue)
        }
      }

      this.loadPlans()
    } catch (error) {
      console.error("Failed to delete plan:", error)
    }
  }

  showEmpty() {
    if (this.hasContainerTarget) this.containerTarget.classList.add("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
    if (this.hasListTarget) this.listTarget.classList.add("hidden")
  }

  showList() {
    if (this.hasContainerTarget) this.containerTarget.classList.remove("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    if (this.hasListTarget) this.listTarget.classList.remove("hidden")
  }
}
