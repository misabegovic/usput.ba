import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cookie-consent"
export default class extends Controller {
  static targets = ["banner"]
  static values = {
    storageKey: { type: String, default: "cookie_consent" }
  }

  connect() {
    // Check if user has already given consent
    if (!this.hasConsent) {
      this.showBanner()
    }
  }

  accept() {
    this.saveConsent("accepted")
    this.hideBanner()
  }

  decline() {
    this.saveConsent("declined")
    this.hideBanner()
  }

  showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("hidden")
      // Trigger animation
      requestAnimationFrame(() => {
        this.bannerTarget.classList.add("cookie-consent-visible")
      })
    }
  }

  hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("cookie-consent-visible")
      // Wait for animation to complete before hiding
      setTimeout(() => {
        this.bannerTarget.classList.add("hidden")
      }, 300)
    }
  }

  saveConsent(value) {
    try {
      localStorage.setItem(this.storageKeyValue, value)
      localStorage.setItem(`${this.storageKeyValue}_date`, new Date().toISOString())
    } catch (e) {
      // localStorage might be disabled
      console.warn("Could not save cookie consent preference:", e)
    }
  }

  get hasConsent() {
    try {
      const consent = localStorage.getItem(this.storageKeyValue)
      return consent === "accepted" || consent === "declined"
    } catch (e) {
      // localStorage might be disabled
      return false
    }
  }
}
