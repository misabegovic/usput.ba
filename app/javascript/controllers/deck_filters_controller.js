import { Controller } from "@hotwired/stimulus"

// Filters apply on selection, with no Apply button — and a second press on an
// active choice clears it, which a radio cannot do on its own.
export default class extends Controller {
  static targets = ["panel"]
  static OPEN_KEY = "usput-deck-filters-open"

  // Each pick swaps this panel out for a fresh one, so whether it was open has to
  // outlive the swap — otherwise every filter costs a re-open.
  connect() {
    if (this.hasPanelTarget && sessionStorage.getItem(this.constructor.OPEN_KEY) === "1") {
      this.panelTarget.classList.remove("hidden")
    }
  }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    sessionStorage.setItem(this.constructor.OPEN_KEY, this.panelTarget.classList.contains("hidden") ? "0" : "1")
  }

  // The input is sr-only, so the pointer lands on the styled span. Handling the
  // label's click is the only place that sees every press.
  choose(event) {
    const input = event.currentTarget.querySelector("input")
    if (!input) return

    event.preventDefault()
    input.checked = !input.checked
    this.submit()
  }

  // requestSubmit, not submit: Turbo only sees the former, and a native submit
  // reloads the page — which locks the pills until it lands.
  submit() {
    this.element.querySelector("form")?.requestSubmit()
  }
}
