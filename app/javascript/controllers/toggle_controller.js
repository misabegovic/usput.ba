import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    this.panelTargets.forEach((panel) => panel.classList.toggle("hidden"))
    // Let any map that just became visible re-measure itself.
    requestAnimationFrame(() => window.dispatchEvent(new Event("resize")))
  }

  close() {
    this.panelTargets.forEach((panel) => panel.classList.add("hidden"))
  }

  closeOnBackground(event) {
    if (event.target === event.currentTarget) this.close()
  }
}
