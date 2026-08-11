import { Controller } from "@hotwired/stimulus"
import { positionService } from "services/position_service"

// The deck cannot deal without a position, so this reloads it with the first fix
// the shared watcher produces. Mounted only while the coordinates are missing.
// However long the browser is given, it has to end somewhere. A device with no
// location provider answers neither callback, and a deck that waits on it shows
// a card asking for something that is never coming.
const DEADLINE_MS = 12000

export default class extends Controller {
  static values = { failedBody: String, retryLabel: String, fallbackLat: Number, fallbackLng: Number }

  connect() {
    // Only a measured fix deals a deck. Handing off a remembered one had the
    // server order every card from wherever the device was last.
    const held = positionService.measured()
    if (held) return this.handOff(held)

    this.deadline = setTimeout(() => this.giveUp(), DEADLINE_MS)
    this.unsubscribe = positionService.subscribe(
      (coords) => {
        this.stopListening()
        this.handOff(coords)
      },
      () => this.giveUp()
    )
  }

  disconnect() {
    this.stopListening()
  }

  // The deck deals from the country's default rather than stopping, which is
  // what this controller already did for an admin reviewing the walk — the
  // traveller was the one left with a dead end. The cards are no longer ordered
  // from where they stand and the deck says so, which is a worse deck and a far
  // better outcome than none.
  giveUp() {
    this.stopListening()
    if (!this.hasFallbackLatValue || !this.hasFallbackLngValue) return this.showFailed()

    this.handOff({ latitude: this.fallbackLatValue, longitude: this.fallbackLngValue }, { approximate: true })
  }

  stopListening() {
    clearTimeout(this.deadline)
    this.unsubscribe?.()
    this.unsubscribe = undefined
  }

  showFailed() {
    const card = this.element.querySelector("[data-plan-deck-target='card']")
    if (!card || card.dataset.geoFailed) return
    card.dataset.geoFailed = "true"

    const message = card.querySelector("p")
    if (message) message.textContent = this.failedBodyValue

    const retry = document.createElement("button")
    retry.type = "button"
    retry.textContent = this.retryLabelValue
    retry.className = "mt-4 rounded-full bg-gray-900 px-5 py-2 text-sm font-semibold text-white dark:bg-white dark:text-gray-900"
    retry.addEventListener("click", () => window.location.reload())
    message?.after(retry)
  }

  // The deck lives in a Turbo frame, so the fix can be handed over by asking
  // that frame to re-render rather than by replacing the document.
  handOff({ latitude, longitude }, { approximate = false } = {}) {
    const url = new URL(window.location.href)
    if (url.searchParams.has("lat")) return

    url.searchParams.set("lat", latitude)
    url.searchParams.set("lng", longitude)
    // The deck needs to know the origin is not the traveller's, so it can say so
    // rather than quoting distances from a city they may not be in.
    if (approximate) url.searchParams.set("approx", "1")

    const frame = document.getElementById("explore_deck")
    if (!frame) return window.location.replace(url.toString())

    window.history.replaceState({}, "", url.toString())
    frame.src = url.toString()
  }
}
