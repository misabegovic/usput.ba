import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["addButton", "noplanMessage", "hasplanMessage", "feedback", "planSelector"]

  static values = {
    plansKey: { type: String, default: "visitumo_plans" },
    activePlanKey: { type: String, default: "visitumo_active_plan" },
    experienceId: Number,
    experienceTitle: String,
    experienceDescription: String,
    experienceDuration: String
  }

  connect() {
    this.allPlans = []
    this.selectedPlanId = null
    this.loadPlans()
    this.checkForExistingPlan()
  }

  loadPlans() {
    try {
      const data = localStorage.getItem(this.plansKeyValue)
      if (data) {
        this.allPlans = JSON.parse(data)
      } else {
        // Migrate from old single-plan format
        const oldPlan = localStorage.getItem("visitumo_plan")
        if (oldPlan) {
          const plan = JSON.parse(oldPlan)
          this.allPlans = [plan]
          // Save in new format
          localStorage.setItem(this.plansKeyValue, JSON.stringify(this.allPlans))
          localStorage.setItem(this.activePlanKeyValue, plan.id)
          // Clean up old format
          localStorage.removeItem("visitumo_plan")
        } else {
          this.allPlans = []
        }
      }

      // Get active plan ID
      this.selectedPlanId = localStorage.getItem(this.activePlanKeyValue)
      if (!this.selectedPlanId && this.allPlans.length > 0) {
        this.selectedPlanId = this.allPlans[0].id
      }
    } catch (error) {
      console.error("Failed to load plans:", error)
      this.allPlans = []
    }
  }

  checkForExistingPlan() {
    const hasPlans = this.allPlans.length > 0 && this.allPlans.some(p => p.days && p.days.length > 0)

    if (hasPlans) {
      // User has existing plans
      if (this.hasNoplanMessageTarget) {
        this.noplanMessageTarget.classList.add("hidden")
      }
      if (this.hasHasplanMessageTarget) {
        this.hasplanMessageTarget.classList.remove("hidden")
      }

      // Render plan selector if multiple plans
      if (this.allPlans.length > 1) {
        this.renderPlanSelector()
      }
    } else {
      // No existing plan
      if (this.hasNoplanMessageTarget) {
        this.noplanMessageTarget.classList.remove("hidden")
      }
      if (this.hasHasplanMessageTarget) {
        this.hasplanMessageTarget.classList.add("hidden")
      }
    }
  }

  renderPlanSelector() {
    if (!this.hasPlanSelectorTarget) return

    const selectorHtml = `
      <div class="mb-3">
        <label class="block text-white/80 text-sm mb-2">Odaberi plan:</label>
        <select data-action="change->add-to-plan#selectPlan"
                class="w-full px-3 py-2 rounded-lg bg-white text-gray-900 border border-white/30 focus:border-white focus:outline-none focus:ring-2 focus:ring-white/50">
          ${this.allPlans.map(plan => `
            <option value="${plan.id}" ${plan.id === this.selectedPlanId ? 'selected' : ''} class="text-gray-900 bg-white">
              ${plan.city?.display_name || plan.city?.name || 'Plan'} - ${plan.duration_days} ${plan.duration_days === 1 ? 'dan' : 'dana'}
            </option>
          `).join('')}
        </select>
      </div>
    `
    this.planSelectorTarget.innerHTML = selectorHtml
    this.planSelectorTarget.classList.remove("hidden")
  }

  selectPlan(event) {
    this.selectedPlanId = event.target.value
  }

  getSelectedPlan() {
    if (!this.selectedPlanId) return this.allPlans[0]
    return this.allPlans.find(p => p.id === this.selectedPlanId) || this.allPlans[0]
  }

  addToPlan() {
    const plan = this.getSelectedPlan()

    if (!plan || !plan.days || plan.days.length === 0) {
      this.showFeedback("Nemate postojeći plan. Kreirajte novi plan prvo.", "error")
      return
    }

    // Check if experience is already in this plan
    const alreadyInPlan = plan.days.some(day =>
      day.experiences && day.experiences.some(exp => exp.id === this.experienceIdValue)
    )

    if (alreadyInPlan) {
      this.showFeedback("Ovo iskustvo je već u odabranom planu.", "warning")
      return
    }

    // Add experience to the first day
    const experience = {
      id: this.experienceIdValue,
      title: this.experienceTitleValue,
      description: this.experienceDescriptionValue,
      formatted_duration: this.experienceDurationValue,
      locations: []
    }

    if (!plan.days[0].experiences) {
      plan.days[0].experiences = []
    }
    plan.days[0].experiences.push(experience)

    // Update total count
    plan.total_experiences = plan.days.reduce(
      (sum, day) => sum + (day.experiences ? day.experiences.length : 0), 0
    )

    // Save all plans
    try {
      const planIndex = this.allPlans.findIndex(p => p.id === plan.id)
      if (planIndex !== -1) {
        this.allPlans[planIndex] = plan
      }
      localStorage.setItem(this.plansKeyValue, JSON.stringify(this.allPlans))

      const planName = plan.city?.display_name || plan.city?.name || 'plan'
      this.showFeedback(`Iskustvo je dodano u "${planName}"!`, "success")

      // Update button state
      if (this.hasAddButtonTarget) {
        this.addButtonTarget.disabled = true
        this.addButtonTarget.innerHTML = `
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
          Dodano u plan
        `
      }
    } catch (error) {
      console.error("Failed to save plan:", error)
      this.showFeedback("Greška pri spremanju. Pokušajte ponovo.", "error")
    }
  }

  showFeedback(message, type) {
    if (!this.hasFeedbackTarget) return

    const colors = {
      success: "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400",
      error: "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
      warning: "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400"
    }

    this.feedbackTarget.className = `mt-3 px-4 py-2 rounded-lg text-sm font-medium ${colors[type]}`
    this.feedbackTarget.textContent = message
    this.feedbackTarget.classList.remove("hidden")

    // Auto-hide after 4 seconds
    setTimeout(() => {
      this.feedbackTarget.classList.add("hidden")
    }, 4000)
  }
}
