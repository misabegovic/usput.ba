// The one owner of `usput_travel_profile`. The deck, the check-in and the
// profile all read and write it here, so no two stores can disagree — and it is
// the only file that knows the key carries the traveller.

const STORAGE_KEY = "usput_travel_profile"

export class TravelProfileService {
  isLoggedIn() {
    return document.querySelector('meta[name="user-logged-in"]')?.content === "true"
  }

  // The server hands down a digest of the account rather than the account, so
  // two travellers on one browser address two stores and neither leaves an
  // identifier behind. A guest has no owner to key by, and keeps the bare name.
  storageKey() {
    const scope = document.querySelector('meta[name="travel-store-scope"]')?.content
    return scope ? `${STORAGE_KEY}_${scope}` : STORAGE_KEY
  }

  read() {
    try {
      const key = this.storageKey()
      const stored = localStorage.getItem(key) ?? this.adoptUnscopedStore(key)
      const profile = stored ? JSON.parse(stored) : null
      return profile && typeof profile === "object" ? this.withDefaults(profile) : this.defaultProfile()
    } catch {
      return this.defaultProfile()
    }
  }

  // Covers both stores that can sit under the bare name once someone is signed
  // in: one written before the key carried the traveller, and the guest buffer
  // the door has already turned into rows. Either belongs to whoever is signed
  // in now, and leaving it would hand it to the next account on the device.
  // Finding nothing is ordinary — an installed iOS app reads a different
  // container than the browser it was installed from.
  adoptUnscopedStore(key) {
    if (key === STORAGE_KEY) return null

    const unscoped = localStorage.getItem(STORAGE_KEY)
    if (unscoped === null) return null

    localStorage.setItem(key, unscoped)
    localStorage.removeItem(STORAGE_KEY)
    return unscoped
  }

  // Adopting on read only reaches the pages that read — and a traveller signing
  // in lands on the home page, where the profile never mounts. Every page claims
  // once the traveller is known, so nothing is left under the bare name for the
  // next account on the device. The door has already turned the walk into rows;
  // this is about not stranding the copy.
  claimUnscopedStore() {
    return this.adoptUnscopedStore(this.storageKey()) !== null
  }

  // Theme, audio-tour locale, dismissals, consent and an unclaimed walk belong
  // to the device rather than to whoever just left, so only our own key goes.
  clearForCurrentTraveller() {
    const key = this.storageKey()
    if (key === STORAGE_KEY) return

    localStorage.removeItem(key)
  }

  write(profile) {
    try {
      profile.updatedAt = new Date().toISOString()
      localStorage.setItem(this.storageKey(), JSON.stringify(profile))
    } catch (error) {
      console.error("Failed to save travel profile:", error)
    }
    return profile
  }

  defaultProfile() {
    const now = new Date().toISOString()
    return {
      createdAt: now,
      updatedAt: now,
      visited: [],        // { id, type, name, visitedAt, city, tags }
      favorites: [],      // { id, type, name, addedAt }
      recentlyViewed: [], // { id, type, name, viewedAt } — last 20
      badges: [],         // { id, earnedAt }
      savedPlans: [],     // { id, name, savedAt, data }
      stats: { totalVisits: 0, citiesVisited: [], seasonsVisited: [] }
    }
  }

  // An older profile may lack a key the UI indexes into.
  withDefaults(profile) {
    return { ...this.defaultProfile(), ...profile, stats: { ...this.defaultProfile().stats, ...(profile.stats || {}) } }
  }

  visited() {
    return this.read().visited
  }

  isVisited(id, type = "location") {
    return this.visited().some(entry => String(entry.id) === String(id) && entry.type === type)
  }

  visitedIds(type = "location") {
    return new Set(this.visited().filter(entry => entry.type === type).map(entry => String(entry.id)))
  }

  // Add only. A visit cannot be undone — you either stood there or you did not.
  markVisited({ id, type = "location", name = null, city = null, tags = [] }) {
    if (!id) return this.read()

    const profile = this.read()
    if (this.isVisited(id, type)) return profile

    profile.visited.push({ id: String(id), type, name, city, tags, visitedAt: new Date().toISOString() })
    profile.stats.totalVisits = profile.visited.length

    if (city && !profile.stats.citiesVisited.includes(city)) profile.stats.citiesVisited.push(city)

    const season = this.currentSeason()
    if (!profile.stats.seasonsVisited.includes(season)) profile.stats.seasonsVisited.push(season)

    this.awardBadges(profile)
    return this.write(profile)
  }

  // Every badge but `collector` is a function of the walk, so they are decided
  // where the walk is written — the deck, the walk and the location page all
  // check in through here, and each earns the same badges. Mutates and reports
  // what was newly earned; the caller writes, and shows them if it can.
  awardBadges(profile) {
    const held = new Set(profile.badges.map(badge => badge.id))
    const earned = this.badgeRules(profile).filter(([id, met]) => met && !held.has(id)).map(([id]) => id)

    const earnedAt = new Date().toISOString()
    earned.forEach(id => profile.badges.push({ id, earnedAt }))
    return earned
  }

  badgeRules({ visited, favorites, stats }) {
    const tagged = (...tags) => visited.filter(entry => entry.tags?.some(tag => tags.includes(tag))).length

    return [
      [ "first_visit", visited.length >= 1 ],
      [ "explorer_5", visited.length >= 5 ],
      [ "explorer_10", visited.length >= 10 ],
      [ "explorer_25", visited.length >= 25 ],
      [ "culture_lover", tagged("culture", "history", "museum") >= 5 ],
      [ "foodie", visited.filter(entry => entry.type === "restaurant" || entry.tags?.includes("food")).length >= 5 ],
      [ "nature_lover", tagged("nature", "park", "mountain") >= 5 ],
      [ "city_hopper", stats.citiesVisited.length >= 3 ],
      [ "all_seasons", stats.seasonsVisited.length >= 4 ],
      [ "collector", favorites.length >= 10 ]
    ]
  }

  // Matches Location.current_season.
  currentSeason() {
    const month = new Date().getMonth() + 1
    if (month <= 2 || month === 12) return "winter"
    if (month <= 5) return "spring"
    if (month <= 8) return "summer"
    return "fall"
  }

  forSignIn() {
    return JSON.stringify(this.read())
  }
}

export const travelProfileService = new TravelProfileService()
