import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="generation-status"
// Manual status checking - no automatic polling
export default class extends Controller {
  static targets = ["container", "button", "buttonText", "stopButton"]
  static values = {
    url: String,
    loading: { type: Boolean, default: false }
  }

  async checkStatus() {
    if (this.loadingValue) return

    this.loadingValue = true
    this.updateButtonState()

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.containerTarget.innerHTML = html
      }
    } catch (error) {
      console.error("Failed to fetch status:", error)
    } finally {
      this.loadingValue = false
      this.updateButtonState()
    }
  }

  updateButtonState() {
    if (!this.hasButtonTarget) return

    if (this.loadingValue) {
      this.buttonTarget.disabled = true
      if (this.hasButtonTextTarget) {
        this.buttonTextTarget.textContent = "Checking..."
      }
    } else {
      this.buttonTarget.disabled = false
      if (this.hasButtonTextTarget) {
        this.buttonTextTarget.textContent = "Check Status"
      }
    }
  }

  stopGeneration(event) {
    // Delay the UI update to allow the form submission to proceed first
    // Disabling the button synchronously would prevent the form from submitting
    setTimeout(() => {
      if (this.hasStopButtonTarget) {
        this.stopButtonTarget.disabled = true
        const span = this.stopButtonTarget.querySelector("span")
        if (span) {
          span.textContent = "Stopping..."
        }
      }
    }, 0)
    // Allow the form to submit normally (don't prevent default)
  }
}
