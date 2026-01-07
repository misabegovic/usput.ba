import { Controller } from "@hotwired/stimulus"
import { planSyncService } from "services/plan_sync_service"

export default class extends Controller {
  static targets = [
    "loading",
    "empty",
    "content",
    "planTitle",
    "duration",
    "durationText",
    "experiencesCount",
    "generatedAt",
    "days",
    "sidebarCity",
    "sidebarDuration",
    "sidebarExperiences",
    "preferences",
    "preferencesList",
    "regenerateButton",
    "confirmModal",
    "confirmModalTitle",
    "recommendations",
    "recommendedExperiences",
    "recommendedExperiencesList",
    "similarPlans",
    "similarPlansList",
    "planSwitcher",
    "viewPublicButton",
    "visibilityButton",
    "visibilityIcon",
    "visibilityText",
    "visibilityModal",
    "visibilityModalIconContainer",
    "visibilityModalIcon",
    "visibilityModalTitle",
    "visibilityModalMessage",
    "visibilityLoginRequired",
    "visibilityLoginButton",
    "confirmVisibilityButton",
    "editTitleModal",
    "titleInput",
    // Notes targets
    "notesCard",
    "notesContent",
    "addNotesButton",
    "editNotesModal",
    "notesInput",
    // Statistics targets
    "statisticsCard",
    "statsTotalDuration",
    "statsAvgDaily",
    "statsDailyBreakdown"
  ]

  static values = {
    plansKey: { type: String, default: "visitumo_plans" },
    activePlanKey: { type: String, default: "visitumo_active_plan" },
    generateUrl: { type: String, default: "/plans/generate" },
    recommendationsUrl: { type: String, default: "/plans/recommendations" }
  }

  // Store current plan data for regeneration
  currentPlan = null
  allPlans = []

  // Store pending removal data for modal confirmation
  pendingRemoval = null

  connect() {
    // Check if URL has a specific plan ID to display
    this.checkUrlForPlanId()
    this.loadPlans()
    this.syncIfLoggedIn()
  }

  // Check URL for ?id= parameter and set as active plan
  checkUrlForPlanId() {
    const urlParams = new URLSearchParams(window.location.search)
    const planId = urlParams.get('id')
    if (planId) {
      // Set this plan as active before loading
      localStorage.setItem(this.activePlanKeyValue, planId)
    }
  }

  // Sync with backend if user is logged in
  async syncIfLoggedIn() {
    if (!planSyncService.isLoggedIn()) return

    try {
      const result = await planSyncService.syncPlans()
      if (result.success && result.plans) {
        this.allPlans = result.plans
        if (this.allPlans.length > 0) {
          const activePlanId = planSyncService.getActivePlanId()
          this.currentPlan = this.allPlans.find(p => p.id === activePlanId) || this.allPlans[0]
          this.renderPlanSwitcher()
          this.renderPlan(this.currentPlan)
          this.showContent()
        }
      }
    } catch (error) {
      console.error("Sync error:", error)
    }
  }

  // ============================================
  // Multi-plan storage helpers
  // ============================================

  loadPlans() {
    try {
      const plansData = localStorage.getItem(this.plansKeyValue)
      let parsedPlans = []

      if (plansData) {
        try {
          parsedPlans = JSON.parse(plansData)
        } catch (parseError) {
          console.error("Failed to parse plans from localStorage, clearing corrupted data:", parseError)
          localStorage.removeItem(this.plansKeyValue)
          localStorage.removeItem(this.activePlanKeyValue)
        }
      }

      // Validate and filter plans - remove any that are malformed
      this.allPlans = (parsedPlans || []).filter(plan => this.isValidPlan(plan))

      // If some plans were invalid, save the cleaned list
      if (parsedPlans && parsedPlans.length !== this.allPlans.length) {
        console.warn(`Removed ${parsedPlans.length - this.allPlans.length} invalid plan(s) from localStorage`)
        this.savePlans()
      }

      // Migrate from old single-plan format if needed
      if (this.allPlans.length === 0) {
        const oldPlan = localStorage.getItem("visitumo_plan")
        if (oldPlan) {
          try {
            const plan = JSON.parse(oldPlan)
            if (this.isValidPlan(plan)) {
              this.allPlans = [plan]
              this.savePlans()
              localStorage.removeItem("visitumo_plan")
            }
          } catch (e) {
            console.error("Failed to migrate old plan format:", e)
            localStorage.removeItem("visitumo_plan")
          }
        }
      }

      if (this.allPlans.length === 0) {
        this.showEmpty()
        return
      }

      // Get active plan ID
      const activePlanId = localStorage.getItem(this.activePlanKeyValue)
      let activePlan = null

      if (activePlanId) {
        activePlan = this.allPlans.find(p => p.id === activePlanId)
      }

      // If no active plan set or not found, use the most recent
      if (!activePlan) {
        activePlan = this.allPlans[0]
        this.setActivePlan(activePlan.id)
      }

      this.currentPlan = activePlan
      this.renderPlanSwitcher()
      this.renderPlan(activePlan)
      this.showContent()
      this.loadRecommendations()
    } catch (error) {
      console.error("Failed to load plans:", error)
      this.showEmpty()
    }
  }

  // Validate that a plan object has required fields
  isValidPlan(plan) {
    if (!plan || typeof plan !== 'object') return false
    if (!plan.id) return false
    if (!plan.city_name) return false
    if (!Array.isArray(plan.days)) return false
    if (typeof plan.duration_days !== 'number' || plan.duration_days < 1) return false
    return true
  }

  savePlans() {
    try {
      localStorage.setItem(this.plansKeyValue, JSON.stringify(this.allPlans))

      // Also sync to backend if logged in (debounced)
      if (planSyncService.isLoggedIn()) {
        this.debouncedSync()
      }
    } catch (error) {
      console.error("Failed to save plans:", error)
    }
  }

  // Debounced sync to avoid too many API calls
  debouncedSync() {
    if (this.syncTimeout) {
      clearTimeout(this.syncTimeout)
    }
    this.syncTimeout = setTimeout(() => {
      planSyncService.syncPlans()
    }, 2000)
  }

  setActivePlan(planId) {
    localStorage.setItem(this.activePlanKeyValue, planId)
  }

  switchPlan(event) {
    const planId = event.currentTarget.dataset.planId
    const plan = this.allPlans.find(p => p.id === planId)

    if (plan) {
      this.currentPlan = plan
      this.setActivePlan(planId)
      this.renderPlanSwitcher()
      this.renderPlan(plan)
      this.loadRecommendations()
    }
  }

  renderPlanSwitcher() {
    if (!this.hasPlanSwitcherTarget || this.allPlans.length <= 1) {
      if (this.hasPlanSwitcherTarget) {
        this.planSwitcherTarget.classList.add("hidden")
      }
      return
    }

    this.planSwitcherTarget.classList.remove("hidden")

    const buttonsHtml = this.allPlans.map(plan => {
      const isActive = plan.id === this.currentPlan?.id
      const cityName = plan.city_name || plan.city?.display_name || plan.city?.name || 'Plan'
      // Show custom title if available, otherwise city name with duration
      const displayName = plan.custom_title && plan.custom_title.trim()
        ? plan.custom_title
        : cityName
      return `
        <button type="button"
                class="flex-shrink-0 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${isActive
                  ? 'bg-white text-amber-700'
                  : 'bg-white/20 text-white hover:bg-white/30'
                }"
                data-action="click->plan-viewer#switchPlan"
                data-plan-id="${plan.id}">
          ${displayName}
          <span class="ml-1 opacity-70">(${plan.duration_days}d)</span>
        </button>
      `
    }).join('')

    this.planSwitcherTarget.innerHTML = `
      <div class="flex items-center gap-2 overflow-x-auto pb-1">
        <span class="text-white/70 text-sm whitespace-nowrap">Vaši planovi:</span>
        ${buttonsHtml}
      </div>
    `
  }

  // ============================================
  // Plan rendering
  // ============================================

  renderPlan(plan) {
    // Header info - show custom title or default city name
    if (this.hasPlanTitleTarget) {
      const customTitle = plan.custom_title
      if (customTitle && customTitle.trim()) {
        this.planTitleTarget.textContent = customTitle
      } else {
        const cityName = plan.city_name
        const daysWord = plan.duration_days === 1 ? "dan" : "dana"
        this.planTitleTarget.textContent = `${cityName} - ${plan.duration_days} ${daysWord}`
      }
    }

    if (this.hasDurationTextTarget) {
      const daysWord = plan.duration_days === 1 ? "dan" : "dana"
      this.durationTextTarget.textContent = `${plan.duration_days} ${daysWord}`
    }

    if (this.hasExperiencesCountTarget) {
      this.experiencesCountTarget.textContent = plan.total_experiences || 0
    }

    if (this.hasGeneratedAtTarget) {
      const date = new Date(plan.generated_at)
      this.generatedAtTarget.textContent = date.toLocaleDateString('hr-HR', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    }

    // Sidebar
    if (this.hasSidebarCityTarget) {
      this.sidebarCityTarget.textContent = plan.city_name
    }

    if (this.hasSidebarDurationTarget) {
      const daysWord = plan.duration_days === 1 ? "dan" : "dana"
      this.sidebarDurationTarget.textContent = `${plan.duration_days} ${daysWord}`
    }

    if (this.hasSidebarExperiencesTarget) {
      this.sidebarExperiencesTarget.textContent = plan.total_experiences || 0
    }

    // Render days
    this.renderDays(plan.days)

    // Render preferences
    this.renderPreferences(plan.preferences)

    // Render notes
    this.renderNotes(plan.notes)

    // Render statistics (if available)
    this.renderStatistics(plan)

    // Update visibility button
    this.updateVisibilityButton()
  }

  renderDays(days) {
    if (!this.hasDaysTarget) return

    const html = days.map((day, dayIndex) => {
      const date = new Date(day.date)
      const formattedDate = date.toLocaleDateString('hr-HR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long'
      })

      const experiencesHtml = day.experiences && day.experiences.length > 0
        ? day.experiences.map((exp, index) => this.renderExperience(exp, index, dayIndex)).join('')
        : `<div class="text-center py-8 bg-gray-50 dark:bg-gray-700 rounded-xl">
            <p class="text-gray-500 dark:text-gray-400">Nema iskustava za ovaj dan</p>
          </div>`

      return `
        <div class="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-lg"
             data-day-index="${dayIndex}"
             data-action="dragover->plan-viewer#dragOver drop->plan-viewer#drop">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-bold text-gray-900 dark:text-white">
              Dan ${day.day_number}
            </h2>
            <span class="text-sm text-gray-500 dark:text-gray-400">
              ${formattedDate}
            </span>
          </div>
          <div class="space-y-4" data-experiences-container data-day-index="${dayIndex}">
            ${experiencesHtml}
          </div>
        </div>
      `
    }).join('')

    this.daysTarget.innerHTML = html
  }

  renderExperience(exp, index, dayIndex) {
    const locationsCount = exp.locations ? exp.locations.length : 0

    return `
      <div class="group flex items-start p-4 bg-gray-50 dark:bg-gray-700 rounded-xl transition-colors"
           draggable="true"
           data-experience-id="${exp.id}"
           data-day-index="${dayIndex}"
           data-experience-index="${index}"
           data-action="dragstart->plan-viewer#dragStart dragend->plan-viewer#dragEnd">
        <!-- Drag Handle -->
        <div class="flex-shrink-0 w-6 h-10 flex items-center justify-center cursor-grab active:cursor-grabbing mr-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
             title="Povuci za promjenu redoslijeda">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16"></path>
          </svg>
        </div>
        <!-- Content (clickable) -->
        <a href="/experiences/${exp.uuid || exp.id}" class="flex-grow min-w-0 hover:opacity-80">
          <h3 class="font-semibold text-gray-900 dark:text-white group-hover:text-amber-600 dark:group-hover:text-amber-400 transition-colors">
            ${exp.title}
          </h3>
          <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
            ${exp.description ? exp.description.substring(0, 150) + (exp.description.length > 150 ? '...' : '') : ''}
          </p>
          <div class="flex flex-wrap items-center gap-2 mt-3">
            ${exp.formatted_duration ? `
              <span class="text-xs text-gray-500 dark:text-gray-400 flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                ${exp.formatted_duration}
              </span>
            ` : ''}
            ${locationsCount > 0 ? `
              <span class="text-xs text-gray-500 dark:text-gray-400 flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                </svg>
                ${locationsCount} ${locationsCount === 1 ? 'lokacija' : 'lokacije'}
              </span>
            ` : ''}
          </div>
        </a>
        <!-- Delete Button -->
        <button type="button"
                class="flex-shrink-0 ml-2 p-2 text-gray-400 hover:text-red-500 dark:hover:text-red-400 transition-colors"
                title="Ukloni iz plana"
                data-action="click->plan-viewer#removeExperience"
                data-day-index="${dayIndex}"
                data-experience-index="${index}">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
          </svg>
        </button>
      </div>
    `
  }

  renderStatistics(plan) {
    // Check if targets exist and plan has days
    if (!this.hasStatisticsCardTarget || !plan.days || plan.days.length === 0) {
      if (this.hasStatisticsCardTarget) {
        this.statisticsCardTarget.classList.add("hidden")
      }
      return
    }

    const DEFAULT_EXPERIENCE_DURATION = 60

    // Always calculate statistics dynamically from current plan data
    let totalMinutes = 0
    const daysWithContent = []

    // Calculate per-day durations
    const dayStats = plan.days.map((day, index) => {
      let dayMinutes = 0

      if (day.experiences && day.experiences.length > 0) {
        day.experiences.forEach((exp) => {
          const duration = exp.estimated_duration || DEFAULT_EXPERIENCE_DURATION
          dayMinutes += duration
        })
        daysWithContent.push(index)
      }

      totalMinutes += dayMinutes
      return { dayNumber: day.day_number, minutes: dayMinutes }
    })

    // Calculate average daily minutes (only for days with content)
    const avgDailyMinutes = daysWithContent.length > 0
      ? Math.round(totalMinutes / daysWithContent.length)
      : 0

    // Get max daily limit from preferences or use default (6 hours = 360 minutes)
    const dailyHours = plan.preferences?.daily_hours || 6
    const maxLimit = dailyHours * 60

    // Show the statistics card
    this.statisticsCardTarget.classList.remove("hidden")

    // Total duration
    if (this.hasStatsTotalDurationTarget) {
      this.statsTotalDurationTarget.textContent = this.formatMinutes(totalMinutes)
    }

    // Average daily
    if (this.hasStatsAvgDailyTarget) {
      this.statsAvgDailyTarget.textContent = this.formatMinutes(avgDailyMinutes)
    }

    // Daily breakdown with progress bars
    if (this.hasStatsDailyBreakdownTarget) {
      const breakdownHtml = dayStats.map(dayStat => {
        const percentage = Math.min((dayStat.minutes / maxLimit) * 100, 100)
        const isOverLimit = dayStat.minutes > maxLimit

        // Color based on fill level
        let barColor = 'bg-emerald-500'
        if (percentage > 80) barColor = 'bg-amber-500'
        if (isOverLimit) barColor = 'bg-red-500'

        return `
          <div class="flex items-center gap-2">
            <span class="text-xs text-gray-500 dark:text-gray-400 w-14">Dan ${dayStat.dayNumber}</span>
            <div class="flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
              <div class="${barColor} h-full rounded-full transition-all duration-300" style="width: ${percentage}%"></div>
            </div>
            <span class="text-xs ${isOverLimit ? 'text-red-500 font-medium' : 'text-gray-500 dark:text-gray-400'} w-12 text-right">
              ${this.formatMinutes(dayStat.minutes)}
            </span>
          </div>
        `
      }).join('')

      this.statsDailyBreakdownTarget.innerHTML = breakdownHtml
    }
  }

  // Helper to format minutes
  formatMinutes(minutes) {
    if (!minutes || minutes <= 0) return "0min"

    const hours = Math.floor(minutes / 60)
    const mins = minutes % 60

    if (hours > 0 && mins > 0) {
      return `${hours}h ${mins}min`
    } else if (hours > 0) {
      return `${hours}h`
    } else {
      return `${mins}min`
    }
  }

  // Parse formatted duration string to minutes (e.g., "1h 30min" -> 90)
  parseDurationToMinutes(durationStr) {
    if (!durationStr) return 60 // Default to 60 minutes

    let totalMinutes = 0

    // Match hours (e.g., "1h", "2h")
    const hoursMatch = durationStr.match(/(\d+)h/)
    if (hoursMatch) {
      totalMinutes += parseInt(hoursMatch[1]) * 60
    }

    // Match minutes (e.g., "30min", "45min")
    const minsMatch = durationStr.match(/(\d+)min/)
    if (minsMatch) {
      totalMinutes += parseInt(minsMatch[1])
    }

    return totalMinutes || 60 // Return 60 as default if nothing parsed
  }

  renderPreferences(preferences) {
    if (!this.hasPreferencesListTarget || !preferences) {
      if (this.hasPreferencesTarget) {
        this.preferencesTarget.classList.add("hidden")
      }
      return
    }

    const items = []

    if (preferences.budget) {
      const budgetLabels = {
        low: "Niski budžet",
        medium: "Srednji budžet",
        high: "Visoki budžet"
      }
      items.push({
        icon: `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>`,
        label: budgetLabels[preferences.budget] || preferences.budget
      })
    }

    if (preferences.meat_lover !== undefined) {
      items.push({
        icon: `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path>
        </svg>`,
        label: preferences.meat_lover ? "Volim meso" : "Preferiram bez mesa"
      })
    }

    if (preferences.interests && preferences.interests.length > 0) {
      items.push({
        icon: `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
        </svg>`,
        label: preferences.interests.join(", ")
      })
    }

    if (items.length === 0) {
      if (this.hasPreferencesTarget) {
        this.preferencesTarget.classList.add("hidden")
      }
      return
    }

    this.preferencesListTarget.innerHTML = items.map(item => `
      <div class="flex items-center space-x-3 text-gray-600 dark:text-gray-400">
        ${item.icon}
        <span>${item.label}</span>
      </div>
    `).join('')
  }

  // ============================================
  // UI State
  // ============================================

  showLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    if (this.hasContentTarget) this.contentTarget.classList.add("hidden")
  }

  showEmpty() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
    if (this.hasContentTarget) this.contentTarget.classList.add("hidden")
  }

  showContent() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    if (this.hasContentTarget) this.contentTarget.classList.remove("hidden")
  }

  // ============================================
  // Plan actions
  // ============================================

  async deletePlan() {
    if (!confirm("Jeste li sigurni da želite obrisati ovaj plan?")) {
      return
    }

    if (!this.currentPlan) return

    try {
      // If plan is synced/shared to database, delete it there too
      const isInDatabase = this.currentPlan.uuid || this.currentPlan.synced || this.currentPlan.shared
      const isLoggedIn = document.querySelector('meta[name="user-logged-in"]')?.content === 'true'

      if (isInDatabase && isLoggedIn) {
        const planId = this.currentPlan.uuid || this.currentPlan.id
        try {
          const response = await fetch(`/user/plans/${planId}`, {
            method: "DELETE",
            headers: {
              "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
            }
          })
          // 204 No Content or 404 Not Found are both acceptable
          if (!response.ok && response.status !== 404) {
            console.error("Failed to delete plan from server:", response.status)
          }
        } catch (e) {
          // Continue with local deletion even if server delete fails
          console.error("Server delete error:", e)
        }
      }

      // Remove from plans array
      this.allPlans = this.allPlans.filter(p => p.id !== this.currentPlan.id)
      this.savePlans()

      if (this.allPlans.length > 0) {
        // Switch to another plan
        this.currentPlan = this.allPlans[0]
        this.setActivePlan(this.currentPlan.id)
        this.renderPlanSwitcher()
        this.renderPlan(this.currentPlan)
        this.loadRecommendations()
      } else {
        // No more plans
        localStorage.removeItem(this.activePlanKeyValue)
        this.currentPlan = null
        this.showEmpty()
      }
    } catch (error) {
      console.error("Failed to delete plan:", error)
    }
  }

  async regeneratePlan() {
    if (!this.currentPlan) {
      console.error("No plan to regenerate")
      return
    }

    // Show loading state on button
    if (this.hasRegenerateButtonTarget) {
      this.regenerateButtonTarget.disabled = true
      this.regenerateButtonTarget.innerHTML = `
        <svg class="w-5 h-5 mr-2 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generiranje...
      `
    }

    try {
      const preferences = this.currentPlan.preferences || {}

      const response = await fetch(this.generateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          city_name: this.currentPlan.city_name,
          duration: this.getDurationParam(this.currentPlan.duration_days),
          budget: preferences.budget,
          meat_lover: preferences.meat_lover,
          interests: preferences.interests
        })
      })

      if (!response.ok) {
        throw new Error("Failed to regenerate plan")
      }

      const newPlan = await response.json()

      // Update plan in array (keep same ID)
      newPlan.id = this.currentPlan.id
      const index = this.allPlans.findIndex(p => p.id === this.currentPlan.id)
      if (index !== -1) {
        this.allPlans[index] = newPlan
      }

      this.savePlans()
      this.currentPlan = newPlan
      this.renderPlan(newPlan)
      this.loadRecommendations()  // Refresh recommendations for new plan
      this.showRegenerateSuccess()
    } catch (error) {
      console.error("Regenerate error:", error)
      this.showRegenerateError()
    }
  }

  getDurationParam(days) {
    if (days === 1) return "1"
    if (days <= 3) return "2-3"
    return "4+"
  }

  showRegenerateSuccess() {
    if (this.hasRegenerateButtonTarget) {
      this.regenerateButtonTarget.disabled = false
      this.regenerateButtonTarget.innerHTML = `
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        Generirano!
      `
      setTimeout(() => {
        this.regenerateButtonTarget.innerHTML = `
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
          Generiraj ponovo
        `
      }, 2000)
    }
  }

  showRegenerateError() {
    if (this.hasRegenerateButtonTarget) {
      this.regenerateButtonTarget.disabled = false
      this.regenerateButtonTarget.innerHTML = `
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
        </svg>
        Greška, pokušajte ponovo
      `
      setTimeout(() => {
        this.regenerateButtonTarget.innerHTML = `
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
          </svg>
          Generiraj ponovo
        `
      }, 3000)
    }
  }

  // ============================================
  // Drag and Drop
  // ============================================

  dragStart(event) {
    const target = event.currentTarget
    this.draggedElement = target
    this.draggedDayIndex = parseInt(target.dataset.dayIndex)
    this.draggedExpIndex = parseInt(target.dataset.experienceIndex)

    target.classList.add("opacity-50", "ring-2", "ring-amber-500")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", "")
  }

  dragEnd(event) {
    const target = event.currentTarget
    target.classList.remove("opacity-50", "ring-2", "ring-amber-500")
    this.draggedElement = null
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const experienceEl = event.target.closest("[data-experience-id]")
    if (experienceEl && experienceEl !== this.draggedElement) {
      this.element.querySelectorAll(".drop-indicator").forEach(el => el.classList.remove("drop-indicator"))
      experienceEl.classList.add("drop-indicator")
    }
  }

  drop(event) {
    event.preventDefault()
    this.element.querySelectorAll(".drop-indicator").forEach(el => el.classList.remove("drop-indicator"))

    if (!this.draggedElement || !this.currentPlan) return

    const dropTarget = event.target.closest("[data-experience-id]")
    const dropContainer = event.target.closest("[data-experiences-container]")

    if (!dropContainer) return

    const targetDayIndex = parseInt(dropContainer.dataset.dayIndex)
    let targetExpIndex

    if (dropTarget) {
      targetExpIndex = parseInt(dropTarget.dataset.experienceIndex)
    } else {
      targetExpIndex = this.currentPlan.days[targetDayIndex].experiences.length
    }

    if (this.draggedDayIndex === targetDayIndex && this.draggedExpIndex === targetExpIndex) {
      return
    }

    this.moveExperience(this.draggedDayIndex, this.draggedExpIndex, targetDayIndex, targetExpIndex)
  }

  moveExperience(fromDayIndex, fromExpIndex, toDayIndex, toExpIndex) {
    if (!this.currentPlan) return

    const experience = this.currentPlan.days[fromDayIndex].experiences[fromExpIndex]
    if (!experience) return

    this.currentPlan.days[fromDayIndex].experiences.splice(fromExpIndex, 1)

    if (fromDayIndex === toDayIndex && fromExpIndex < toExpIndex) {
      toExpIndex--
    }

    this.currentPlan.days[toDayIndex].experiences.splice(toExpIndex, 0, experience)

    this.saveCurrentPlan()
    this.renderDays(this.currentPlan.days)
    this.renderStatistics(this.currentPlan)
  }

  // ============================================
  // Experience removal
  // ============================================

  removeExperience(event) {
    event.preventDefault()
    event.stopPropagation()

    const dayIndex = parseInt(event.currentTarget.dataset.dayIndex)
    const expIndex = parseInt(event.currentTarget.dataset.experienceIndex)

    if (!this.currentPlan || !this.currentPlan.days[dayIndex]) return

    const experience = this.currentPlan.days[dayIndex].experiences[expIndex]
    if (!experience) return

    this.pendingRemoval = { dayIndex, expIndex, experience }
    this.showConfirmModal(experience.title)
  }

  showConfirmModal(title) {
    if (this.hasConfirmModalTitleTarget) {
      this.confirmModalTitleTarget.textContent = `"${title}"`
    }
    if (this.hasConfirmModalTarget) {
      this.confirmModalTarget.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  closeModal() {
    if (this.hasConfirmModalTarget) {
      this.confirmModalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
    this.pendingRemoval = null
  }

  confirmRemove() {
    if (!this.pendingRemoval || !this.currentPlan) {
      this.closeModal()
      return
    }

    const { dayIndex, expIndex } = this.pendingRemoval

    this.currentPlan.days[dayIndex].experiences.splice(expIndex, 1)
    this.currentPlan.total_experiences = this.currentPlan.days.reduce(
      (sum, day) => sum + (day.experiences ? day.experiences.length : 0), 0
    )

    this.saveCurrentPlan()
    this.renderPlan(this.currentPlan)
    this.loadRecommendations()
    this.closeModal()
  }

  saveCurrentPlan() {
    if (!this.currentPlan) return

    const index = this.allPlans.findIndex(p => p.id === this.currentPlan.id)
    if (index !== -1) {
      this.allPlans[index] = this.currentPlan
    }
    this.savePlans()
  }

  // ============================================
  // Recommendations
  // ============================================

  async loadRecommendations() {
    if (!this.currentPlan || !this.currentPlan.city_name) return

    // Show loading state
    if (this.hasRecommendationsTarget) {
      this.recommendationsTarget.classList.remove("hidden")
      if (this.hasRecommendedExperiencesListTarget) {
        this.recommendedExperiencesListTarget.innerHTML = `
          <div class="flex items-center justify-center py-8 col-span-full">
            <svg class="w-6 h-6 animate-spin text-amber-500" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
        `
      }
    }

    // Create AbortController for timeout
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 10000) // 10 second timeout

    try {
      const excludeIds = this.getExperienceIdsFromPlan()

      const url = new URL(this.recommendationsUrlValue, window.location.origin)
      url.searchParams.set("city_name", this.currentPlan.city_name)
      if (excludeIds.length > 0) {
        url.searchParams.set("exclude_ids", JSON.stringify(excludeIds))
      }

      const response = await fetch(url, {
        headers: { "Accept": "application/json" },
        signal: controller.signal
      })

      clearTimeout(timeoutId)

      if (!response.ok) {
        throw new Error(`HTTP error: ${response.status}`)
      }

      const data = await response.json()
      this.renderRecommendations(data)
    } catch (error) {
      clearTimeout(timeoutId)

      if (error.name === 'AbortError') {
        console.warn("Recommendations request timed out")
      } else {
        console.error("Failed to load recommendations:", error)
      }

      // Show error state
      if (this.hasRecommendedExperiencesListTarget) {
        this.recommendedExperiencesListTarget.innerHTML = `
          <div class="text-center py-4 col-span-full text-gray-500 dark:text-gray-400">
            <p>Nije moguće učitati preporuke</p>
            <button type="button" class="text-amber-600 hover:text-amber-700 mt-2 underline"
                    data-action="click->plan-viewer#loadRecommendations">
              Pokušaj ponovo
            </button>
          </div>
        `
      }
    }
  }

  getExperienceIdsFromPlan() {
    if (!this.currentPlan || !this.currentPlan.days) return []

    const ids = []
    this.currentPlan.days.forEach(day => {
      if (day.experiences) {
        day.experiences.forEach(exp => {
          if (exp.id) ids.push(exp.id)
        })
      }
    })
    return ids
  }

  renderRecommendations(data) {
    const hasExperiences = data.experiences && data.experiences.length > 0
    const hasPlans = data.plans && data.plans.length > 0

    if (!hasExperiences && !hasPlans) return

    if (this.hasRecommendationsTarget) {
      this.recommendationsTarget.classList.remove("hidden")
    }

    if (hasExperiences && this.hasRecommendedExperiencesListTarget) {
      this.recommendedExperiencesTarget.classList.remove("hidden")
      this.recommendedExperiencesListTarget.innerHTML = data.experiences.map(exp =>
        this.renderRecommendedExperience(exp)
      ).join('')
    }

    if (hasPlans && this.hasSimilarPlansListTarget) {
      this.similarPlansTarget.classList.remove("hidden")
      this.similarPlansListTarget.innerHTML = data.plans.map(plan =>
        this.renderSimilarPlan(plan)
      ).join('')
    }
  }

  renderRecommendedExperience(exp) {
    return `
      <div class="bg-white dark:bg-gray-800 rounded-xl shadow-md hover:shadow-lg transition-shadow overflow-hidden"
           data-recommendation-id="${exp.id}">
        <a href="/experiences/${exp.uuid || exp.id}" class="block p-4">
          <h4 class="font-semibold text-gray-900 dark:text-white hover:text-amber-600 dark:hover:text-amber-400 transition-colors">
            ${exp.title}
          </h4>
          ${exp.description ? `
            <p class="text-sm text-gray-600 dark:text-gray-400 mt-1 line-clamp-2">
              ${exp.description}
            </p>
          ` : ''}
          <div class="flex items-center gap-3 mt-3 text-xs text-gray-500 dark:text-gray-400">
            ${exp.formatted_duration ? `
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                ${exp.formatted_duration}
              </span>
            ` : ''}
            ${exp.locations_count > 0 ? `
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                </svg>
                ${exp.locations_count} ${exp.locations_count === 1 ? 'lokacija' : 'lokacije'}
              </span>
            ` : ''}
          </div>
        </a>
        <button type="button"
                class="w-full flex items-center justify-center gap-2 px-4 py-3 bg-amber-500 hover:bg-amber-600 active:bg-amber-700 text-white font-medium transition-colors"
                data-action="click->plan-viewer#addExperienceToPlan"
                data-experience-id="${exp.id}"
                data-experience-title="${exp.title}"
                data-experience-description="${exp.description || ''}"
                data-experience-duration="${exp.formatted_duration || ''}"
                data-experience-locations="${exp.locations_count || 0}">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
          </svg>
          Dodaj u plan
        </button>
      </div>
    `
  }

  renderSimilarPlan(plan) {
    const stars = plan.average_rating ? '★'.repeat(Math.round(plan.average_rating)) + '☆'.repeat(5 - Math.round(plan.average_rating)) : ''
    const displayTitle = plan.custom_title && plan.custom_title.trim() ? plan.custom_title : plan.title

    return `
      <a href="/plans/${plan.id}"
         class="group block bg-white dark:bg-gray-800 rounded-xl p-4 shadow-md hover:shadow-lg transition-shadow">
        <h4 class="font-semibold text-gray-900 dark:text-white group-hover:text-amber-600 dark:group-hover:text-amber-400 transition-colors">
          ${displayTitle}
        </h4>
        <div class="flex items-center gap-3 mt-2 text-sm text-gray-600 dark:text-gray-400">
          <span>${plan.duration_days} ${plan.duration_days === 1 ? 'dan' : 'dana'}</span>
          <span>${plan.experiences_count} iskustava</span>
        </div>
        ${plan.average_rating ? `
          <div class="flex items-center gap-2 mt-2">
            <span class="text-amber-500 text-sm">${stars}</span>
            <span class="text-xs text-gray-500 dark:text-gray-400">(${plan.reviews_count} recenzija)</span>
          </div>
        ` : ''}
      </a>
    `
  }

  addExperienceToPlan(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.currentPlan || !this.currentPlan.days || this.currentPlan.days.length === 0) return

    const button = event.currentTarget
    const experience = {
      id: button.dataset.experienceId,
      title: button.dataset.experienceTitle,
      description: button.dataset.experienceDescription,
      formatted_duration: button.dataset.experienceDuration,
      estimated_duration: this.parseDurationToMinutes(button.dataset.experienceDuration),
      locations: []
    }

    this.currentPlan.days[0].experiences.push(experience)
    this.currentPlan.total_experiences = this.currentPlan.days.reduce(
      (sum, day) => sum + (day.experiences ? day.experiences.length : 0), 0
    )

    this.saveCurrentPlan()
    this.renderPlan(this.currentPlan)

    const card = button.closest('[data-recommendation-id]')
    if (card) {
      card.remove()
    }

    if (this.hasRecommendedExperiencesListTarget &&
        this.recommendedExperiencesListTarget.children.length === 0) {
      this.recommendedExperiencesTarget.classList.add("hidden")
    }
  }

  // ============================================
  // Toggle Plan Visibility
  // ============================================

  updateVisibilityButton() {
    if (!this.currentPlan) return

    const isPublic = this.currentPlan.visibility === "public_plan" || this.currentPlan.is_public
    const planUuid = this.currentPlan.uuid

    // Show/hide "View Public" button based on visibility and uuid
    if (this.hasViewPublicButtonTarget) {
      if (isPublic && planUuid) {
        this.viewPublicButtonTarget.classList.remove("hidden")
        this.viewPublicButtonTarget.href = `/plans/${planUuid}`
      } else {
        this.viewPublicButtonTarget.classList.add("hidden")
      }
    }

    if (this.hasVisibilityTextTarget) {
      this.visibilityTextTarget.textContent = isPublic ? "Učini privatnim" : "Učini javnim"
    }

    if (this.hasVisibilityIconTarget) {
      if (isPublic) {
        // Lock icon for making private
        this.visibilityIconTarget.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
        `
      } else {
        // Globe icon for making public
        this.visibilityIconTarget.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        `
      }
    }
  }

  toggleVisibility() {
    const isLoggedIn = planSyncService.isLoggedIn()
    const isPublic = this.currentPlan?.visibility === "public_plan" || this.currentPlan?.is_public

    // Show/hide appropriate elements based on login status
    if (this.hasVisibilityLoginRequiredTarget) {
      this.visibilityLoginRequiredTarget.classList.toggle("hidden", isLoggedIn)
    }
    if (this.hasVisibilityLoginButtonTarget) {
      this.visibilityLoginButtonTarget.classList.toggle("hidden", isLoggedIn)
    }
    if (this.hasConfirmVisibilityButtonTarget) {
      this.confirmVisibilityButtonTarget.classList.toggle("hidden", !isLoggedIn)
    }

    // Update modal content based on current visibility
    if (this.hasVisibilityModalTitleTarget) {
      this.visibilityModalTitleTarget.textContent = isPublic
        ? "Učini plan privatnim"
        : "Učini plan javnim"
    }

    if (this.hasVisibilityModalMessageTarget) {
      this.visibilityModalMessageTarget.textContent = isPublic
        ? "Tvoj plan više neće biti vidljiv drugim korisnicima."
        : "Tvoj plan će biti vidljiv svim korisnicima i pomoći će drugima da otkriju nova mjesta."
    }

    // Update modal icon container color
    if (this.hasVisibilityModalIconContainerTarget) {
      if (isPublic) {
        this.visibilityModalIconContainerTarget.classList.remove("bg-emerald-100", "dark:bg-emerald-900/30")
        this.visibilityModalIconContainerTarget.classList.add("bg-amber-100", "dark:bg-amber-900/30")
      } else {
        this.visibilityModalIconContainerTarget.classList.remove("bg-amber-100", "dark:bg-amber-900/30")
        this.visibilityModalIconContainerTarget.classList.add("bg-emerald-100", "dark:bg-emerald-900/30")
      }
    }

    // Update modal icon
    if (this.hasVisibilityModalIconTarget) {
      if (isPublic) {
        this.visibilityModalIconTarget.classList.remove("text-emerald-600", "dark:text-emerald-400")
        this.visibilityModalIconTarget.classList.add("text-amber-600", "dark:text-amber-400")
        this.visibilityModalIconTarget.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
        `
      } else {
        this.visibilityModalIconTarget.classList.remove("text-amber-600", "dark:text-amber-400")
        this.visibilityModalIconTarget.classList.add("text-emerald-600", "dark:text-emerald-400")
        this.visibilityModalIconTarget.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        `
      }
    }

    // Show modal
    if (this.hasVisibilityModalTarget) {
      this.visibilityModalTarget.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  closeVisibilityModal() {
    if (this.hasVisibilityModalTarget) {
      this.visibilityModalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  async confirmVisibilityToggle() {
    if (!this.currentPlan) {
      this.closeVisibilityModal()
      return
    }

    // Plan must be synced to the server first (have a uuid)
    const planId = this.currentPlan.uuid || this.currentPlan.id

    // If plan doesn't have a uuid yet, we need to sync it first
    if (!this.currentPlan.uuid) {
      // First sync the plan to get a UUID
      try {
        const syncResult = await planSyncService.syncPlans()
        if (syncResult.success && syncResult.plans) {
          const syncedPlan = syncResult.plans.find(p => p.id === this.currentPlan.id)
          if (syncedPlan && syncedPlan.uuid) {
            this.currentPlan.uuid = syncedPlan.uuid
            this.saveCurrentPlan()
          }
        }
      } catch (e) {
        console.error("Failed to sync plan:", e)
      }
    }

    const finalPlanId = this.currentPlan.uuid || this.currentPlan.id

    // Show loading state
    if (this.hasConfirmVisibilityButtonTarget) {
      this.confirmVisibilityButtonTarget.disabled = true
      this.confirmVisibilityButtonTarget.innerHTML = `
        <svg class="w-5 h-5 animate-spin inline-block mr-2" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Spremanje...
      `
    }

    try {
      const response = await fetch(`/user/plans/${finalPlanId}/toggle_visibility`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}))
        throw new Error(errorData.error || "Failed to toggle visibility")
      }

      const data = await response.json()

      // Update plan with new visibility status
      this.currentPlan.visibility = data.visibility
      this.currentPlan.is_public = data.is_public
      this.saveCurrentPlan()

      this.closeVisibilityModal()
      this.updateVisibilityButton()
      this.showVisibilitySuccess(data.is_public)
    } catch (error) {
      console.error("Visibility toggle error:", error)
      this.showVisibilityError(error.message)
    }
  }

  showVisibilitySuccess(isPublic) {
    // Show temporary success indicator on button
    if (this.hasVisibilityButtonTarget) {
      const originalHtml = this.visibilityButtonTarget.innerHTML
      this.visibilityButtonTarget.innerHTML = `
        <svg class="w-4 h-4 inline-block mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        ${isPublic ? "Sada je javan!" : "Sada je privatan!"}
      `
      this.visibilityButtonTarget.classList.remove("bg-white/10", "hover:bg-white/20")
      this.visibilityButtonTarget.classList.add("bg-emerald-500/20", "text-emerald-100")

      // Reset after 2 seconds
      setTimeout(() => {
        this.visibilityButtonTarget.classList.remove("bg-emerald-500/20", "text-emerald-100")
        this.visibilityButtonTarget.classList.add("bg-white/10", "hover:bg-white/20")
        this.updateVisibilityButton()
      }, 2000)
    }

    // Reset confirm button
    if (this.hasConfirmVisibilityButtonTarget) {
      this.confirmVisibilityButtonTarget.disabled = false
      this.confirmVisibilityButtonTarget.innerHTML = "Potvrdi"
    }
  }

  showVisibilityError(message) {
    if (this.hasConfirmVisibilityButtonTarget) {
      this.confirmVisibilityButtonTarget.disabled = false
      this.confirmVisibilityButtonTarget.innerHTML = `
        <svg class="w-5 h-5 inline-block mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
        </svg>
        Greška
      `

      setTimeout(() => {
        this.confirmVisibilityButtonTarget.innerHTML = "Potvrdi"
      }, 3000)
    }

    console.error("Visibility toggle failed:", message)
  }

  // ============================================
  // Edit Plan Title
  // ============================================

  showEditTitleModal() {
    if (!this.hasEditTitleModalTarget) return

    // Pre-fill with current custom title or empty
    if (this.hasTitleInputTarget) {
      this.titleInputTarget.value = this.currentPlan?.custom_title || ""
    }

    this.editTitleModalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")

    // Focus the input
    setTimeout(() => {
      if (this.hasTitleInputTarget) {
        this.titleInputTarget.focus()
        this.titleInputTarget.select()
      }
    }, 100)
  }

  closeEditTitleModal() {
    if (this.hasEditTitleModalTarget) {
      this.editTitleModalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  saveTitle(event) {
    // Prevent form submission if triggered by enter key
    if (event) {
      event.preventDefault()
    }

    if (!this.currentPlan || !this.hasTitleInputTarget) {
      this.closeEditTitleModal()
      return
    }

    const newTitle = this.titleInputTarget.value.trim()

    // Update the plan's custom_title
    this.currentPlan.custom_title = newTitle || null

    // Save to localStorage and sync
    this.saveCurrentPlan()

    // Update the displayed title
    this.renderPlan(this.currentPlan)

    // Also update the plan switcher if there are multiple plans
    this.renderPlanSwitcher()

    this.closeEditTitleModal()
  }

  // ============================================
  // Notes
  // ============================================

  renderNotes(notes) {
    const hasNotes = notes && typeof notes === 'string' && notes.trim().length > 0

    // Show/hide notes card based on whether notes exist
    if (this.hasNotesCardTarget) {
      if (hasNotes) {
        this.notesCardTarget.classList.remove("hidden")
      } else {
        this.notesCardTarget.classList.add("hidden")
      }
    }

    // Show/hide add notes button based on whether notes exist
    if (this.hasAddNotesButtonTarget) {
      if (hasNotes) {
        this.addNotesButtonTarget.classList.add("hidden")
      } else {
        this.addNotesButtonTarget.classList.remove("hidden")
      }
    }

    // Update notes content
    if (this.hasNotesContentTarget && hasNotes) {
      this.notesContentTarget.textContent = notes
    }
  }

  showEditNotesModal() {
    if (!this.hasEditNotesModalTarget) return

    // Pre-fill with current notes or empty
    if (this.hasNotesInputTarget) {
      this.notesInputTarget.value = this.currentPlan?.notes || ""
    }

    this.editNotesModalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")

    // Focus the textarea
    setTimeout(() => {
      if (this.hasNotesInputTarget) {
        this.notesInputTarget.focus()
      }
    }, 100)
  }

  closeEditNotesModal() {
    if (this.hasEditNotesModalTarget) {
      this.editNotesModalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  saveNotes(event) {
    if (event) {
      event.preventDefault()
    }

    if (!this.currentPlan || !this.hasNotesInputTarget) {
      this.closeEditNotesModal()
      return
    }

    const newNotes = this.notesInputTarget.value.trim()

    // Update the plan's notes
    this.currentPlan.notes = newNotes || null

    // Save to localStorage and sync
    this.saveCurrentPlan()

    // Update the displayed notes
    this.renderNotes(this.currentPlan.notes)

    this.closeEditNotesModal()
  }
}
