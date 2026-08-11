import { Controller } from "@hotwired/stimulus"
import { travelProfileService } from "services/travel_profile_service"
import { positionService } from "services/position_service"
import { distanceKm } from "services/route_service"

// One number for both sides of the press: how old a fix may be to be asked for,
// and to be accepted. Asking for a fix this old and then refusing it for being
// that old is what left the button doing nothing. A cold acquisition on every
// press is what made the first check-in take ten seconds to fail.
const REUSE_MS = 30000

export default class extends Controller {
  static targets = ["hint", "control"]
  // The geofence comes from the server — RecordsVisits owns it, so the browser
  // and the server cannot reach opposite verdicts on one press.
  static values = {
    lat: Number, lng: Number, guest: Boolean, geofenceM: Number,
    locationId: String, locationName: String, locationCity: String, locationTags: Array
  }

  connect() {
    this.sending = false
    // A guest has no form to submit, so the button reports its own press.
    this.event = this.guestValue ? "click" : "submit"
    this.element.addEventListener(this.event, this.capture)
    this.element.addEventListener("turbo:submit-end", this.released)
    this.unsubscribe = positionService.subscribe(() => {})
    if (this.guestValue && travelProfileService.isVisited(this.locationIdValue)) this.restoreVisited()
  }

  // Explore deals unvisited places only, so a visited one is dropped on a fresh
  // deal exactly as the server drops it for a signed-in traveller. The walk keeps
  // its visited steps, and so does a location page.
  restoreVisited() {
    const card = this.element.closest("[data-plan-deck-target='card']")
    const browsing = card?.closest("[data-plan-deck-browse-value='true']")
    if (!browsing) return this.markVisited()

    ;(card.closest(".snap-start") || card).remove()
  }

  disconnect() {
    this.element.removeEventListener(this.event, this.capture)
    this.element.removeEventListener("turbo:submit-end", this.released)
    this.unsubscribe?.()
  }

  // A success replaces this control, so only a failed submit gets here — and
  // without the release every later press was a silent no-op until a reload.
  released = (event) => {
    this.sending = false
    if (event.detail?.success === false) this.showMessage("failed")
  }

  capture = (event) => {
    if (this.sending) return
    event.preventDefault()

    // Out of this event first: requestSubmit() is ignored while the submit it
    // would re-trigger is still being dispatched.
    const here = positionService.recent(REUSE_MS)
    if (here) return setTimeout(() => this.evaluate(here.latitude, here.longitude), 0)
    if (!navigator.geolocation) return this.showEnableLocation()

    // Nothing fresh enough held. A traveller standing still is the case that
    // gets here: the watcher reports on movement, so the fix it gave on arrival
    // only ages, and refusing it leaves nothing to press. The service acquires
    // rather than reusing, and a press that shows nothing meanwhile reads as a
    // dead button.
    this.showMessage("locating")
    positionService.acquire(REUSE_MS).then((measured) => {
      // Anything at all is enough to answer with: the gate widens by the
      // reading's own error, so a coarse fix produces an honest distance rather
      // than a refusal. Only a total absence of position has nothing to say.
      const here = measured || positionService.current()
      if (here) return this.evaluate(here.latitude, here.longitude)

      this.showEnableLocation()
    })
  }

  evaluate(lat, lng) {
    const km = distanceKm(lat, lng, this.latValue, this.lngValue)
    if (km * 1000 <= this.geofenceMValue) {
      return this.guestValue ? this.recordGuestVisit() : this.submitWith(lat, lng)
    }
    this.showHint(km, this.bearing(lat, lng, this.latValue, this.lngValue))
  }

  submitWith(lat, lng) {
    const form = this.element.querySelector("form")
    form.querySelector('input[name="user_lat"]').value = lat
    form.querySelector('input[name="user_lng"]').value = lng
    this.sending = true
    form.requestSubmit()
  }

  // The place is remembered, never where the traveller stood.
  recordGuestVisit() {
    this.sending = true
    travelProfileService.markVisited({
      id: this.locationIdValue,
      name: this.locationNameValue,
      city: this.locationCityValue,
      tags: this.locationTagsValue
    })
    this.markVisited()
  }

  markVisited() {
    if (this.hasControlTarget) this.controlTarget.classList.add("hidden")
    if (this.hasHintTarget) this.hintTarget.classList.add("hidden")
    const card = this.element.closest("[data-plan-deck-target='card']")
    card?.setAttribute("data-plan-deck-visited", "true")
    const scope = this.element.closest("[data-walk-visited]") || card || this.element.parentElement
    scope?.querySelectorAll("[data-visited-badge]").forEach(el => el.classList.remove("hidden"))
    scope?.querySelectorAll("[data-visited-hide]").forEach(el => el.classList.add("hidden"))
  }

  showHint(km, direction) {
    if (!this.hasHintTarget) return
    // The same straight line the cards quote, so the press and the card above it
    // can never disagree. The gate is the same measure too: a geofence is a
    // radius, not a route.
    const band = this.warmthBand(km)
    const distance = km >= 1 ? `${km.toFixed(1)} km` : `${Math.round(km * 1000)} m`
    this.hintTarget.textContent = `${band.emoji} ${band.label} · ${distance} · ${direction}`
    this.hintTarget.style.backgroundColor = band.tint
    this.hintTarget.classList.remove("hidden")
  }

  warmthBand(km) {
    // Cold → warm as the metres fall. HOT (<100 m) never reaches here —
    // evaluate() checks in at that range. Labels are localized via data-warmth;
    // tints are inline so Tailwind's purge can't drop dynamic colour classes.
    const labels = this.hintTarget.dataset.warmth
      ? this.hintTarget.dataset.warmth.split(",")
      : ["Freezing", "Cold", "Cool", "Warm"]
    const index = km > 5 ? 0 : km > 1 ? 1 : km > 0.5 ? 2 : 3
    const emoji = ["❄️", "🧊", "🌤️", "🔥"][index]
    const tint = ["rgba(37,99,235,.75)", "rgba(14,165,233,.75)", "rgba(234,179,8,.8)", "rgba(220,38,38,.85)"][index]
    return { label: labels[index], emoji, tint }
  }

  showEnableLocation() {
    this.showMessage("enableLocation")
  }

  showMessage(key) {
    if (!this.hasHintTarget) return
    this.hintTarget.textContent = this.hintTarget.dataset[key] || ""
    this.hintTarget.style.backgroundColor = ""
    this.hintTarget.classList.remove("hidden")
  }

  bearing(lat1, lng1, lat2, lng2) {
    const toRad = (deg) => (deg * Math.PI) / 180
    const y = Math.sin(toRad(lng2 - lng1)) * Math.cos(toRad(lat2))
    const x = Math.cos(toRad(lat1)) * Math.sin(toRad(lat2)) - Math.sin(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.cos(toRad(lng2 - lng1))
    const degrees = (Math.atan2(y, x) * 180 / Math.PI + 360) % 360
    const compass = (this.hasHintTarget && this.hintTarget.dataset.directions
      ? this.hintTarget.dataset.directions.split(",")
      : ["N", "NE", "E", "SE", "S", "SW", "W", "NW"])
    return compass[Math.round(degrees / 45) % 8]
  }
}
