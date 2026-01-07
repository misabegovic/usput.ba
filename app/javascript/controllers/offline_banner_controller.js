import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="offline-banner"
// Shows a banner when the user goes offline with a link to their travel profile
export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this.updateOnlineStatus()

    // Store bound function references for proper cleanup
    this.boundHandleOnline = this.handleOnline.bind(this)
    this.boundHandleOffline = this.handleOffline.bind(this)

    // Listen for online/offline events
    window.addEventListener("online", this.boundHandleOnline)
    window.addEventListener("offline", this.boundHandleOffline)
  }

  disconnect() {
    window.removeEventListener("online", this.boundHandleOnline)
    window.removeEventListener("offline", this.boundHandleOffline)
  }

  updateOnlineStatus() {
    if (navigator.onLine) {
      this.hideBanner()
    } else {
      this.showBanner()
    }
  }

  handleOnline() {
    this.hideBanner()
  }

  handleOffline() {
    this.showBanner()
  }

  showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("hidden")
      this.bannerTarget.classList.add("animate-slide-in")
    }
  }

  hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add("hidden")
      this.bannerTarget.classList.remove("animate-slide-in")
    }
  }

  dismiss() {
    this.hideBanner()
  }
}
