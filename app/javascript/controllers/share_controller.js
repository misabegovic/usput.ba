import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "checkIcon", "text"]
  static values = {
    successMessage: { type: String, default: "Link kopiran!" }
  }

  async copy() {
    const url = window.location.href

    try {
      await navigator.clipboard.writeText(url)
      this.showSuccess()
    } catch (err) {
      // Fallback for older browsers
      this.fallbackCopy(url)
    }
  }

  fallbackCopy(text) {
    const textArea = document.createElement("textarea")
    textArea.value = text
    textArea.style.position = "fixed"
    textArea.style.left = "-999999px"
    document.body.appendChild(textArea)
    textArea.select()

    try {
      document.execCommand("copy")
      this.showSuccess()
    } catch (err) {
      console.error("Failed to copy:", err)
    }

    document.body.removeChild(textArea)
  }

  showSuccess() {
    // Show check icon
    if (this.hasIconTarget && this.hasCheckIconTarget) {
      this.iconTarget.classList.add("hidden")
      this.checkIconTarget.classList.remove("hidden")
    }

    // Update text if present
    if (this.hasTextTarget) {
      this.originalText = this.textTarget.textContent
      this.textTarget.textContent = this.successMessageValue
    }

    // Add success styling
    this.buttonTarget.classList.add("bg-emerald-500", "text-white")

    // Reset after 2 seconds
    setTimeout(() => {
      this.reset()
    }, 2000)
  }

  reset() {
    if (this.hasIconTarget && this.hasCheckIconTarget) {
      this.iconTarget.classList.remove("hidden")
      this.checkIconTarget.classList.add("hidden")
    }

    if (this.hasTextTarget && this.originalText) {
      this.textTarget.textContent = this.originalText
    }

    this.buttonTarget.classList.remove("bg-emerald-500", "text-white")
  }
}