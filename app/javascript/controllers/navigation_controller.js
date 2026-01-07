import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="navigation"
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
      this.menuTarget.classList.add("animate-fade-in")
    }
    if (this.hasOpenIconTarget) {
      this.openIconTarget.classList.add("hidden")
    }
    if (this.hasCloseIconTarget) {
      this.closeIconTarget.classList.remove("hidden")
    }
    // Prevent body scroll when menu is open
    document.body.classList.add("overflow-hidden", "md:overflow-auto")
  }

  hideMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add("hidden")
      this.menuTarget.classList.remove("animate-fade-in")
    }
    if (this.hasOpenIconTarget) {
      this.openIconTarget.classList.remove("hidden")
    }
    if (this.hasCloseIconTarget) {
      this.closeIconTarget.classList.add("hidden")
    }
    // Restore body scroll
    document.body.classList.remove("overflow-hidden", "md:overflow-auto")
  }

  // Close menu when clicking outside
  clickOutside(event) {
    if (this.openValue && !this.element.contains(event.target)) {
      this.close()
    }
  }

  // Close menu on escape key
  closeOnEscape(event) {
    if (event.key === "Escape" && this.openValue) {
      this.close()
    }
  }
}
