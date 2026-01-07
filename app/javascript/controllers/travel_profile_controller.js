import { Controller } from "@hotwired/stimulus"

// Travel Profile Controller
// Manages user's travel data in localStorage including:
// - Visited locations
// - Favorite locations/experiences
// - Recently viewed items
// - Badges/achievements
// - Saved plans
//
// When user is logged in, profile is synced to the server for permanent storage.

export default class extends Controller {
  static targets = [
    "visitedCount",
    "favoritesCount",
    "badgesCount",
    "favoriteButton",
    "visitedButton",
    "badgesList",
    "recentlyViewed",
    "syncStatus",
    "userInfo",
    "visitedList",
    "favoritesList",
    "visitedShowMore",
    "favoritesShowMore",
    "badgesShowMore",
    "recentShowMore",
    "feedbackMessage"
  ]

  // Pagination settings
  static ITEMS_PER_PAGE = 5

  static values = {
    itemId: String, // UUID string
    itemType: String, // "location", "experience", "plan"
    itemName: String,
    loggedIn: Boolean,
    username: String,
    syncUrl: String,
    locationLat: Number,
    locationLng: Number,
    maxDistanceMeters: { type: Number, default: 500 },
    translations: Object // I18n translations passed from Rails
  }

  static STORAGE_KEY = "usput_travel_profile"
  static BADGES = {
    first_visit: { id: "first_visit", name: "Prvi Korak", nameEn: "First Step", icon: "👣", description: "Posjetio prvu lokaciju" },
    explorer_5: { id: "explorer_5", name: "Istraživač", nameEn: "Explorer", icon: "🧭", description: "Posjetio 5 lokacija" },
    explorer_10: { id: "explorer_10", name: "Avanturista", nameEn: "Adventurer", icon: "🎒", description: "Posjetio 10 lokacija" },
    explorer_25: { id: "explorer_25", name: "Putnik", nameEn: "Traveler", icon: "✈️", description: "Posjetio 25 lokacija" },
    culture_lover: { id: "culture_lover", name: "Ljubitelj Kulture", nameEn: "Culture Lover", icon: "🏛️", description: "Posjetio 5 kulturnih lokacija" },
    foodie: { id: "foodie", name: "Gurmanski Putnik", nameEn: "Foodie Traveler", icon: "🍽️", description: "Posjetio 5 restorana" },
    nature_lover: { id: "nature_lover", name: "Prirodnjak", nameEn: "Nature Lover", icon: "🌲", description: "Posjetio 5 prirodnih lokacija" },
    city_hopper: { id: "city_hopper", name: "Gradski Skakač", nameEn: "City Hopper", icon: "🏙️", description: "Posjetio lokacije u 3 različita grada" },
    all_seasons: { id: "all_seasons", name: "Sva Godišnja Doba", nameEn: "All Seasons", icon: "🗓️", description: "Posjetio lokacije u sva 4 godišnja doba" },
    collector: { id: "collector", name: "Kolekcionar", nameEn: "Collector", icon: "⭐", description: "Dodao 10 omiljenih lokacija" }
  }

  connect() {
    this.loadProfile()

    // Initialize pagination state
    this.visitedShown = this.constructor.ITEMS_PER_PAGE
    this.favoritesShown = this.constructor.ITEMS_PER_PAGE
    this.badgesShown = this.constructor.ITEMS_PER_PAGE
    this.recentShown = this.constructor.ITEMS_PER_PAGE

    this.updateUI()
    this.trackView()

    // If user is logged in, sync profile from server
    if (this.loggedInValue) {
      this.syncFromServer()
    }
  }

  // Get translation from translations value or return fallback
  t(key, replacements = {}) {
    const translations = this.translationsValue || {}
    let text = translations[key]

    if (!text) {
      // Fallback to hardcoded defaults if translations not available
      return this.getFallbackTranslation(key, replacements)
    }

    // Replace placeholders like %{distance} with actual values
    Object.keys(replacements).forEach(placeholder => {
      text = text.replace(new RegExp(`%\\{${placeholder}\\}`, 'g'), replacements[placeholder])
    })

    return text
  }

  // Get badge translation
  getBadgeTranslation(badgeId, field) {
    const translations = this.translationsValue || {}
    const badges = translations.badges || {}
    const badge = badges[badgeId]
    if (badge && badge[field]) {
      return badge[field]
    }
    // Fallback to static BADGES
    const staticBadge = this.constructor.BADGES[badgeId]
    return staticBadge ? staticBadge[field] : ''
  }

  // Fallback translations for when translations value is not set
  getFallbackTranslation(key, replacements = {}) {
    const fallbacks = {
      checking_location: "Provjeravamo vašu lokaciju...",
      visit_recorded: "Posjeta uspješno zabilježena!",
      removed_from_visited: "Uklonjeno iz posjećenih",
      removed_from_favorites: "Uklonjeno iz omiljenih",
      added_to_favorites: "Dodano u omiljene!",
      too_far_from_location: `Predaleko ste od lokacije (${replacements.distance || ''}). Morate biti unutar ${replacements.max_distance || '500'}m.`,
      location_no_coordinates: "Lokacija nema koordinate za validaciju",
      geolocation_not_supported: "Vaš preglednik ne podržava geolokaciju",
      geolocation_permission_denied: "Pristup lokaciji je odbijen. Dozvolite pristup u postavkama preglednika.",
      geolocation_unavailable: "Lokacija nije dostupna. Provjerite da li je GPS uključen.",
      geolocation_timeout: "Vrijeme za dobijanje lokacije je isteklo. Pokušajte ponovo.",
      geolocation_error: "Greška pri dobijanju lokacije",
      validation_error: "Greška pri validaciji posjete",
      not_close_enough: "Niste dovoljno blizu lokacije",
      sync_syncing: "Sinkronizacija...",
      sync_saved: "Sačuvano",
      sync_error: "Greška pri sinkronizaciji",
      no_badges_yet: "Još nemaš nijedan badge. Posjeti lokacije da ih zaradiš!",
      no_recent_items: "Nema nedavno pregledanih stavki.",
      no_visited_locations: "Još nisi posjetio nijednu lokaciju",
      no_favorite_locations: "Još nemaš omiljenih lokacija",
      new_badge: "Novi Badge!",
      badge_awesome: "Super!",
      profile_exported: "Profil exportovan!",
      profile_imported: "Profil uspješno importovan!",
      profile_import_error: "Greška pri importu profila",
      profile_cleared: "Profil obrisan",
      confirm_clear: "Jesi li siguran da želiš obrisati sve podatke profila? Ova akcija se ne može poništiti.",
      confirm_replace_or_merge: "Želiš li zamijeniti trenutni profil ili spojiti podatke?",
      show_more: `Prikaži još (${replacements.count || ''})`,
      time_just_now: "Upravo sada",
      time_minutes_ago: `Prije ${replacements.count || ''} min`,
      time_hours_ago: `Prije ${replacements.count || ''}h`,
      time_days_ago: `Prije ${replacements.count || ''} dana`
    }
    return fallbacks[key] || key
  }

  // Load profile from localStorage
  loadProfile() {
    const stored = localStorage.getItem(this.constructor.STORAGE_KEY)
    this.profile = stored ? JSON.parse(stored) : this.defaultProfile()
  }

  // Save profile to localStorage and optionally sync to server
  saveProfile() {
    localStorage.setItem(this.constructor.STORAGE_KEY, JSON.stringify(this.profile))
    this.updateUI()

    // If user is logged in, sync to server
    if (this.loggedInValue) {
      this.syncToServer()
    }
  }

  // Sync profile to server (for logged-in users)
  async syncToServer() {
    if (!this.loggedInValue) return

    try {
      this.updateSyncStatus("syncing")

      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/travel_profile/sync", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ travel_profile_data: this.profile })
      })

      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          this.updateSyncStatus("synced")
          // Don't overwrite local profile - local state is authoritative
          // Server sync is just for persistence, not for merging
        }
      } else {
        this.updateSyncStatus("error")
      }
    } catch (error) {
      console.error("Sync error:", error)
      this.updateSyncStatus("error")
    }
  }

  // Sync profile from server (on login)
  async syncFromServer() {
    if (!this.loggedInValue) return

    try {
      this.updateSyncStatus("syncing")

      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/travel_profile/sync", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ travel_profile_data: this.profile })
      })

      if (response.ok) {
        const data = await response.json()
        if (data.success && data.travel_profile_data) {
          // Merge server data with local data
          this.profile = data.travel_profile_data
          localStorage.setItem(this.constructor.STORAGE_KEY, JSON.stringify(this.profile))
          this.updateUI()
          this.updateSyncStatus("synced")
        }
      } else {
        this.updateSyncStatus("error")
      }
    } catch (error) {
      console.error("Sync from server error:", error)
      this.updateSyncStatus("error")
    }
  }

  // Update sync status indicator
  updateSyncStatus(status) {
    if (!this.hasSyncStatusTarget) return

    const statusEl = this.syncStatusTarget
    statusEl.classList.remove("hidden")

    switch (status) {
      case "syncing":
        statusEl.innerHTML = `<span class="text-blue-500 text-xs">${this.t('sync_syncing')}</span>`
        break
      case "synced":
        statusEl.innerHTML = `<span class="text-emerald-500 text-xs">✓ ${this.t('sync_saved')}</span>`
        setTimeout(() => statusEl.classList.add("hidden"), 2000)
        break
      case "error":
        statusEl.innerHTML = `<span class="text-red-500 text-xs">⚠ ${this.t('sync_error')}</span>`
        break
    }
  }

  // Default profile structure
  defaultProfile() {
    return {
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      visited: [], // { id, type, name, visitedAt, city, tags }
      favorites: [], // { id, type, name, addedAt }
      recentlyViewed: [], // { id, type, name, viewedAt } - last 20
      badges: [], // { id, earnedAt }
      savedPlans: [], // { id, name, savedAt, data }
      stats: {
        totalVisits: 0,
        citiesVisited: [],
        seasonsVisited: []
      }
    }
  }

  // Track current page view
  trackView() {
    if (!this.hasItemIdValue || !this.hasItemTypeValue) return

    const item = {
      id: this.itemIdValue,
      type: this.itemTypeValue,
      name: this.itemNameValue || `${this.itemTypeValue} ${this.itemIdValue}`,
      viewedAt: new Date().toISOString()
    }

    // Remove if already in recently viewed
    this.profile.recentlyViewed = this.profile.recentlyViewed.filter(
      v => !(String(v.id) === String(item.id) && v.type === item.type)
    )

    // Add to front
    this.profile.recentlyViewed.unshift(item)

    // Keep only last 20
    this.profile.recentlyViewed = this.profile.recentlyViewed.slice(0, 20)

    this.profile.updatedAt = new Date().toISOString()
    this.saveProfile()
  }

  // Toggle favorite status
  toggleFavorite(event) {
    event.preventDefault()

    if (!this.hasItemIdValue || !this.hasItemTypeValue) return

    const item = {
      id: this.itemIdValue,
      type: this.itemTypeValue,
      name: this.itemNameValue || `${this.itemTypeValue} ${this.itemIdValue}`,
      addedAt: new Date().toISOString()
    }

    const existingIndex = this.profile.favorites.findIndex(
      f => String(f.id) === String(item.id) && f.type === item.type
    )

    if (existingIndex >= 0) {
      // Remove from favorites
      this.profile.favorites.splice(existingIndex, 1)
      this.showFeedback(this.t('removed_from_favorites'), "success")
    } else {
      // Add to favorites
      this.profile.favorites.push(item)
      this.showFeedback(this.t('added_to_favorites'), "success")
      this.checkBadges()
    }

    this.profile.updatedAt = new Date().toISOString()
    this.saveProfile()
  }

  // Mark location as visited - requires geolocation validation
  markVisited(event) {
    event.preventDefault()

    if (!this.hasItemIdValue || !this.hasItemTypeValue) return

    const button = event.currentTarget

    // Check if already visited - allow removal without geolocation
    const existingIndex = this.profile.visited.findIndex(
      v => String(v.id) === String(this.itemIdValue) && v.type === this.itemTypeValue
    )

    if (existingIndex >= 0) {
      // Already visited - remove (no geolocation needed)
      this.profile.visited.splice(existingIndex, 1)
      this.profile.stats.totalVisits--
      this.showFeedback(this.t('removed_from_visited'), "success")
      this.profile.updatedAt = new Date().toISOString()
      this.saveProfile()
      return
    }

    // For new visits, require geolocation validation
    this.showFeedback(this.t('checking_location'), "info")
    button.disabled = true

    this.requestGeolocationForVisit(button)
  }

  // Request geolocation and validate visit
  requestGeolocationForVisit(button) {
    if (!navigator.geolocation) {
      this.showFeedback(this.t('geolocation_not_supported'), "error")
      button.disabled = false
      return
    }

    navigator.geolocation.getCurrentPosition(
      (position) => this.handleVisitGeolocationSuccess(position, button),
      (error) => this.handleVisitGeolocationError(error, button),
      {
        enableHighAccuracy: true,
        timeout: 20000,
        maximumAge: 0
      }
    )
  }

  // Handle successful geolocation for visit
  async handleVisitGeolocationSuccess(position, button) {
    const userLat = position.coords.latitude
    const userLng = position.coords.longitude

    // For logged-in users, validate on server
    if (this.loggedInValue) {
      await this.validateVisitOnServer(userLat, userLng, button)
    } else {
      // For guests, validate locally
      this.validateVisitLocally(userLat, userLng, button)
    }
  }

  // Validate visit on server (for logged-in users)
  async validateVisitOnServer(userLat, userLng, button) {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/travel_profile/validate_visit", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          location_id: this.itemIdValue,
          user_lat: userLat,
          user_lng: userLng
        })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        // Server validated and added to profile
        this.profile = data.travel_profile_data
        localStorage.setItem(this.constructor.STORAGE_KEY, JSON.stringify(this.profile))
        this.updateUI()
        this.showFeedback(data.message || this.t('visit_recorded'), "success")
        this.checkBadges()
      } else {
        // Validation failed
        this.showFeedback(data.error || this.t('not_close_enough'), "error")
      }
    } catch (error) {
      console.error("Visit validation error:", error)
      this.showFeedback(this.t('validation_error'), "error")
    } finally {
      button.disabled = false
    }
  }

  // Validate visit locally (for guest users)
  validateVisitLocally(userLat, userLng, button) {
    // Check if location has coordinates
    if (!this.hasLocationLatValue || !this.hasLocationLngValue) {
      this.showFeedback(this.t('location_no_coordinates'), "error")
      button.disabled = false
      return
    }

    const locationLat = this.locationLatValue
    const locationLng = this.locationLngValue
    const maxDistanceMeters = this.maxDistanceMetersValue

    // Calculate distance using Haversine formula
    const distanceMeters = this.calculateDistance(userLat, userLng, locationLat, locationLng)

    if (distanceMeters <= maxDistanceMeters) {
      // User is close enough - add to visited
      const city = button.dataset.city || null
      const tags = button.dataset.tags ? button.dataset.tags.split(",") : []

      const item = {
        id: this.itemIdValue,
        type: this.itemTypeValue,
        name: this.itemNameValue || `${this.itemTypeValue} ${this.itemIdValue}`,
        visitedAt: new Date().toISOString(),
        city: city,
        tags: tags
      }

      this.profile.visited.push(item)
      this.profile.stats.totalVisits++

      // Track city
      if (city && !this.profile.stats.citiesVisited.includes(city)) {
        this.profile.stats.citiesVisited.push(city)
      }

      // Track season
      const currentSeason = this.getCurrentSeason()
      if (!this.profile.stats.seasonsVisited.includes(currentSeason)) {
        this.profile.stats.seasonsVisited.push(currentSeason)
      }

      this.profile.updatedAt = new Date().toISOString()
      this.saveProfile()
      this.showFeedback(this.t('visit_recorded'), "success")
      this.checkBadges()
    } else {
      // User is too far
      const distanceText = distanceMeters >= 1000
        ? `${(distanceMeters / 1000).toFixed(1)} km`
        : `${Math.round(distanceMeters)} m`
      this.showFeedback(this.t('too_far_from_location', { distance: distanceText, max_distance: maxDistanceMeters }), "error")
    }

    button.disabled = false
  }

  // Handle geolocation error
  handleVisitGeolocationError(error, button) {
    let message = this.t('geolocation_error')

    switch (error.code) {
      case error.PERMISSION_DENIED:
        message = this.t('geolocation_permission_denied')
        break
      case error.POSITION_UNAVAILABLE:
        message = this.t('geolocation_unavailable')
        break
      case error.TIMEOUT:
        message = this.t('geolocation_timeout')
        break
    }

    this.showFeedback(message, "error")
    button.disabled = false
  }

  // Calculate distance between two coordinates using Haversine formula
  calculateDistance(lat1, lng1, lat2, lng2) {
    const R = 6371000 // Earth's radius in meters
    const dLat = this.toRad(lat2 - lat1)
    const dLng = this.toRad(lng2 - lng1)
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) * Math.cos(this.toRad(lat2)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    return R * c
  }

  // Convert degrees to radians
  toRad(deg) {
    return deg * (Math.PI / 180)
  }

  // Check and award badges
  checkBadges() {
    const newBadges = []
    const visited = this.profile.visited
    const favorites = this.profile.favorites

    // First visit
    if (visited.length >= 1 && !this.hasBadge("first_visit")) {
      newBadges.push("first_visit")
    }

    // Explorer badges
    if (visited.length >= 5 && !this.hasBadge("explorer_5")) {
      newBadges.push("explorer_5")
    }
    if (visited.length >= 10 && !this.hasBadge("explorer_10")) {
      newBadges.push("explorer_10")
    }
    if (visited.length >= 25 && !this.hasBadge("explorer_25")) {
      newBadges.push("explorer_25")
    }

    // Culture lover
    const culturalVisits = visited.filter(v =>
      v.tags && (v.tags.includes("culture") || v.tags.includes("history") || v.tags.includes("museum"))
    ).length
    if (culturalVisits >= 5 && !this.hasBadge("culture_lover")) {
      newBadges.push("culture_lover")
    }

    // Foodie
    const foodVisits = visited.filter(v =>
      v.type === "restaurant" || (v.tags && v.tags.includes("food"))
    ).length
    if (foodVisits >= 5 && !this.hasBadge("foodie")) {
      newBadges.push("foodie")
    }

    // Nature lover
    const natureVisits = visited.filter(v =>
      v.tags && (v.tags.includes("nature") || v.tags.includes("park") || v.tags.includes("mountain"))
    ).length
    if (natureVisits >= 5 && !this.hasBadge("nature_lover")) {
      newBadges.push("nature_lover")
    }

    // City hopper
    if (this.profile.stats.citiesVisited.length >= 3 && !this.hasBadge("city_hopper")) {
      newBadges.push("city_hopper")
    }

    // All seasons
    if (this.profile.stats.seasonsVisited.length >= 4 && !this.hasBadge("all_seasons")) {
      newBadges.push("all_seasons")
    }

    // Collector
    if (favorites.length >= 10 && !this.hasBadge("collector")) {
      newBadges.push("collector")
    }

    // Award new badges
    newBadges.forEach(badgeId => {
      this.profile.badges.push({
        id: badgeId,
        earnedAt: new Date().toISOString()
      })
      const badge = this.constructor.BADGES[badgeId]
      this.showBadgeEarned(badge)
    })
  }

  hasBadge(badgeId) {
    return this.profile.badges.some(b => b.id === badgeId)
  }

  getCurrentSeason() {
    const month = new Date().getMonth() + 1
    if (month >= 3 && month <= 5) return "spring"
    if (month >= 6 && month <= 8) return "summer"
    if (month >= 9 && month <= 11) return "autumn"
    return "winter"
  }

  // Update UI elements
  updateUI() {
    // Update counters
    if (this.hasVisitedCountTarget) {
      this.visitedCountTarget.textContent = this.profile.visited.length
    }
    if (this.hasFavoritesCountTarget) {
      this.favoritesCountTarget.textContent = this.profile.favorites.length
    }
    if (this.hasBadgesCountTarget) {
      this.badgesCountTarget.textContent = this.profile.badges.length
    }

    // Update favorite button state
    if (this.hasFavoriteButtonTarget && this.hasItemIdValue && this.hasItemTypeValue) {
      const isFavorite = this.profile.favorites.some(
        f => String(f.id) === String(this.itemIdValue) && f.type === this.itemTypeValue
      )
      this.favoriteButtonTarget.setAttribute("aria-pressed", isFavorite)

      // Toggle heart icons (empty/filled)
      const emptyHeart = this.favoriteButtonTarget.querySelector(".heart-empty")
      const filledHeart = this.favoriteButtonTarget.querySelector(".heart-filled")
      if (emptyHeart && filledHeart) {
        emptyHeart.classList.toggle("hidden", isFavorite)
        filledHeart.classList.toggle("hidden", !isFavorite)
      }
    }

    // Update visited button state
    if (this.hasVisitedButtonTarget && this.hasItemIdValue && this.hasItemTypeValue) {
      const isVisited = this.profile.visited.some(
        v => String(v.id) === String(this.itemIdValue) && v.type === this.itemTypeValue
      )

      // Remove default background classes and add visited state
      if (isVisited) {
        this.visitedButtonTarget.classList.remove("bg-white/90", "dark:bg-gray-800/90", "bg-gray-100", "dark:bg-gray-800", "hover:bg-emerald-100", "dark:hover:bg-emerald-900/30")
        this.visitedButtonTarget.classList.add("bg-emerald-500", "!text-white")
        // Update text color for children
        const textSpan = this.visitedButtonTarget.querySelector("span")
        if (textSpan) {
          textSpan.classList.remove("text-gray-700", "dark:text-gray-300", "group-hover:text-emerald-500")
          textSpan.classList.add("!text-white")
        }
      } else {
        this.visitedButtonTarget.classList.add("bg-gray-100", "dark:bg-gray-800", "hover:bg-emerald-100", "dark:hover:bg-emerald-900/30")
        this.visitedButtonTarget.classList.remove("bg-emerald-500", "!text-white")
        // Restore text color for children
        const textSpan = this.visitedButtonTarget.querySelector("span")
        if (textSpan) {
          textSpan.classList.add("text-gray-700", "dark:text-gray-300", "group-hover:text-emerald-500")
          textSpan.classList.remove("!text-white")
        }
      }
      this.visitedButtonTarget.setAttribute("aria-pressed", isVisited)

      // Toggle checkmark icons (empty/filled) and update their colors
      const emptyCheck = this.visitedButtonTarget.querySelector(".check-empty")
      const filledCheck = this.visitedButtonTarget.querySelector(".check-filled")
      if (emptyCheck && filledCheck) {
        emptyCheck.classList.toggle("hidden", isVisited)
        filledCheck.classList.toggle("hidden", !isVisited)

        // Update icon colors when visited
        if (isVisited) {
          emptyCheck.classList.remove("text-gray-600", "dark:text-gray-300", "group-hover:text-emerald-500")
          emptyCheck.classList.add("!text-white")
          filledCheck.classList.add("!text-white")
        } else {
          emptyCheck.classList.add("text-gray-600", "dark:text-gray-300", "group-hover:text-emerald-500")
          emptyCheck.classList.remove("!text-white")
          filledCheck.classList.remove("!text-white")
        }
      }
    }

    // Render badges list
    if (this.hasBadgesListTarget) {
      this.renderBadges()
    }

    // Render recently viewed
    if (this.hasRecentlyViewedTarget) {
      this.renderRecentlyViewed()
    }

    // Render visited list (for profile page)
    if (this.hasVisitedListTarget) {
      this.renderVisitedList()
    }

    // Render favorites list (for profile page)
    if (this.hasFavoritesListTarget) {
      this.renderFavoritesList()
    }
  }

  renderBadges() {
    const container = this.badgesListTarget
    container.innerHTML = ""

    if (this.profile.badges.length === 0) {
      container.innerHTML = `<p class="text-gray-500 text-sm">${this.t('no_badges_yet')}</p>`
      return
    }

    const badgesToShow = this.profile.badges.slice(0, this.badgesShown)
    badgesToShow.forEach(earned => {
      const badge = this.constructor.BADGES[earned.id]
      if (!badge) return

      const badgeName = this.getBadgeTranslation(earned.id, 'name') || badge.name
      const badgeDescription = this.getBadgeTranslation(earned.id, 'description') || badge.description

      const el = document.createElement("div")
      el.className = "flex items-center p-3 bg-gray-50 dark:bg-gray-700 rounded-lg"
      el.innerHTML = `
        <span class="text-3xl mr-3">${badge.icon}</span>
        <div>
          <p class="font-medium text-gray-900 dark:text-white">${badgeName}</p>
          <p class="text-sm text-gray-500 dark:text-gray-400">${badgeDescription}</p>
        </div>
      `
      container.appendChild(el)
    })

    this.updateShowMoreButton("badgesShowMore", this.badgesShown, this.profile.badges.length)
  }

  renderRecentlyViewed() {
    const container = this.recentlyViewedTarget
    container.innerHTML = ""

    if (this.profile.recentlyViewed.length === 0) {
      container.innerHTML = `<p class="text-gray-500 dark:text-gray-400 text-sm py-4 text-center">${this.t('no_recent_items')}</p>`
      this.updateShowMoreButton("recentShowMore", 0, 0)
      return
    }

    const itemsToShow = this.profile.recentlyViewed.slice(0, this.recentShown)
    itemsToShow.forEach(item => {
      const el = document.createElement("a")
      el.href = `/${item.type}s/${item.id}`
      el.className = "flex items-center p-3 bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 rounded-lg transition-colors"
      el.innerHTML = `
        <div class="w-8 h-8 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center mr-3 flex-shrink-0">
          <svg class="w-4 h-4 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
          </svg>
        </div>
        <div class="flex-grow min-w-0">
          <p class="font-medium text-gray-900 dark:text-white truncate">${item.name}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400">${this.formatDate(item.viewedAt)}</p>
        </div>
      `
      container.appendChild(el)
    })

    this.updateShowMoreButton("recentShowMore", this.recentShown, this.profile.recentlyViewed.length)
  }

  renderVisitedList() {
    const container = this.visitedListTarget
    container.innerHTML = ""

    if (this.profile.visited.length === 0) {
      container.innerHTML = `<p class="text-gray-500 dark:text-gray-400 text-sm py-4 text-center">${this.t('no_visited_locations')}</p>`
      this.updateShowMoreButton("visitedShowMore", 0, 0)
      return
    }

    const itemsToShow = this.profile.visited.slice(0, this.visitedShown)
    itemsToShow.forEach(item => {
      const el = document.createElement("a")
      el.href = `/${item.type}s/${item.id}`
      el.className = "flex items-center p-3 bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 rounded-lg transition-colors"
      el.innerHTML = `
        <div class="w-8 h-8 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg flex items-center justify-center mr-3 flex-shrink-0">
          <svg class="w-4 h-4 text-emerald-600 dark:text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
          </svg>
        </div>
        <div class="flex-grow min-w-0">
          <p class="font-medium text-gray-900 dark:text-white truncate">${item.name}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400">${item.city ? item.city + " - " : ""}${this.formatDate(item.visitedAt)}</p>
        </div>
      `
      container.appendChild(el)
    })

    this.updateShowMoreButton("visitedShowMore", this.visitedShown, this.profile.visited.length)
  }

  renderFavoritesList() {
    const container = this.favoritesListTarget
    container.innerHTML = ""

    if (this.profile.favorites.length === 0) {
      container.innerHTML = `<p class="text-gray-500 dark:text-gray-400 text-sm py-4 text-center">${this.t('no_favorite_locations')}</p>`
      this.updateShowMoreButton("favoritesShowMore", 0, 0)
      return
    }

    const itemsToShow = this.profile.favorites.slice(0, this.favoritesShown)
    itemsToShow.forEach(item => {
      const el = document.createElement("a")
      el.href = `/${item.type}s/${item.id}`
      el.className = "flex items-center p-3 bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 rounded-lg transition-colors"
      el.innerHTML = `
        <div class="w-8 h-8 bg-red-100 dark:bg-red-900/30 rounded-lg flex items-center justify-center mr-3 flex-shrink-0">
          <svg class="w-4 h-4 text-red-500" fill="currentColor" viewBox="0 0 24 24">
            <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"></path>
          </svg>
        </div>
        <div class="flex-grow min-w-0">
          <p class="font-medium text-gray-900 dark:text-white truncate">${item.name}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400">${this.formatDate(item.addedAt)}</p>
        </div>
      `
      container.appendChild(el)
    })

    this.updateShowMoreButton("favoritesShowMore", this.favoritesShown, this.profile.favorites.length)
  }

  formatDate(isoString) {
    const date = new Date(isoString)
    const now = new Date()
    const diffMs = now - date
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)

    if (diffMins < 1) return this.t('time_just_now')
    if (diffMins < 60) return this.t('time_minutes_ago', { count: diffMins })
    if (diffHours < 24) return this.t('time_hours_ago', { count: diffHours })
    if (diffDays < 7) return this.t('time_days_ago', { count: diffDays })
    return date.toLocaleDateString()
  }

  // Export profile as JSON
  exportProfile(event) {
    event.preventDefault()

    const exportData = {
      ...this.profile,
      exportedAt: new Date().toISOString(),
      version: "1.0"
    }

    const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: "application/json" })
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = url
    a.download = `usput-travel-profile-${new Date().toISOString().split("T")[0]}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)

    this.showToast(this.t('profile_exported'), "success")
  }

  // Export profile as PDF - Boarding Pass design
  exportProfilePdf(event) {
    event.preventDefault()

    const memberSince = new Date(this.profile.createdAt).toLocaleDateString("bs-BA", { year: "numeric", month: "long" })
    const topBadges = this.profile.badges.slice(0, 4).map(b => this.constructor.BADGES[b.id]).filter(Boolean)
    const recentVisits = this.profile.visited.slice(0, 5)
    const topCity = this.profile.stats.citiesVisited[0] || "BiH"
    const flightNumber = "UP" + Math.random().toString().substring(2, 6)
    const seatNumber = String.fromCharCode(65 + Math.floor(Math.random() * 6)) + Math.floor(Math.random() * 30 + 1)
    const gate = String.fromCharCode(65 + Math.floor(Math.random() * 4)) + Math.floor(Math.random() * 20 + 1)
    const boardingTime = new Date()
    boardingTime.setHours(boardingTime.getHours() + 2)

    const printWindow = window.open("", "_blank")
    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Boarding Pass - Usput.ba</title>
        <style>
          @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Inter:wght@400;500;600;700;800&display=swap');

          * { margin: 0; padding: 0; box-sizing: border-box; }

          body {
            font-family: 'Inter', system-ui, sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            min-height: 100vh;
            padding: 2rem;
            display: flex;
            justify-content: center;
            align-items: center;
          }

          .boarding-pass {
            width: 100%;
            max-width: 900px;
            background: white;
            border-radius: 20px;
            overflow: hidden;
            box-shadow: 0 25px 80px rgba(0,0,0,0.4);
            display: flex;
          }

          /* Main Section */
          .main-section {
            flex: 1;
            padding: 0;
          }

          /* Header Strip */
          .header-strip {
            background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
            padding: 1.25rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }

          .airline-brand {
            display: flex;
            align-items: center;
            gap: 0.75rem;
          }

          .airline-logo {
            width: 40px;
            height: 40px;
            object-fit: contain;
          }

          .airline-name {
            color: white;
            font-size: 1.5rem;
            font-weight: 800;
            letter-spacing: -0.5px;
          }

          .pass-type {
            background: rgba(255,255,255,0.2);
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1.5px;
          }

          /* Route Section */
          .route-section {
            padding: 2rem;
            background: linear-gradient(180deg, #f8fafc 0%, white 100%);
            border-bottom: 2px dashed #e2e8f0;
            position: relative;
          }

          .route-section::before,
          .route-section::after {
            content: '';
            position: absolute;
            bottom: -12px;
            width: 24px;
            height: 24px;
            background: #0f172a;
            border-radius: 50%;
          }

          .route-section::before { left: -12px; }
          .route-section::after { right: -12px; }

          .route-display {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 1.5rem;
          }

          .airport {
            text-align: center;
          }

          .airport-code {
            font-family: 'JetBrains Mono', monospace;
            font-size: 3rem;
            font-weight: 700;
            color: #1e293b;
            letter-spacing: -2px;
            line-height: 1;
          }

          .airport-name {
            font-size: 0.8rem;
            color: #64748b;
            margin-top: 0.25rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
          }

          .flight-path {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 0 2rem;
            position: relative;
          }

          .flight-line {
            width: 100%;
            height: 2px;
            background: linear-gradient(90deg, #2563eb 0%, #60a5fa 50%, #2563eb 100%);
            position: relative;
          }

          .flight-line::before {
            content: '';
            position: absolute;
            left: 0;
            top: -4px;
            width: 10px;
            height: 10px;
            background: #2563eb;
            border-radius: 50%;
          }

          .flight-line::after {
            content: '';
            position: absolute;
            right: 0;
            top: -4px;
            width: 10px;
            height: 10px;
            background: #2563eb;
            border-radius: 50%;
          }

          .plane-icon {
            position: absolute;
            font-size: 1.5rem;
            animation: none;
          }

          .flight-stats {
            display: flex;
            justify-content: center;
            gap: 3rem;
          }

          .flight-stat {
            text-align: center;
          }

          .stat-value {
            font-family: 'JetBrains Mono', monospace;
            font-size: 1.75rem;
            font-weight: 700;
            color: #2563eb;
          }

          .stat-label {
            font-size: 0.65rem;
            color: #94a3b8;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 0.25rem;
          }

          /* Details Section */
          .details-section {
            padding: 1.5rem 2rem;
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 1rem;
            border-bottom: 1px solid #e2e8f0;
          }

          .detail-item {
            text-align: center;
          }

          .detail-label {
            font-size: 0.6rem;
            color: #94a3b8;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 0.25rem;
          }

          .detail-value {
            font-family: 'JetBrains Mono', monospace;
            font-size: 1.1rem;
            font-weight: 600;
            color: #1e293b;
          }

          /* Destinations Section */
          .destinations-section {
            padding: 1.5rem 2rem;
          }

          .section-title {
            font-size: 0.7rem;
            color: #94a3b8;
            text-transform: uppercase;
            letter-spacing: 1.5px;
            margin-bottom: 1rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
          }

          .section-title::after {
            content: '';
            flex: 1;
            height: 1px;
            background: #e2e8f0;
          }

          .destination-list {
            display: flex;
            flex-wrap: wrap;
            gap: 0.5rem;
          }

          .destination-tag {
            background: linear-gradient(135deg, #eff6ff, #dbeafe);
            color: #1e40af;
            padding: 0.4rem 0.75rem;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 600;
            border: 1px solid #bfdbfe;
          }

          /* Badges Row */
          .badges-row {
            padding: 1rem 2rem;
            background: #fefce8;
            display: flex;
            align-items: center;
            gap: 1rem;
            border-top: 1px solid #fef08a;
          }

          .badges-label {
            font-size: 0.65rem;
            color: #a16207;
            text-transform: uppercase;
            letter-spacing: 1px;
            white-space: nowrap;
          }

          .badge-icons {
            display: flex;
            gap: 0.5rem;
          }

          .badge-icon {
            font-size: 1.25rem;
          }

          /* Stub Section (right side) */
          .stub-section {
            width: 200px;
            background: linear-gradient(180deg, #1e293b 0%, #0f172a 100%);
            color: white;
            padding: 1.5rem;
            display: flex;
            flex-direction: column;
            position: relative;
          }

          .stub-section::before {
            content: '';
            position: absolute;
            left: 0;
            top: 0;
            bottom: 0;
            width: 1px;
            background: repeating-linear-gradient(
              to bottom,
              transparent,
              transparent 8px,
              #475569 8px,
              #475569 16px
            );
          }

          .stub-header {
            text-align: center;
            margin-bottom: 1.5rem;
          }

          .stub-logo {
            width: 50px;
            height: 50px;
            margin: 0 auto 0.5rem;
            object-fit: contain;
          }

          .stub-airline {
            font-weight: 700;
            font-size: 1rem;
            margin-bottom: 0.25rem;
          }

          .stub-tagline {
            font-size: 0.6rem;
            color: #94a3b8;
            text-transform: uppercase;
            letter-spacing: 1px;
          }

          .stub-route {
            text-align: center;
            margin-bottom: 1.5rem;
            padding-bottom: 1rem;
            border-bottom: 1px dashed #475569;
          }

          .stub-codes {
            font-family: 'JetBrains Mono', monospace;
            font-size: 1.5rem;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
          }

          .stub-arrow {
            color: #60a5fa;
          }

          .stub-details {
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 1rem;
          }

          .stub-detail {
            text-align: center;
          }

          .stub-label {
            font-size: 0.55rem;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 0.25rem;
          }

          .stub-value {
            font-family: 'JetBrains Mono', monospace;
            font-size: 1.25rem;
            font-weight: 600;
          }

          .stub-barcode {
            margin-top: auto;
            padding-top: 1rem;
            border-top: 1px dashed #475569;
          }

          .barcode-lines {
            display: flex;
            justify-content: center;
            gap: 2px;
            margin-bottom: 0.5rem;
          }

          .barcode-line {
            width: 2px;
            background: white;
            height: 40px;
          }

          .barcode-line:nth-child(odd) { height: 35px; }
          .barcode-line:nth-child(3n) { width: 3px; }
          .barcode-line:nth-child(5n) { width: 1px; height: 40px; }

          .barcode-text {
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.6rem;
            text-align: center;
            color: #94a3b8;
            letter-spacing: 2px;
          }

          @media print {
            body {
              background: white;
              padding: 0;
              -webkit-print-color-adjust: exact;
              print-color-adjust: exact;
            }
            .boarding-pass {
              box-shadow: none;
              border: 2px solid #e2e8f0;
            }
          }
        </style>
      </head>
      <body>
        <div class="boarding-pass">
          <div class="main-section">
            <div class="header-strip">
              <div class="airline-brand">
                <img src="/usput-logo.png" alt="" class="airline-logo" onerror="this.style.display='none'" />
                <span class="airline-name">Usput.ba</span>
              </div>
              <div class="pass-type">Boarding Pass</div>
            </div>

            <div class="route-section">
              <div class="route-display">
                <div class="airport">
                  <div class="airport-code">DOM</div>
                  <div class="airport-name">Tvoj Dom</div>
                </div>
                <div class="flight-path">
                  <div class="flight-line"></div>
                  <span class="plane-icon">✈️</span>
                </div>
                <div class="airport">
                  <div class="airport-code">${topCity.substring(0, 3).toUpperCase()}</div>
                  <div class="airport-name">${topCity}</div>
                </div>
              </div>
              <div class="flight-stats">
                <div class="flight-stat">
                  <div class="stat-value">${this.profile.visited.length}</div>
                  <div class="stat-label">Posjeta</div>
                </div>
                <div class="flight-stat">
                  <div class="stat-value">${this.profile.stats.citiesVisited.length}</div>
                  <div class="stat-label">Gradova</div>
                </div>
                <div class="flight-stat">
                  <div class="stat-value">${this.profile.badges.length}</div>
                  <div class="stat-label">Bedževa</div>
                </div>
                <div class="flight-stat">
                  <div class="stat-value">${this.profile.favorites.length}</div>
                  <div class="stat-label">Favorita</div>
                </div>
              </div>
            </div>

            <div class="details-section">
              <div class="detail-item">
                <div class="detail-label">Let</div>
                <div class="detail-value">${flightNumber}</div>
              </div>
              <div class="detail-item">
                <div class="detail-label">Sjedište</div>
                <div class="detail-value">${seatNumber}</div>
              </div>
              <div class="detail-item">
                <div class="detail-label">Gate</div>
                <div class="detail-value">${gate}</div>
              </div>
              <div class="detail-item">
                <div class="detail-label">Član od</div>
                <div class="detail-value">${memberSince.split(" ")[1] || memberSince}</div>
              </div>
            </div>

            <div class="destinations-section">
              <div class="section-title">Posjećene Destinacije</div>
              <div class="destination-list">
                ${recentVisits.length > 0
                  ? recentVisits.map(v => `<span class="destination-tag">${v.name}</span>`).join("")
                  : '<span class="destination-tag">Čeka te avantura!</span>'
                }
              </div>
            </div>

            ${topBadges.length > 0 ? `
            <div class="badges-row">
              <span class="badges-label">Achievements</span>
              <div class="badge-icons">
                ${topBadges.map(b => `<span class="badge-icon" title="${b.name}">${b.icon}</span>`).join("")}
              </div>
            </div>
            ` : ""}
          </div>

          <div class="stub-section">
            <div class="stub-header">
              <img src="/usput-logo.png" alt="" class="stub-logo" onerror="this.style.display='none'" />
              <div class="stub-airline">Usput.ba</div>
              <div class="stub-tagline">Explore BiH</div>
            </div>

            <div class="stub-route">
              <div class="stub-codes">
                DOM <span class="stub-arrow">→</span> ${topCity.substring(0, 3).toUpperCase()}
              </div>
            </div>

            <div class="stub-details">
              <div class="stub-detail">
                <div class="stub-label">Let</div>
                <div class="stub-value">${flightNumber}</div>
              </div>
              <div class="stub-detail">
                <div class="stub-label">Sjedište</div>
                <div class="stub-value">${seatNumber}</div>
              </div>
              <div class="stub-detail">
                <div class="stub-label">Klasa</div>
                <div class="stub-value">${this.profile.badges.length >= 5 ? "GOLD" : this.profile.badges.length >= 2 ? "SILVER" : "EXPLORER"}</div>
              </div>
            </div>

            <div class="stub-barcode">
              <div class="barcode-lines">
                ${Array(20).fill(0).map(() => '<div class="barcode-line"></div>').join("")}
              </div>
              <div class="barcode-text">USPUT${Math.random().toString(36).substring(2, 10).toUpperCase()}</div>
            </div>
          </div>
        </div>
      </body>
      </html>
    `)
    printWindow.document.close()
    printWindow.print()
  }

  // Import profile from JSON file
  importProfile(event) {
    const file = event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const imported = JSON.parse(e.target.result)

        // Validate structure
        if (!imported.visited || !imported.favorites || !imported.badges) {
          throw new Error("Invalid profile format")
        }

        // Merge or replace
        if (confirm(this.t('confirm_replace_or_merge'))) {
          // Replace
          this.profile = { ...this.defaultProfile(), ...imported }
        } else {
          // Merge
          this.profile.visited = [...this.profile.visited, ...imported.visited]
            .filter((v, i, arr) => arr.findIndex(x => x.id === v.id && x.type === v.type) === i)
          this.profile.favorites = [...this.profile.favorites, ...imported.favorites]
            .filter((f, i, arr) => arr.findIndex(x => x.id === f.id && x.type === f.type) === i)
          this.profile.badges = [...this.profile.badges, ...imported.badges]
            .filter((b, i, arr) => arr.findIndex(x => x.id === b.id) === i)
        }

        this.profile.updatedAt = new Date().toISOString()
        this.saveProfile()
        this.showToast(this.t('profile_imported'), "success")
      } catch (err) {
        this.showToast(this.t('profile_import_error'), "error")
        console.error("Import error:", err)
      }
    }
    reader.readAsText(file)
  }

  // Clear all profile data
  clearProfile(event) {
    event.preventDefault()

    if (confirm(this.t('confirm_clear'))) {
      this.profile = this.defaultProfile()
      this.saveProfile()
      this.showToast(this.t('profile_cleared'), "info")
    }
  }

  // Show inline feedback message (preferred for action buttons)
  showFeedback(message, type = "info") {
    if (!this.hasFeedbackMessageTarget) {
      // Fallback to toast if no feedback target
      this.showToast(message, type)
      return
    }

    const feedback = this.feedbackMessageTarget

    // Set colors based on type
    feedback.classList.remove(
      "hidden",
      "bg-emerald-100", "dark:bg-emerald-900/30", "text-emerald-700", "dark:text-emerald-300",
      "bg-red-100", "dark:bg-red-900/30", "text-red-700", "dark:text-red-300",
      "bg-blue-100", "dark:bg-blue-900/30", "text-blue-700", "dark:text-blue-300",
      "bg-gray-100", "dark:bg-gray-800", "text-gray-700", "dark:text-gray-300"
    )

    if (type === "success") {
      feedback.classList.add("bg-emerald-100", "dark:bg-emerald-900/30", "text-emerald-700", "dark:text-emerald-300")
    } else if (type === "error") {
      feedback.classList.add("bg-red-100", "dark:bg-red-900/30", "text-red-700", "dark:text-red-300")
    } else if (type === "info") {
      feedback.classList.add("bg-blue-100", "dark:bg-blue-900/30", "text-blue-700", "dark:text-blue-300")
    } else {
      feedback.classList.add("bg-gray-100", "dark:bg-gray-800", "text-gray-700", "dark:text-gray-300")
    }

    // Set icon based on type
    let icon = ""
    if (type === "success") {
      icon = '<svg class="w-5 h-5 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>'
    } else if (type === "error") {
      icon = '<svg class="w-5 h-5 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>'
    } else if (type === "info") {
      icon = '<svg class="w-5 h-5 mr-2 flex-shrink-0 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg>'
    }

    feedback.innerHTML = `<div class="flex items-center">${icon}<span>${message}</span></div>`

    // Auto-hide after delay (except for loading/info messages)
    if (type !== "info") {
      setTimeout(() => {
        feedback.classList.add("hidden")
      }, 4000)
    }
  }

  // Hide feedback message
  hideFeedback() {
    if (this.hasFeedbackMessageTarget) {
      this.feedbackMessageTarget.classList.add("hidden")
    }
  }

  // Show toast notification (fallback for pages without inline feedback)
  showToast(message, type = "info") {
    const toast = document.createElement("div")
    const bgColor = type === "success" ? "bg-emerald-500" : type === "error" ? "bg-red-500" : "bg-gray-700"

    toast.className = `fixed bottom-4 right-4 ${bgColor} text-white px-6 py-3 rounded-lg shadow-lg z-50 transition-all transform translate-y-0 opacity-100`
    toast.textContent = message

    document.body.appendChild(toast)

    setTimeout(() => {
      toast.classList.add("translate-y-2", "opacity-0")
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  // Update show more button visibility and text
  updateShowMoreButton(targetName, shown, total) {
    const target = this[`has${targetName.charAt(0).toUpperCase() + targetName.slice(1)}Target`]
      ? this[`${targetName}Target`]
      : null

    if (!target) return

    const remaining = total - shown
    if (remaining > 0) {
      target.classList.remove("hidden")
      target.querySelector("span").textContent = this.t('show_more', { count: remaining })
    } else {
      target.classList.add("hidden")
    }
  }

  // Show more actions
  showMoreVisited(event) {
    event.preventDefault()
    this.visitedShown += this.constructor.ITEMS_PER_PAGE
    this.renderVisitedList()
  }

  showMoreFavorites(event) {
    event.preventDefault()
    this.favoritesShown += this.constructor.ITEMS_PER_PAGE
    this.renderFavoritesList()
  }

  showMoreBadges(event) {
    event.preventDefault()
    this.badgesShown += this.constructor.ITEMS_PER_PAGE
    this.renderBadges()
  }

  showMoreRecent(event) {
    event.preventDefault()
    this.recentShown += this.constructor.ITEMS_PER_PAGE
    this.renderRecentlyViewed()
  }

  // Show badge earned celebration
  showBadgeEarned(badge) {
    const badgeName = this.getBadgeTranslation(badge.id, 'name') || badge.name
    const badgeDescription = this.getBadgeTranslation(badge.id, 'description') || badge.description

    const modal = document.createElement("div")
    modal.className = "fixed inset-0 bg-black/50 flex items-center justify-center z-50"
    modal.innerHTML = `
      <div class="bg-white dark:bg-gray-800 rounded-2xl p-8 text-center max-w-sm mx-4 transform animate-bounce-in">
        <div class="text-6xl mb-4">${badge.icon}</div>
        <h3 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">${this.t('new_badge')}</h3>
        <p class="text-xl font-semibold text-emerald-600 dark:text-emerald-400 mb-2">${badgeName}</p>
        <p class="text-gray-600 dark:text-gray-400 mb-6">${badgeDescription}</p>
        <button class="bg-emerald-500 hover:bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium transition-colors">
          ${this.t('badge_awesome')}
        </button>
      </div>
    `

    modal.querySelector("button").addEventListener("click", () => modal.remove())
    modal.addEventListener("click", (e) => {
      if (e.target === modal) modal.remove()
    })

    document.body.appendChild(modal)
  }
}
