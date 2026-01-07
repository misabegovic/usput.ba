import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="curator-menu"
export default class extends Controller {
  static targets = ["menu", "openIcon", "closeIcon"]
  static values = {
    open: { type: Boolean, default: false }
  }

  toggle() {
    this.openValue = !this.openValue
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    if (this.openValue) {
      this.showMenu()
    } else {
      this.hideMenu()
    }
  }

  showMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove("hidden")
    }
    if (this.hasOpenIconTarget) {
      this.openIconTarget.classList.add("hidden")
      this.openIconTarget.classList.remove("block")
    }
    if (this.hasCloseIconTarget) {
      this.closeIconTarget.classList.remove("hidden")
      this.closeIconTarget.classList.add("block")
    }
  }

  hideMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add("hidden")
    }
    if (this.hasOpenIconTarget) {
      this.openIconTarget.classList.remove("hidden")
      this.openIconTarget.classList.add("block")
    }
    if (this.hasCloseIconTarget) {
      this.closeIconTarget.classList.add("hidden")
      this.closeIconTarget.classList.remove("block")
    }
  }
}
