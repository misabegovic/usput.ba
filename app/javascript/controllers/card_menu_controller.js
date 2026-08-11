import { Controller } from "@hotwired/stimulus"

// Tap the card photo to open its actions menu; each action shows one
// in-card panel (info / map / reviews / moments).
export default class extends Controller {
  static targets = ["menu", "panel"]

  open(event) {
    if (event.target.closest("button, a, form, input, textarea, label")) return
    this.reveal()
  }

  openFromHandle(event) {
    event.stopPropagation()
    this.reveal()
  }

  close(event) {
    event?.stopPropagation()
    this.menuTarget.classList.replace("flex", "hidden")
  }

  show(event) {
    event.stopPropagation()
    const name = event.currentTarget.dataset.panel
    this.menuTarget.classList.replace("flex", "hidden")
    this.panelTargets.forEach((panel) => panel.classList.toggle("hidden", panel.dataset.panel !== name))
    // Hidden-panel maps lay out at zero size; the map re-measures on resize.
    window.dispatchEvent(new Event("resize"))
  }

  // Anyone may look at a place's moments; only capturing one is earned by
  // being there, and that is enforced server-side.
  moments(event) {
    event.stopPropagation()
    this.close()
    this.element.querySelector("[data-story-open]")?.click()
  }

  // Panel ✕ goes back to the menu, not straight out.
  back(event) {
    event?.stopPropagation()
    this.panelTargets.forEach((panel) => panel.classList.add("hidden"))
    this.menuTarget.classList.replace("hidden", "flex")
  }

  reveal() {
    this.menuTarget.classList.replace("hidden", "flex")
  }
}
