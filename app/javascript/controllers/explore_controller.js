import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="explore"
// Handles explore page search and filtering functionality
export default class extends Controller {
  static targets = [
    "form",
    "searchInput",
    "resultsContainer",
    "loadingIndicator",
    "emptyState",
    "filterPanel",
    "filterToggle",
    "filterCount",
    "typeCheckbox",
    "filterInput",
    "citySelect",
    "audioToggle",
    "nearbyButton",
    "nearbyStatus",
    "nearbyOptions",
    "latInput",
    "lngInput",
    "radiusSelect",
    "clearFiltersButton",
    "seasonClearBtn",
    "budgetClearBtn",
    "durationClearBtn",
    "ratingClearBtn",
    "originClearBtn"
  ]

  static values = {
    searchUrl: { type: String, default: "/explore" },
    debounceMs: { type: Number, default: 300 },
    lat: { type: Number, default: 0 },
    lng: { type: Number, default: 0 },
    nearbyActive: { type: Boolean, default: false },
    filtersExpanded: { type: Boolean, default: false }
  }

  // Geolocation retry state
  locationRetryCount = 0
  maxLocationRetries = 2
  searchTimeout = null
  abortController = null

  connect() {
    // Parse URL parameters and set initial state
    this.initializeFromUrl()

    // Update filter count badge and clear buttons
    this.updateFilterCount()
    this.updateClearButtons()
  }

  disconnect() {
    // Clean up any pending requests
    if (this.abortController) {
      this.abortController.abort()
    }
    clearTimeout(this.searchTimeout)
  }

  // Initialize filters from URL parameters
  initializeFromUrl() {
    const urlParams = new URLSearchParams(window.location.search)

    // Set nearby coordinates if present
    if (urlParams.has("lat") && urlParams.has("lng")) {
      this.latValue = parseFloat(urlParams.get("lat"))
      this.lngValue = parseFloat(urlParams.get("lng"))
      this.nearbyActiveValue = true

      // Ensure hidden inputs are enabled and have correct values
      if (this.hasLatInputTarget) {
        this.latInputTarget.value = this.latValue
        this.latInputTarget.disabled = false
      }
      if (this.hasLngInputTarget) {
        this.lngInputTarget.value = this.lngValue
        this.lngInputTarget.disabled = false
      }

      this.updateNearbyUI(true)
    } else {
      // No coordinates - disable hidden inputs
      if (this.hasLatInputTarget) this.latInputTarget.disabled = true
      if (this.hasLngInputTarget) this.lngInputTarget.disabled = true
    }

    // Set type checkboxes
    const types = urlParams.getAll("types[]")
    if (this.hasTypeCheckboxTarget) {
      this.typeCheckboxTargets.forEach(checkbox => {
        checkbox.checked = types.includes(checkbox.value)
      })
    }

    // Set search input
    if (this.hasSearchInputTarget && urlParams.has("q")) {
      this.searchInputTarget.value = urlParams.get("q")
    }

    // Set audio toggle
    if (this.hasAudioToggleTarget && urlParams.has("audio_support")) {
      this.audioToggleTarget.checked = urlParams.get("audio_support") === "true"
    }
  }

  // Handle search input with debounce
  onSearchInput(event) {
    clearTimeout(this.searchTimeout)

    this.searchTimeout = setTimeout(() => {
      this.performSearch()
    }, this.debounceMsValue)
  }

  // Handle search form submission
  onSearchSubmit(event) {
    event.preventDefault()
    clearTimeout(this.searchTimeout)
    this.performSearch()
  }

  // Perform the search
  performSearch() {
    const formData = this.buildFormData()
    const queryString = new URLSearchParams(formData).toString()

    // Update URL without reload for better UX
    const newUrl = `${this.searchUrlValue}${queryString ? '?' + queryString : ''}`
    window.history.pushState({}, "", newUrl)

    // Submit form to load new results
    if (this.hasFormTarget) {
      this.formTarget.submit()
    }
  }

  // Build form data from all inputs
  buildFormData() {
    const formData = new FormData()

    // Search query
    if (this.hasSearchInputTarget && this.searchInputTarget.value.trim()) {
      formData.append("q", this.searchInputTarget.value.trim())
    }

    // Resource types (multiple)
    if (this.hasTypeCheckboxTarget) {
      this.typeCheckboxTargets.forEach(checkbox => {
        if (checkbox.checked) {
          formData.append("types[]", checkbox.value)
        }
      })
    }

    // Radio button filters (season, budget, duration, min_rating, sort)
    if (this.hasFilterInputTarget) {
      this.filterInputTargets.forEach(input => {
        if (input.checked && input.value) {
          formData.append(input.name, input.value)
        }
      })
    }

    // City filter
    if (this.hasCitySelectTarget && this.citySelectTarget.value) {
      formData.append("city_name", this.citySelectTarget.value)
    }

    // Audio support filter
    if (this.hasAudioToggleTarget && this.audioToggleTarget.checked) {
      formData.append("audio_support", "true")
    }

    // Nearby coordinates and radius
    if (this.nearbyActiveValue && this.latValue && this.lngValue) {
      formData.append("lat", this.latValue)
      formData.append("lng", this.lngValue)

      // Include radius if selected
      if (this.hasRadiusSelectTarget && this.radiusSelectTarget.value) {
        formData.append("radius", this.radiusSelectTarget.value)
      }
    }

    return formData
  }

  // Handle filter change (immediate search)
  onFilterChange(event) {
    this.updateFilterCount()
    this.updateClearButtons()
    this.performSearch()
  }

  // Update visibility of individual clear buttons
  updateClearButtons() {
    // Check each filter type and show/hide its clear button
    const filterStates = {
      season: false,
      budget: false,
      duration: false,
      min_rating: false,
      origin: false
    }

    // Check which filters are active
    if (this.hasFilterInputTarget) {
      this.filterInputTargets.forEach(input => {
        if (input.checked && filterStates.hasOwnProperty(input.name)) {
          filterStates[input.name] = true
        }
      })
    }

    // Update clear button visibility
    if (this.hasSeasonClearBtnTarget) {
      this.seasonClearBtnTarget.classList.toggle("hidden", !filterStates.season)
    }
    if (this.hasBudgetClearBtnTarget) {
      this.budgetClearBtnTarget.classList.toggle("hidden", !filterStates.budget)
    }
    if (this.hasDurationClearBtnTarget) {
      this.durationClearBtnTarget.classList.toggle("hidden", !filterStates.duration)
    }
    if (this.hasRatingClearBtnTarget) {
      this.ratingClearBtnTarget.classList.toggle("hidden", !filterStates.min_rating)
    }
    if (this.hasOriginClearBtnTarget) {
      this.originClearBtnTarget.classList.toggle("hidden", !filterStates.origin)
    }
  }

  // Handle type checkbox change
  onTypeChange(event) {
    this.updateFilterCount()
    this.performSearch()
  }

  // Toggle filter panel visibility (mobile)
  toggleFilters(event) {
    event.preventDefault()
    this.filtersExpandedValue = !this.filtersExpandedValue

    if (this.hasFilterPanelTarget) {
      if (this.filtersExpandedValue) {
        this.filterPanelTarget.classList.remove("hidden")
      } else {
        this.filterPanelTarget.classList.add("hidden")
      }
    }

    if (this.hasFilterToggleTarget) {
      const icon = this.filterToggleTarget.querySelector("svg")
      if (icon) {
        icon.classList.toggle("rotate-180", this.filtersExpandedValue)
      }
    }
  }

  // Update filter count badge
  updateFilterCount() {
    let count = 0

    // Count checked type filters
    if (this.hasTypeCheckboxTarget) {
      count += this.typeCheckboxTargets.filter(cb => cb.checked).length
    }

    // Count checked radio filters (excluding sort which is always set)
    if (this.hasFilterInputTarget) {
      this.filterInputTargets.forEach(input => {
        if (input.checked && input.name !== "sort") {
          count++
        }
      })
    }

    // Count city select
    if (this.hasCitySelectTarget && this.citySelectTarget.value) count++

    // Count toggles
    if (this.hasAudioToggleTarget && this.audioToggleTarget.checked) count++
    if (this.nearbyActiveValue) count++

    // Update badge
    if (this.hasFilterCountTarget) {
      this.filterCountTarget.textContent = count
      this.filterCountTarget.classList.toggle("hidden", count === 0)
    }

    // Show/hide clear button
    if (this.hasClearFiltersButtonTarget) {
      this.clearFiltersButtonTarget.classList.toggle("hidden", count === 0)
    }
  }

  // Clear all filters
  clearAllFilters(event) {
    event.preventDefault()

    // Clear search input
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }

    // Uncheck all type checkboxes
    if (this.hasTypeCheckboxTarget) {
      this.typeCheckboxTargets.forEach(cb => cb.checked = false)
    }

    // Uncheck all radio filters
    if (this.hasFilterInputTarget) {
      this.filterInputTargets.forEach(input => input.checked = false)
    }

    // Reset city select
    if (this.hasCitySelectTarget) this.citySelectTarget.value = ""

    // Clear toggles
    if (this.hasAudioToggleTarget) this.audioToggleTarget.checked = false

    // Clear nearby
    this.clearNearby()

    // Update UI and search
    this.updateFilterCount()
    this.updateClearButtons()

    // Navigate to clean URL
    window.location.href = this.searchUrlValue
  }

  // Clear individual filter by name
  clearFilterByName(filterName) {
    if (this.hasFilterInputTarget) {
      this.filterInputTargets.forEach(input => {
        if (input.name === filterName) {
          input.checked = false
        }
      })
    }
    this.updateFilterCount()
    this.updateClearButtons()
    this.performSearch()
  }

  // Clear season filter
  clearSeason(event) {
    event.preventDefault()
    this.clearFilterByName("season")
  }

  // Clear budget filter
  clearBudget(event) {
    event.preventDefault()
    this.clearFilterByName("budget")
  }

  // Clear duration filter
  clearDuration(event) {
    event.preventDefault()
    this.clearFilterByName("duration")
  }

  // Clear rating filter
  clearRating(event) {
    event.preventDefault()
    this.clearFilterByName("min_rating")
  }

  // Clear origin filter
  clearOrigin(event) {
    event.preventDefault()
    this.clearFilterByName("origin")
  }

  // Clear city filter
  clearCity(event) {
    event.preventDefault()
    if (this.hasCitySelectTarget) {
      this.citySelectTarget.value = ""
    }
    this.updateFilterCount()
    this.updateClearButtons()
    this.performSearch()
  }

  // ========== Geolocation / Nearby ==========

  toggleNearby(event) {
    event.preventDefault()

    // If already active, turn off
    if (this.nearbyActiveValue) {
      this.clearNearby()
      this.updateFilterCount()
      this.performSearch()
      return
    }

    // Otherwise, request location
    if (!navigator.geolocation) {
      this.showNearbyError("Vaš preglednik ne podržava geolokaciju")
      return
    }

    this.locationRetryCount = 0
    this.attemptGeolocation()
  }

  // Change radius
  onRadiusChange(event) {
    if (this.hasRadiusSelectTarget) {
      // If nearby is active, re-search with new radius
      if (this.nearbyActiveValue) {
        this.performSearch()
      }
    }
  }

  attemptGeolocation() {
    this.showNearbyLoading()

    const useHighAccuracy = this.locationRetryCount === 0
    const timeout = useHighAccuracy ? 8000 : 15000

    navigator.geolocation.getCurrentPosition(
      (position) => this.handleLocationSuccess(position),
      (error) => this.handleLocationError(error),
      {
        enableHighAccuracy: useHighAccuracy,
        timeout: timeout,
        maximumAge: 0
      }
    )
  }

  handleLocationSuccess(position) {
    this.latValue = position.coords.latitude
    this.lngValue = position.coords.longitude
    this.nearbyActiveValue = true

    // Update and enable hidden inputs
    if (this.hasLatInputTarget) {
      this.latInputTarget.value = this.latValue
      this.latInputTarget.disabled = false
    }
    if (this.hasLngInputTarget) {
      this.lngInputTarget.value = this.lngValue
      this.lngInputTarget.disabled = false
    }

    this.hideNearbyLoading()
    this.updateNearbyUI(true)
    this.updateFilterCount()
    this.performSearch()
  }

  handleLocationError(error) {
    if (this.locationRetryCount < this.maxLocationRetries) {
      this.locationRetryCount++
      this.attemptGeolocation()
      return
    }

    let message = "Nije moguće dohvatiti lokaciju"
    switch (error.code) {
      case error.PERMISSION_DENIED:
        message = "Pristup lokaciji je odbijen"
        break
      case error.POSITION_UNAVAILABLE:
        message = "Lokacija nije dostupna"
        break
      case error.TIMEOUT:
        message = "Zahtjev za lokaciju je istekao"
        break
    }

    this.hideNearbyLoading()
    this.showNearbyError(message)
  }

  showNearbyLoading() {
    if (this.hasNearbyButtonTarget) {
      this.nearbyButtonTarget.disabled = true
      this.nearbyButtonTarget.innerHTML = `
        <svg class="animate-spin w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Lociranje...
      `
    }
  }

  hideNearbyLoading() {
    if (this.hasNearbyButtonTarget) {
      this.nearbyButtonTarget.disabled = false
    }
  }

  updateNearbyUI(active) {
    if (!this.hasNearbyButtonTarget) return

    if (active) {
      this.nearbyButtonTarget.innerHTML = `
        <svg class="w-4 h-4 mr-2 text-green-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
        </svg>
        U blizini
      `
      this.nearbyButtonTarget.classList.add("bg-green-50", "text-green-700", "dark:bg-green-900/20", "dark:text-green-400")
      this.nearbyButtonTarget.classList.remove("bg-gray-100", "text-gray-700", "dark:bg-gray-700", "dark:text-gray-300")

      // Show radius options
      if (this.hasNearbyOptionsTarget) {
        this.nearbyOptionsTarget.classList.remove("hidden")
      }
    } else {
      this.nearbyButtonTarget.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
        </svg>
        U blizini
      `
      this.nearbyButtonTarget.classList.remove("bg-green-50", "text-green-700", "dark:bg-green-900/20", "dark:text-green-400")
      this.nearbyButtonTarget.classList.add("bg-gray-100", "text-gray-700", "dark:bg-gray-700", "dark:text-gray-300")

      // Hide radius options
      if (this.hasNearbyOptionsTarget) {
        this.nearbyOptionsTarget.classList.add("hidden")
      }
    }
  }

  showNearbyError(message) {
    if (this.hasNearbyStatusTarget) {
      this.nearbyStatusTarget.textContent = message
      this.nearbyStatusTarget.classList.remove("hidden")

      setTimeout(() => {
        this.nearbyStatusTarget.classList.add("hidden")
      }, 3000)
    }
  }

  clearNearby(event) {
    if (event) event.preventDefault()

    this.latValue = 0
    this.lngValue = 0
    this.nearbyActiveValue = false

    // Clear and disable hidden inputs so they don't submit with form
    if (this.hasLatInputTarget) {
      this.latInputTarget.value = ""
      this.latInputTarget.disabled = true
    }
    if (this.hasLngInputTarget) {
      this.lngInputTarget.value = ""
      this.lngInputTarget.disabled = true
    }

    this.updateNearbyUI(false)
  }

  // ========== Loading State ==========

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove("hidden")
    }
    if (this.hasResultsContainerTarget) {
      this.resultsContainerTarget.classList.add("opacity-50")
    }
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add("hidden")
    }
    if (this.hasResultsContainerTarget) {
      this.resultsContainerTarget.classList.remove("opacity-50")
    }
  }
}
