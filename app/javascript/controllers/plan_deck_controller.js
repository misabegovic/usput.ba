import { Controller } from "@hotwired/stimulus"
import { positionService } from "services/position_service"
import { distanceKm } from "services/route_service"

// How many slots behind the traveller survive. Generous: scrolling back a few
// cards is ordinary, and refetching what was just released is the worse cost.
const KEEP_BEHIND = 15
// Below this, re-dealing is churn rather than a better deck.
const MIN_REDEAL_KM = 0.2

// How often the deck quietly checks whether the traveller has moved away from
// the origin it was dealt from. Cheap — a cached low-accuracy reading, no
// routing request — and it never re-deals on its own.
const DRIFT_CHECK_MS = 120000

export default class extends Controller {
  static targets = ["card", "done", "distanceLabel", "movedPrompt"]
  static values = { browse: Boolean }

  connect() {
    this.index = 0
    // Browse mode (explore) keeps every card in the scroll; the walk deals one
    // at a time, opening on whichever is closest right now.
    if (!this.browseValue) {
      this.render()
      this.dealNearest(false)
    }
    // The server ordered the deck from where the traveller stood at page load.
    // From here the live position owns both the labels and the order.
    this.unsubscribe = positionService.subscribe(({ latitude, longitude }) => {
      this.refreshDistances(latitude, longitude)
      if (this.browseValue) this.resortAhead(latitude, longitude)
      if (this.browseValue) this.dealFromIfMoved(latitude, longitude)
    })
    if (this.browseValue) this.element.addEventListener("scroll", this.onScroll, { passive: true })
    if (this.browseValue) this.driftTimer = setInterval(() => this.checkDrift(), DRIFT_CHECK_MS)
  }

  disconnect() {
    clearInterval(this.driftTimer)
    this.unsubscribe?.()
    this.element.removeEventListener("scroll", this.onScroll)
    cancelAnimationFrame(this.scrollFrame)
  }

  // Says why the traveller would press, which is the part the control itself
  // cannot say. Shown only once the deck is provably out of date — a prompt
  // that fires while someone is standing still teaches them to ignore it.
  async checkDrift() {
    if (!this.hasMovedPromptTarget || document.hidden) return

    const here = await positionService.peek()
    if (!here) return

    const url = new URL(window.location.href)
    const fromLat = parseFloat(url.searchParams.get("lat"))
    const fromLng = parseFloat(url.searchParams.get("lng"))
    if (!isFinite(fromLat) || !isFinite(fromLng)) return

    const moved = distanceKm(here.latitude, here.longitude, fromLat, fromLng)
    this.movedPromptTarget.classList.toggle("hidden", moved < this.redealThreshold(here.latitude, here.longitude))
  }

  onScroll = () => {
    cancelAnimationFrame(this.scrollFrame)
    this.scrollFrame = requestAnimationFrame(() => this.releaseBehind())
  }

  // Every card dealt used to stay in the page for the whole session, so a long
  // scroll cost more the longer it ran. Slots well behind the traveller are
  // released and the scroll is pulled up by exactly the height they occupied,
  // so the card under the thumb does not move.
  releaseBehind() {
    const slots = this.slots()
    const surplus = this.currentSlot(slots) - KEEP_BEHIND
    if (surplus <= 0) return

    const dropped = slots.slice(0, surplus)
    const height = dropped.reduce((total, slot) => total + slot.offsetHeight, 0)
    dropped.forEach((slot) => slot.remove())
    this.element.scrollTop -= height
  }

  // The traveller asked for a new position: acquire it, relabel every card from
  // it, and re-deal the places still to come from where they now stand.
  async updateLocation(event) {
    const button = event?.currentTarget
    button?.setAttribute("disabled", "disabled")
    const here = await positionService.refresh()
    button?.removeAttribute("disabled")
    if (!here) return

    if (this.hasMovedPromptTarget) this.movedPromptTarget.classList.add("hidden")

    this.dealFrom(here.latitude, here.longitude)
  }

  // Re-sorting the cards on the page cannot answer this. The set itself was
  // chosen by the server from the old origin, so the place nearest to where the
  // traveller now stands may not be among them at all — the deck has to be
  // dealt again. A page reload does not do it either: the coordinates live in
  // the URL, so a refresh re-deals from wherever the last ask happened to be.
  dealFrom(lat, lng) {
    const url = new URL(window.location.href)
    url.searchParams.set("lat", lat)
    url.searchParams.set("lng", lng)
    url.searchParams.delete("approx")

    const frame = document.getElementById("explore_deck")
    if (!frame) return window.location.replace(url.toString())

    window.history.replaceState({}, "", url.toString())
    frame.src = url.toString()
  }

  dealFromIfMoved(lat, lng) {
    const url = new URL(window.location.href)
    const fromLat = parseFloat(url.searchParams.get("lat"))
    const fromLng = parseFloat(url.searchParams.get("lng"))
    if (!isFinite(fromLat) || !isFinite(fromLng)) return
    if (distanceKm(lat, lng, fromLat, fromLng) < this.redealThreshold(lat, lng)) return

    this.dealFrom(lat, lng)
  }

  // Not a fixed distance: two kilometres is noise when the nearest place is
  // fifty away, and far too coarse inside a city. A third of the way to the
  // nearest card the traveller has not reached is where the deal can change.
  redealThreshold(lat, lng) {
    const slots = this.slots()
    const ahead = slots.slice(this.currentSlot(slots) + 1)
    // A deck with nothing ahead is the case that most needs re-dealing, not the
    // one to refuse: it happens when the traveller has scrolled to the end, and
    // when they come back to an exhausted deck somewhere else entirely.
    if (!ahead.length) return MIN_REDEAL_KM

    const nearest = Math.min(...ahead.map((slot) => this.slotDistance(slot, lat, lng)))
    return isFinite(nearest) ? Math.max(nearest / 3, MIN_REDEAL_KM) : MIN_REDEAL_KM
  }

  // Nearest-first, but only over the cards the traveller has not reached yet:
  // reordering what is on screen would move a card out from under their thumb.
  resortAhead(lat, lng) {
    const slots = this.slots()
    const current = this.currentSlot(slots)
    const ahead = slots.slice(current + 1)
    if (ahead.length < 2) return

    const sorted = [ ...ahead ].sort((a, b) => this.slotDistance(a, lat, lng) - this.slotDistance(b, lat, lng))
    if (sorted.every((slot, i) => slot === ahead[i])) return

    const anchor = ahead[ahead.length - 1].nextSibling
    sorted.forEach((slot) => slot.parentNode.insertBefore(slot, anchor))
  }

  slots() {
    return this.cardTargets
      .map((card) => card.closest(".snap-start"))
      .filter((slot, i, all) => slot && all.indexOf(slot) === i)
  }

  // The slot whose top is nearest the scroller's top is the one in view.
  currentSlot(slots) {
    const top = this.element.scrollTop
    let index = 0
    slots.forEach((slot, i) => {
      if (slot.offsetTop <= top + 1) index = i
    })
    return index
  }

  slotDistance(slot, lat, lng) {
    const card = slot.querySelector("[data-plan-deck-target='card']")
    return distanceKm(lat, lng, parseFloat(card?.dataset.planDeckLat), parseFloat(card?.dataset.planDeckLng))
  }


  advance() {
    const current = this.cardTargets[this.index]
    if (current && !this.isVisited(current)) return // can't skip an un-visited stop
    this.dealNearest(true)
  }

  // Nearest un-visited to the current position; re-run on open and each advance.
  dealNearest(advancing) {
    const remaining = this.cardTargets
      .map((card, i) => ({ card, i }))
      .filter(({ card }) => !this.isVisited(card))

    if (remaining.length === 0) {
      if (advancing) { this.index = this.cardTargets.length; this.render() }
      return
    }
    const here = positionService.current()
    if (!here) return this.show(remaining[0].i)

    const nearest = remaining
      .map((entry) => ({ ...entry, distance: distanceKm(here.latitude, here.longitude, parseFloat(entry.card.dataset.planDeckLat), parseFloat(entry.card.dataset.planDeckLng)) }))
      .sort((a, b) => a.distance - b.distance)[0]
    this.show(nearest.i)
  }

  show(i) {
    this.index = i
    this.render()
    const here = positionService.current()
  }

  render() {
    const done = this.index >= this.cardTargets.length
    this.cardTargets.forEach((card, i) => card.classList.toggle("hidden", done || i !== this.index))
    if (this.hasDoneTarget) this.doneTarget.classList.toggle("hidden", !done)
  }

  isVisited(card) {
    return card.dataset.planDeckVisited === "true" || card.querySelector("[data-walk-visited='true']") !== null
  }


  // The straight line is what a card can afford to show for every place at once.
  // The real road distance costs an upstream routing call, so only the card the
  // traveller is actually looking at gets one, and only once.

  cardInView() {
    if (!this.browseValue) return this.cardTargets[this.index]
    const slots = this.slots()
    return slots[this.currentSlot(slots)]?.querySelector("[data-plan-deck-target='card']")
  }

  refreshDistances(lat, lng) {
    this.distanceLabelTargets.forEach((label) => {
      const card = label.closest("[data-plan-deck-target='card']")
      const template = label.dataset.kmTemplate
      if (!card || !template) return
      // One measure on every card, and the label says which one it is. Naming a
      // travel mode beside it was the worse bug: it read as a road distance, and
      // a road distance to Štrbački buk is a third longer than the line to it.
      // The real routed figure belongs to the map, which draws the route it
      // describes and is the only thing that asks the upstream for one.
      const km = distanceKm(lat, lng, parseFloat(card.dataset.planDeckLat), parseFloat(card.dataset.planDeckLng))
      label.textContent = template.replace("{km}", km.toFixed(1))
    })
  }
}
