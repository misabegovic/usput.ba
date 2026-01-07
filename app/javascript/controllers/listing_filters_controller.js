import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="listing-filters"
export default class extends Controller {
  static targets = [
    "form",
    "nearbyButton",
    "nearbyStatus",
    "nearbyCoords",
    "nearbyBadge",
    "clearNearby",
    "citySelect",
    "activeFilters",
    "filterContent",
    "toggleButton",
    "toggleIcon"
  ]

  static values = {
    findCityUrl: { type: String, default: "/plans/find_city" },
    lat: { type: Number, default: 0 },
    lng: { type: Number, default: 0 },
    nearbyActive: { type: Boolean, default: false },
    filtersExpanded: { type: Boolean, default: false }
  }

  // Geolocation retry state
  locationRetryCount = 0
  maxLocationRetries = 2

  connect() {
    // Check for existing nearby params in URL
    const urlParams = new URLSearchParams(window.location.search)
    if (urlParams.has('lat') && urlParams.has('lng')) {
      this.latValue = parseFloat(urlParams.get('lat'))
      this.lngValue = parseFloat(urlParams.get('lng'))
      this.nearbyActiveValue = true
      this.updateNearbyUI()
    }
  }

  // Nearby filter - request geolocation
  requestNearby(event) {
    event.preventDefault()

    if (!navigator.geolocation) {
      this.showNearbyError("Your browser doesn't support geolocation")
      return
    }

    this.locationRetryCount = 0
    this.attemptGeolocation()
  }

  attemptGeolocation() {
    this.showNearbyLoading()

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
        maximumAge: 0
      }
    )
  }

  handleLocationSuccess(position) {
    this.latValue = position.coords.latitude
    this.lngValue = position.coords.longitude
    this.nearbyActiveValue = true

    // Update hidden inputs and submit form
    if (this.hasNearbyCoordsTarget) {
      const latInput = this.nearbyCoordsTarget.querySelector('input[name="lat"]')
      const lngInput = this.nearbyCoordsTarget.querySelector('input[name="lng"]')
      if (latInput) latInput.value = this.latValue
      if (lngInput) lngInput.value = this.lngValue
    }

    this.showNearbySuccess()
    this.submitForm()
  }

  handleLocationError(error) {
    // Retry with lower accuracy if first attempt failed
    if (this.locationRetryCount < this.maxLocationRetries) {
      this.locationRetryCount++
      this.attemptGeolocation()
      return
    }

    let message = "Unable to get location"
    switch (error.code) {
      case error.PERMISSION_DENIED:
        message = "Location permission denied"
        break
      case error.POSITION_UNAVAILABLE:
        message = "Location unavailable"
        break
      case error.TIMEOUT:
        message = "Location request timed out"
        break
    }

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
        Locating...
      `
    }
    if (this.hasNearbyStatusTarget) {
      this.nearbyStatusTarget.textContent = ""
      this.nearbyStatusTarget.classList.add("hidden")
    }
  }

  showNearbySuccess() {
    if (this.hasNearbyButtonTarget) {
      this.nearbyButtonTarget.disabled = false
      this.nearbyButtonTarget.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
        </svg>
        Nearby
      `
    }
    this.updateNearbyUI()
  }

  showNearbyError(message) {
    if (this.hasNearbyButtonTarget) {
      this.nearbyButtonTarget.disabled = false
      this.nearbyButtonTarget.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
        </svg>
        Nearby
      `
    }
    if (this.hasNearbyStatusTarget) {
      this.nearbyStatusTarget.textContent = message
      this.nearbyStatusTarget.classList.remove("hidden")
      this.nearbyStatusTarget.classList.add("text-red-600", "dark:text-red-400")
    }
  }

  updateNearbyUI() {
    if (this.nearbyActiveValue && this.hasNearbyBadgeTarget) {
      this.nearbyBadgeTarget.classList.remove("hidden")
    }
    if (this.hasClearNearbyTarget) {
      if (this.nearbyActiveValue) {
        this.clearNearbyTarget.classList.remove("hidden")
      } else {
        this.clearNearbyTarget.classList.add("hidden")
      }
    }
  }

  clearNearby(event) {
    event.preventDefault()

    this.latValue = 0
    this.lngValue = 0
    this.nearbyActiveValue = false

    // Clear hidden inputs
    if (this.hasNearbyCoordsTarget) {
      const latInput = this.nearbyCoordsTarget.querySelector('input[name="lat"]')
      const lngInput = this.nearbyCoordsTarget.querySelector('input[name="lng"]')
      if (latInput) latInput.value = ""
      if (lngInput) lngInput.value = ""
    }

    if (this.hasNearbyBadgeTarget) {
      this.nearbyBadgeTarget.classList.add("hidden")
    }
    if (this.hasClearNearbyTarget) {
      this.clearNearbyTarget.classList.add("hidden")
    }

    this.submitForm()
  }

  // Filter change handlers
  filterChanged(event) {
    this.submitForm()
  }

  // Clear all filters
  clearAll(event) {
    event.preventDefault()

    // Reset the form
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }

    // Clear nearby
    this.latValue = 0
    this.lngValue = 0
    this.nearbyActiveValue = false

    if (this.hasNearbyCoordsTarget) {
      const latInput = this.nearbyCoordsTarget.querySelector('input[name="lat"]')
      const lngInput = this.nearbyCoordsTarget.querySelector('input[name="lng"]')
      if (latInput) latInput.value = ""
      if (lngInput) lngInput.value = ""
    }

    // Navigate to clean URL
    window.location.href = window.location.pathname
  }

  // Submit form
  submitForm() {
    if (this.hasFormTarget) {
      this.formTarget.submit()
    }
  }

  // City search functionality
  searchCities(event) {
    const query = event.target.value.trim()

    if (query.length < 2) {
      this.hideCityResults()
      return
    }

    this.fetchCities(query)
  }

  async fetchCities(query) {
    try {
      const response = await fetch(`/plans/search_cities?q=${encodeURIComponent(query)}`)
      const data = await response.json()

      if (data.cities && data.cities.length > 0) {
        this.showCityResults(data.cities)
      } else {
        this.hideCityResults()
      }
    } catch (error) {
      console.error("City search error:", error)
      this.hideCityResults()
    }
  }

  showCityResults(cities) {
    // Implementation would show dropdown with city results
    // This is a simplified version - the actual dropdown rendering
    // would be handled via targets
  }

  hideCityResults() {
    // Hide the city results dropdown
  }

  selectCity(event) {
    const cityId = event.currentTarget.dataset.cityId
    const cityName = event.currentTarget.dataset.cityName

    if (this.hasCitySelectTarget) {
      this.citySelectTarget.value = cityId
    }

    this.hideCityResults()
    this.submitForm()
  }

  // Toggle mobile filters
  toggleFilters(event) {
    event.preventDefault()
    this.filtersExpandedValue = !this.filtersExpandedValue
    this.updateFiltersVisibility()
  }

  updateFiltersVisibility() {
    if (this.hasFilterContentTarget) {
      if (this.filtersExpandedValue) {
        this.filterContentTarget.classList.remove("hidden")
        this.filterContentTarget.classList.add("block")
      } else {
        this.filterContentTarget.classList.add("hidden")
        this.filterContentTarget.classList.remove("block")
      }
    }

    if (this.hasToggleIconTarget) {
      if (this.filtersExpandedValue) {
        this.toggleIconTarget.classList.add("rotate-180")
      } else {
        this.toggleIconTarget.classList.remove("rotate-180")
      }
    }
  }
}
