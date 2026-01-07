import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="plan-wizard"
export default class extends Controller {
  static targets = [
    "step",
    "stepIndicator",
    "prevButton",
    "nextButton",
    "submitButton",
    "cityNameDisplay",
    "locationStatus",
    "locationError",
    "locationLoading",
    "locationSuccess",
    "locationRetry",
    "manualCitySelect",
    "citySearchInput",
    "citySearchResults",
    "durationOption",
    "meatOption",
    "budgetOption",
    "dailyHoursOption",
    "interestTag",
    "interestsContainer",
    "loadMoreContainer",
    "loadMoreButton",
    "toast"
  ]

  static values = {
    currentStep: { type: Number, default: 0 },
    totalSteps: { type: Number, default: 4 },
    findCityUrl: { type: String, default: "/plans/find_city" },
    generateUrl: { type: String, default: "/plans/generate" },
    searchCitiesUrl: { type: String, default: "/plans/search_cities" },
    presetCityName: { type: String, default: "" },
    plansKey: { type: String, default: "visitumo_plans" },
    activePlanKey: { type: String, default: "visitumo_active_plan" },
    // I18n values
    geolocationNotSupported: { type: String, default: "Vaš preglednik ne podržava geolokaciju" },
    locationFailed: { type: String, default: "Nije moguće dobiti lokaciju. Molimo odaberite grad ručno." },
    permissionDenied: { type: String, default: "Pristup lokaciji je odbijen. Molimo omogućite pristup ili odaberite grad ručno." },
    locationUnavailable: { type: String, default: "Informacije o lokaciji nisu dostupne" },
    locationTimeout: { type: String, default: "Traženje lokacije traje predugo..." },
    noCityFound: { type: String, default: "Nismo pronašli grad u vašoj blizini. Molimo odaberite ručno." },
    cityLookupError: { type: String, default: "Greška pri traženju grada" },
    enableLocation: { type: String, default: "Molimo omogućite pristup lokaciji" },
    noSearchResults: { type: String, default: "Nema rezultata. Pokušajte s drugim terminom." },
    serverError: { type: String, default: "Greška pri povezivanju sa serverom" }
  }

  // Geolocation retry state
  locationRetryCount = 0
  maxLocationRetries = 2

  // Debounce timer for city search
  searchDebounceTimer = null
  searchDebounceDelay = 300

  // Form data
  formData = {
    cityName: null,
    duration: null,
    meatLover: null,
    budget: null,
    dailyHours: 6,  // Default to 6 hours (balanced)
    interests: []
  }

  connect() {
    // Check for preset city name from URL
    if (this.presetCityNameValue) {
      this.formData.cityName = this.presetCityNameValue
    }

    this.showStep(this.currentStepValue)
    this.updateNavigation()
  }

  disconnect() {
    // Clean up debounce timer
    if (this.searchDebounceTimer) {
      clearTimeout(this.searchDebounceTimer)
    }
  }

  // Navigation
  nextStep() {
    if (this.validateCurrentStep()) {
      if (this.currentStepValue < this.totalStepsValue - 1) {
        this.currentStepValue++
        this.showStep(this.currentStepValue)
        this.updateNavigation()
      }
    }
  }

  prevStep() {
    if (this.currentStepValue > 0) {
      this.currentStepValue--
      this.showStep(this.currentStepValue)
      this.updateNavigation()
    }
  }

  showStep(index) {
    this.stepTargets.forEach((step, i) => {
      if (i === index) {
        step.classList.remove("hidden")
        step.classList.add("animate-fade-in")
      } else {
        step.classList.add("hidden")
        step.classList.remove("animate-fade-in")
      }
    })

    // Update step indicators
    this.stepIndicatorTargets.forEach((indicator, i) => {
      if (i < index) {
        // Completed
        indicator.classList.remove("bg-gray-300", "dark:bg-gray-600", "bg-primary-600", "dark:bg-primary-500")
        indicator.classList.add("bg-green-500", "dark:bg-green-400")
      } else if (i === index) {
        // Current
        indicator.classList.remove("bg-gray-300", "dark:bg-gray-600", "bg-green-500", "dark:bg-green-400")
        indicator.classList.add("bg-primary-600", "dark:bg-primary-500")
      } else {
        // Upcoming
        indicator.classList.remove("bg-primary-600", "dark:bg-primary-500", "bg-green-500", "dark:bg-green-400")
        indicator.classList.add("bg-gray-300", "dark:bg-gray-600")
      }
    })
  }

  updateNavigation() {
    // Previous button
    if (this.hasPrevButtonTarget) {
      if (this.currentStepValue === 0) {
        this.prevButtonTarget.classList.add("invisible")
      } else {
        this.prevButtonTarget.classList.remove("invisible")
      }
    }

    // Next/Submit buttons
    if (this.hasNextButtonTarget && this.hasSubmitButtonTarget) {
      if (this.currentStepValue === this.totalStepsValue - 1) {
        this.nextButtonTarget.classList.add("hidden")
        this.submitButtonTarget.classList.remove("hidden")
      } else {
        this.nextButtonTarget.classList.remove("hidden")
        this.submitButtonTarget.classList.add("hidden")
      }
    }
  }

  // Step 0: Geolocation with retry and fallback
  requestLocation() {
    if (!navigator.geolocation) {
      this.showLocationError(this.geolocationNotSupportedValue, true)
      return
    }

    this.locationRetryCount = 0
    this.attemptGeolocation()
  }

  attemptGeolocation() {
    this.showLocationLoading()

    // First try with high accuracy (GPS), shorter timeout
    // If that fails, retry with low accuracy (network-based)
    const useHighAccuracy = this.locationRetryCount === 0
    const timeout = useHighAccuracy ? 8000 : 15000

    navigator.geolocation.getCurrentPosition(
      (position) => this.handleLocationSuccess(position),
      (error) => this.handleLocationError(error),
      {
        enableHighAccuracy: useHighAccuracy,
        timeout: timeout,
        maximumAge: 300000 // 5 minutes cache
      }
    )
  }

  retryLocation() {
    this.locationRetryCount++
    if (this.locationRetryCount <= this.maxLocationRetries) {
      this.attemptGeolocation()
    } else {
      this.showLocationError(this.locationFailedValue, true)
    }
  }

  async handleLocationSuccess(position) {
    const { latitude, longitude } = position.coords

    try {
      const response = await fetch(this.findCityUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ lat: latitude, lng: longitude })
      })

      const data = await response.json()

      if (data.city_name) {
        this.setCityName(data.city_name)
        this.showLocationSuccess()
      } else {
        this.showLocationError(this.noCityFoundValue, true)
      }
    } catch (error) {
      this.showLocationError(this.cityLookupErrorValue, true)
      console.error("City lookup error:", error)
    }
  }

  setCityName(cityName) {
    this.formData.cityName = cityName

    if (this.hasCityNameDisplayTarget) {
      this.cityNameDisplayTarget.textContent = cityName
    }
  }

  handleLocationError(error) {
    let message = this.locationFailedValue
    let canRetry = true

    switch (error.code) {
      case error.PERMISSION_DENIED:
        message = this.permissionDeniedValue
        canRetry = false // No point retrying if permission denied
        break
      case error.POSITION_UNAVAILABLE:
        message = this.locationUnavailableValue
        break
      case error.TIMEOUT:
        message = this.locationTimeoutValue
        // Auto-retry on timeout
        if (this.locationRetryCount < this.maxLocationRetries) {
          this.retryLocation()
          return
        }
        message = this.locationFailedValue
        break
    }

    this.showLocationError(message, canRetry || this.locationRetryCount < this.maxLocationRetries)
  }

  showLocationLoading() {
    if (this.hasLocationStatusTarget) {
      this.locationStatusTarget.classList.remove("hidden")
    }
    if (this.hasLocationLoadingTarget) {
      this.locationLoadingTarget.classList.remove("hidden")
    }
    if (this.hasLocationErrorTarget) {
      this.locationErrorTarget.classList.add("hidden")
    }
    if (this.hasLocationSuccessTarget) {
      this.locationSuccessTarget.classList.add("hidden")
    }
    if (this.hasLocationRetryTarget) {
      this.locationRetryTarget.classList.add("hidden")
    }
    if (this.hasManualCitySelectTarget) {
      this.manualCitySelectTarget.classList.add("hidden")
    }
  }

  showLocationError(message, showManualOption = true) {
    if (this.hasLocationStatusTarget) {
      this.locationStatusTarget.classList.remove("hidden")
    }
    if (this.hasLocationLoadingTarget) {
      this.locationLoadingTarget.classList.add("hidden")
    }
    if (this.hasLocationErrorTarget) {
      this.locationErrorTarget.classList.remove("hidden")
      // Find text element within error target
      const textEl = this.locationErrorTarget.querySelector("[data-error-text]")
      if (textEl) {
        textEl.textContent = message
      } else {
        this.locationErrorTarget.textContent = message
      }
    }
    if (this.hasLocationSuccessTarget) {
      this.locationSuccessTarget.classList.add("hidden")
    }
    // Show retry button if we haven't exhausted retries
    if (this.hasLocationRetryTarget) {
      if (this.locationRetryCount < this.maxLocationRetries) {
        this.locationRetryTarget.classList.remove("hidden")
      } else {
        this.locationRetryTarget.classList.add("hidden")
      }
    }
    // Show manual city selection option
    if (this.hasManualCitySelectTarget && showManualOption) {
      this.manualCitySelectTarget.classList.remove("hidden")
    }
  }

  showLocationSuccess() {
    if (this.hasLocationStatusTarget) {
      this.locationStatusTarget.classList.remove("hidden")
    }
    if (this.hasLocationLoadingTarget) {
      this.locationLoadingTarget.classList.add("hidden")
    }
    if (this.hasLocationErrorTarget) {
      this.locationErrorTarget.classList.add("hidden")
    }
    if (this.hasLocationSuccessTarget) {
      this.locationSuccessTarget.classList.remove("hidden")
    }
    if (this.hasLocationRetryTarget) {
      this.locationRetryTarget.classList.add("hidden")
    }
    if (this.hasManualCitySelectTarget) {
      this.manualCitySelectTarget.classList.add("hidden")
    }
  }

  // Manual city selection
  showManualCityInput() {
    if (this.hasManualCitySelectTarget) {
      this.manualCitySelectTarget.classList.remove("hidden")
    }
    if (this.hasCitySearchInputTarget) {
      this.citySearchInputTarget.focus()
    }
  }

  searchCities(event) {
    const query = event.target.value.trim()

    // Clear previous debounce timer
    if (this.searchDebounceTimer) {
      clearTimeout(this.searchDebounceTimer)
    }

    if (query.length < 2) {
      if (this.hasCitySearchResultsTarget) {
        this.citySearchResultsTarget.classList.add("hidden")
      }
      return
    }

    // Debounce the search request
    this.searchDebounceTimer = setTimeout(() => {
      this.performCitySearch(query)
    }, this.searchDebounceDelay)
  }

  async performCitySearch(query) {
    try {
      const response = await fetch(`${this.searchCitiesUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.cities && data.cities.length > 0) {
        this.renderCityResults(data.cities)
      } else {
        this.renderNoCityResults()
      }
    } catch (error) {
      console.error("City search error:", error)
    }
  }

  // Helper to escape HTML entities for XSS protection
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  renderCityResults(cities) {
    if (!this.hasCitySearchResultsTarget) return

    // Clear previous results
    this.citySearchResultsTarget.innerHTML = ''

    cities.forEach(city => {
      const button = document.createElement('button')
      button.type = 'button'
      button.className = 'w-full text-left px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors border-b border-gray-100 dark:border-gray-700 last:border-0'
      button.dataset.action = 'click->plan-wizard#selectCity'
      button.dataset.cityName = city.name

      const span = document.createElement('span')
      span.className = 'font-medium text-gray-900 dark:text-white'
      span.textContent = city.display_name || city.name

      button.appendChild(span)
      this.citySearchResultsTarget.appendChild(button)
    })

    this.citySearchResultsTarget.classList.remove("hidden")
  }

  renderNoCityResults() {
    if (!this.hasCitySearchResultsTarget) return

    // Clear and create element safely
    this.citySearchResultsTarget.innerHTML = ''

    const div = document.createElement('div')
    div.className = 'px-4 py-3 text-gray-500 dark:text-gray-400 text-sm'
    div.textContent = this.noSearchResultsValue

    this.citySearchResultsTarget.appendChild(div)
    this.citySearchResultsTarget.classList.remove("hidden")
  }

  selectCity(event) {
    const button = event.currentTarget
    const cityName = button.dataset.cityName

    this.setCityName(cityName)
    this.showLocationSuccess()

    // Clear search
    if (this.hasCitySearchInputTarget) {
      this.citySearchInputTarget.value = ""
    }
    if (this.hasCitySearchResultsTarget) {
      this.citySearchResultsTarget.classList.add("hidden")
    }
  }

  // Step 1: Duration selection
  selectDuration(event) {
    const value = event.currentTarget.dataset.value
    this.formData.duration = value

    this.durationOptionTargets.forEach(option => {
      if (option.dataset.value === value) {
        option.classList.remove("border-gray-300", "dark:border-gray-600")
        option.classList.add("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      } else {
        option.classList.add("border-gray-300", "dark:border-gray-600")
        option.classList.remove("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      }
    })
  }

  // Step 2: Preferences
  selectMeat(event) {
    const value = event.currentTarget.dataset.value
    this.formData.meatLover = value === "true"

    this.meatOptionTargets.forEach(option => {
      if (option.dataset.value === value) {
        option.classList.remove("border-gray-300", "dark:border-gray-600")
        option.classList.add("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      } else {
        option.classList.add("border-gray-300", "dark:border-gray-600")
        option.classList.remove("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      }
    })
  }

  selectBudget(event) {
    const value = event.currentTarget.dataset.value
    this.formData.budget = value

    this.budgetOptionTargets.forEach(option => {
      if (option.dataset.value === value) {
        option.classList.remove("border-gray-300", "dark:border-gray-600")
        option.classList.add("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      } else {
        option.classList.add("border-gray-300", "dark:border-gray-600")
        option.classList.remove("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      }
    })
  }

  selectDailyHours(event) {
    const value = parseInt(event.currentTarget.dataset.value)
    this.formData.dailyHours = value

    this.dailyHoursOptionTargets.forEach(option => {
      if (parseInt(option.dataset.value) === value) {
        option.classList.remove("border-gray-300", "dark:border-gray-600")
        option.classList.add("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      } else {
        option.classList.add("border-gray-300", "dark:border-gray-600")
        option.classList.remove("border-primary-500", "bg-primary-50", "dark:bg-primary-900/30")
      }
    })
  }

  // Step 3: Interests
  toggleInterest(event) {
    const tag = event.currentTarget.dataset.tag
    const index = this.formData.interests.indexOf(tag)

    if (index === -1) {
      this.formData.interests.push(tag)
      event.currentTarget.classList.remove("bg-gray-100", "dark:bg-gray-700", "text-gray-700", "dark:text-gray-300")
      event.currentTarget.classList.add("bg-primary-500", "text-white")
    } else {
      this.formData.interests.splice(index, 1)
      event.currentTarget.classList.add("bg-gray-100", "dark:bg-gray-700", "text-gray-700", "dark:text-gray-300")
      event.currentTarget.classList.remove("bg-primary-500", "text-white")
    }
  }

  // Load more interests (show hidden interests)
  loadMoreInterests(event) {
    const button = event.currentTarget
    const initialCount = parseInt(button.dataset.initialCount) || 8

    // Show all hidden interest tags
    this.interestTagTargets.forEach((tag, index) => {
      if (index >= initialCount) {
        tag.classList.remove("hidden")
        // Add animation
        tag.classList.add("animate-fade-in")
      }
    })

    // Hide the load more button container
    if (this.hasLoadMoreContainerTarget) {
      this.loadMoreContainerTarget.classList.add("hidden")
    }
  }

  // Validation
  validateCurrentStep() {
    switch (this.currentStepValue) {
      case 0:
        if (!this.formData.cityName) {
          this.showLocationError(this.enableLocationValue)
          return false
        }
        return true
      case 1:
        if (!this.formData.duration) {
          this.highlightRequired(this.durationOptionTargets)
          return false
        }
        return true
      case 2:
        if (this.formData.meatLover === null || !this.formData.budget) {
          if (this.formData.meatLover === null) {
            this.highlightRequired(this.meatOptionTargets)
          }
          if (!this.formData.budget) {
            this.highlightRequired(this.budgetOptionTargets)
          }
          return false
        }
        return true
      case 3:
        // Interests are optional
        return true
      default:
        return true
    }
  }

  highlightRequired(targets) {
    targets.forEach(target => {
      target.classList.add("ring-2", "ring-red-500")
      setTimeout(() => {
        target.classList.remove("ring-2", "ring-red-500")
      }, 2000)
    })
  }

  // Generate plan via API and save to localStorage
  async generatePlan(event) {
    if (event) event.preventDefault()

    if (!this.validateCurrentStep()) {
      return
    }

    // Show loading state
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = `
        <svg class="w-5 h-5 inline-block mr-2 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Kreiram plan...
      `
    }

    try {
      const response = await fetch(this.generateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          city_name: this.formData.cityName,
          duration: this.formData.duration,
          meat_lover: this.formData.meatLover,
          budget: this.formData.budget,
          daily_hours: this.formData.dailyHours,
          interests: this.formData.interests
        })
      })

      const planData = await response.json()

      if (response.ok) {
        // Save to localStorage
        this.savePlanToStorage(planData)

        // Dispatch custom event for other components
        this.dispatch("planGenerated", { detail: planData })

        // Show success and redirect (include any warnings)
        this.showSuccess(planData, planData.warnings)
      } else {
        this.showError(planData.error || "Greška pri kreiranju plana")
      }
    } catch (error) {
      console.error("Plan generation error:", error)
      this.showError(this.serverErrorValue)
    }
  }

  // Save plan to localStorage (multi-plan support)
  savePlanToStorage(planData) {
    try {
      // Mark as saved locally
      planData.saved = true
      planData.savedAt = new Date().toISOString()

      // Load existing plans
      const plans = this.getAllPlans()

      // Add new plan at the beginning
      plans.unshift(planData)

      // Keep only last 10 plans
      const trimmedPlans = plans.slice(0, 10)

      // Save plans list
      localStorage.setItem(this.plansKeyValue, JSON.stringify(trimmedPlans))

      // Set this plan as active
      localStorage.setItem(this.activePlanKeyValue, planData.id)

      // Clean up old single-plan format if it exists
      localStorage.removeItem("visitumo_plan")
      localStorage.removeItem("visitumo_plan_history")

      return true
    } catch (error) {
      console.error("Failed to save plan to localStorage:", error)
      return false
    }
  }

  // Get all plans from localStorage
  getAllPlans() {
    try {
      const data = localStorage.getItem(this.plansKeyValue)
      if (data) {
        return JSON.parse(data)
      }

      // Migrate from old single-plan format if exists
      const oldPlan = localStorage.getItem("visitumo_plan")
      if (oldPlan) {
        const plan = JSON.parse(oldPlan)
        return [plan]
      }

      return []
    } catch {
      return []
    }
  }

  // Get current/active plan from localStorage
  getCurrentPlan() {
    try {
      const plans = this.getAllPlans()
      if (plans.length === 0) return null

      const activePlanId = localStorage.getItem(this.activePlanKeyValue)
      if (activePlanId) {
        const activePlan = plans.find(p => p.id === activePlanId)
        if (activePlan) return activePlan
      }

      // Return first plan if no active plan set
      return plans[0]
    } catch {
      return null
    }
  }

  // Clear all plans
  clearAllPlans() {
    localStorage.removeItem(this.plansKeyValue)
    localStorage.removeItem(this.activePlanKeyValue)
  }

  // Clear specific plan
  clearPlan(planId) {
    const plans = this.getAllPlans()
    const filtered = plans.filter(p => p.id !== planId)
    localStorage.setItem(this.plansKeyValue, JSON.stringify(filtered))

    // If we deleted the active plan, set a new active
    const activePlanId = localStorage.getItem(this.activePlanKeyValue)
    if (activePlanId === planId && filtered.length > 0) {
      localStorage.setItem(this.activePlanKeyValue, filtered[0].id)
    } else if (filtered.length === 0) {
      localStorage.removeItem(this.activePlanKeyValue)
    }
  }

  // Show success state
  showSuccess(planData, warnings = []) {
    // Build warnings HTML if any
    let warningsHtml = ''
    if (warnings && warnings.length > 0) {
      warningsHtml = `
        <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4 mb-6 text-left">
          <div class="flex items-start">
            <svg class="w-5 h-5 text-amber-500 mt-0.5 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
            </svg>
            <div class="text-sm text-amber-700 dark:text-amber-300">
              ${warnings.map(w => `<p>${w}</p>`).join('')}
            </div>
          </div>
        </div>
      `
    }

    // Replace wizard content with success message
    const content = `
      <div class="text-center py-8 animate-fade-in">
        <div class="w-20 h-20 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center mx-auto mb-6">
          <svg class="w-10 h-10 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
          </svg>
        </div>
        <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          Plan je kreiran!
        </h2>
        <p class="text-gray-600 dark:text-gray-400 mb-6">
          ${planData.total_experiences} iskustava za ${planData.duration_days} ${planData.duration_days === 1 ? 'dan' : 'dana'} u ${planData.city_name}
        </p>
        ${warningsHtml}
        <div class="space-x-4">
          <a href="/plans/view" class="btn-primary inline-block">
            Pogledaj plan
          </a>
          <button type="button" class="btn-secondary" onclick="location.reload()">
            Kreiraj novi
          </button>
        </div>
      </div>
    `

    // Find the card and replace content
    const card = this.element.querySelector('.card')
    if (card) {
      card.innerHTML = content
    }
  }

  // Show error with toast notification
  showError(message) {
    // Reset button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.innerHTML = `
        <svg class="w-5 h-5 inline-block mr-1 -mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
        </svg>
        Kreiraj plan
      `
    }

    // Show toast notification
    this.showToast(message, 'error')
  }

  // Toast notification system
  showToast(message, type = 'error') {
    // Remove existing toast if any
    const existingToast = document.getElementById('plan-wizard-toast')
    if (existingToast) {
      existingToast.remove()
    }

    // Create toast element
    const toast = document.createElement('div')
    toast.id = 'plan-wizard-toast'
    toast.className = `fixed bottom-4 left-1/2 -translate-x-1/2 z-50 px-6 py-4 rounded-lg shadow-lg transition-all duration-300 transform translate-y-full opacity-0 ${
      type === 'error'
        ? 'bg-red-600 text-white'
        : type === 'success'
        ? 'bg-green-600 text-white'
        : 'bg-gray-800 text-white dark:bg-gray-700'
    }`

    // Create inner content
    const content = document.createElement('div')
    content.className = 'flex items-center space-x-3'

    // Icon
    const iconSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    iconSvg.setAttribute('class', 'w-5 h-5 flex-shrink-0')
    iconSvg.setAttribute('fill', 'none')
    iconSvg.setAttribute('stroke', 'currentColor')
    iconSvg.setAttribute('viewBox', '0 0 24 24')

    const iconPath = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    iconPath.setAttribute('stroke-linecap', 'round')
    iconPath.setAttribute('stroke-linejoin', 'round')
    iconPath.setAttribute('stroke-width', '2')

    if (type === 'error') {
      iconPath.setAttribute('d', 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z')
    } else if (type === 'success') {
      iconPath.setAttribute('d', 'M5 13l4 4L19 7')
    } else {
      iconPath.setAttribute('d', 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z')
    }

    iconSvg.appendChild(iconPath)
    content.appendChild(iconSvg)

    // Message text
    const text = document.createElement('span')
    text.className = 'font-medium'
    text.textContent = message
    content.appendChild(text)

    // Close button
    const closeBtn = document.createElement('button')
    closeBtn.type = 'button'
    closeBtn.className = 'ml-4 text-white/80 hover:text-white'
    closeBtn.innerHTML = `
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
      </svg>
    `
    closeBtn.addEventListener('click', () => this.hideToast(toast))
    content.appendChild(closeBtn)

    toast.appendChild(content)
    document.body.appendChild(toast)

    // Animate in
    requestAnimationFrame(() => {
      toast.classList.remove('translate-y-full', 'opacity-0')
    })

    // Auto-hide after 5 seconds
    setTimeout(() => {
      this.hideToast(toast)
    }, 5000)
  }

  hideToast(toast) {
    if (!toast) return

    toast.classList.add('translate-y-full', 'opacity-0')
    setTimeout(() => {
      toast.remove()
    }, 300)
  }

  // Close wizard (for modal usage)
  close() {
    this.element.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }
}
