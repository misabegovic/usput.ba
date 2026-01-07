import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pwa-install"
// Shows an install prompt banner for mobile users who are not using the PWA
// Also shows a desktop banner informing users that the app is available on mobile
export default class extends Controller {
  static targets = ["banner", "desktopBanner"]
  static values = {
    dismissed: { type: Boolean, default: false }
  }

  connect() {
    // Check if we should show the banner
    this.deferredPrompt = null
    this.checkAndShowBanner()

    // Store bound function reference for proper cleanup
    this.boundHandleBeforeInstallPrompt = this.handleBeforeInstallPrompt.bind(this)

    // Listen for the beforeinstallprompt event
    window.addEventListener("beforeinstallprompt", this.boundHandleBeforeInstallPrompt)
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.boundHandleBeforeInstallPrompt)
  }

  handleBeforeInstallPrompt(event) {
    // Prevent the default browser prompt
    event.preventDefault()
    // Store the event for later use
    this.deferredPrompt = event
    // Show our custom banner (only on mobile)
    if (this.isMobile()) {
      this.showBanner()
    }
  }

  checkAndShowBanner() {
    // Don't show if already dismissed in this session
    if (this.isDismissed()) {
      return
    }

    // Don't show if already installed as PWA (standalone mode)
    if (this.isStandalone()) {
      return
    }

    // Show different banners based on device type
    if (this.isMobile()) {
      // Show mobile install banner for iOS (which doesn't support beforeinstallprompt)
      if (this.isIOS()) {
        this.showBanner()
      }
      // For Android/Chrome, we wait for beforeinstallprompt event
    } else {
      // Show desktop banner informing about mobile app availability
      this.showDesktopBanner()
    }
  }

  isStandalone() {
    // Check if running as installed PWA
    return window.matchMedia("(display-mode: standalone)").matches ||
           window.navigator.standalone === true ||
           document.referrer.includes("android-app://")
  }

  isMobile() {
    // Check if mobile device using user agent and screen width
    const userAgent = navigator.userAgent || navigator.vendor || window.opera
    const isMobileUA = /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent.toLowerCase())
    const isSmallScreen = window.innerWidth <= 768
    return isMobileUA || isSmallScreen
  }

  isIOS() {
    const userAgent = navigator.userAgent || navigator.vendor || window.opera
    return /iphone|ipad|ipod/i.test(userAgent.toLowerCase()) && !window.MSStream
  }

  isDismissed() {
    try {
      const dismissedUntil = localStorage.getItem("pwa_install_dismissed_until")
      if (dismissedUntil) {
        return new Date().getTime() < parseInt(dismissedUntil, 10)
      }
      return false
    } catch (e) {
      return false
    }
  }

  setDismissed() {
    try {
      // Dismiss for 7 days
      const dismissUntil = new Date().getTime() + (7 * 24 * 60 * 60 * 1000)
      localStorage.setItem("pwa_install_dismissed_until", dismissUntil.toString())
    } catch (e) {
      // localStorage might not be available
    }
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

  showDesktopBanner() {
    if (this.hasDesktopBannerTarget) {
      this.desktopBannerTarget.classList.remove("hidden")
      this.desktopBannerTarget.classList.add("animate-fade-in")
    }
  }

  hideDesktopBanner() {
    if (this.hasDesktopBannerTarget) {
      this.desktopBannerTarget.classList.add("hidden")
      this.desktopBannerTarget.classList.remove("animate-fade-in")
    }
  }

  dismiss() {
    this.setDismissed()
    this.hideBanner()
    this.hideDesktopBanner()
  }

  async install() {
    if (this.isIOS()) {
      // For iOS, show instructions since we can't trigger install programmatically
      this.showIOSInstructions()
      return
    }

    if (!this.deferredPrompt) {
      // No deferred prompt available, fallback to instructions
      this.showIOSInstructions()
      return
    }

    try {
      // Show the browser's install prompt
      this.deferredPrompt.prompt()

      // Wait for user response
      const { outcome } = await this.deferredPrompt.userChoice

      if (outcome === "accepted") {
        console.log("[Usput] PWA installed successfully")
      } else {
        console.log("[Usput] PWA installation dismissed")
      }

      // Clear the deferred prompt
      this.deferredPrompt = null
      this.hideBanner()
    } catch (error) {
      console.error("[Usput] PWA installation error:", error)
    }
  }

  showIOSInstructions() {
    // Show a modal or alert with iOS-specific instructions
    const iosInstructions = this.element.querySelector("[data-pwa-install-target='iosModal']")
    if (iosInstructions) {
      iosInstructions.classList.remove("hidden")
    }
  }

  hideIOSInstructions() {
    const iosInstructions = this.element.querySelector("[data-pwa-install-target='iosModal']")
    if (iosInstructions) {
      iosInstructions.classList.add("hidden")
    }
  }
}
