import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="moment-lightbox"
export default class extends Controller {
  static targets = ["overlay", "image"]

  open(event) {
    this.imageTarget.src = event.currentTarget.dataset.momentLightboxUrl
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    this.boundKey ||= this.onKey.bind(this)
    document.addEventListener("keydown", this.boundKey)
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    this.imageTarget.removeAttribute("src")
    document.body.classList.remove("overflow-hidden")
    if (this.boundKey) document.removeEventListener("keydown", this.boundKey)
  }

  closeOnBackground(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  onKey(event) {
    if (event.key === "Escape") this.close()
  }

  disconnect() {
    if (this.boundKey) document.removeEventListener("keydown", this.boundKey)
    document.body.classList.remove("overflow-hidden")
  }
}
