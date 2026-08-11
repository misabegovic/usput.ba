import { Controller } from "@hotwired/stimulus"

// Swipe a step to the right to mark it visited — same result as the button.
// Mirrors setupSwipe in photo_gallery_controller.js.
export default class extends Controller {
  static targets = ["form"]

  connect() {
    this.setupSwipe()
  }

  setupSwipe() {
    let startX = 0
    let startY = 0

    this.element.addEventListener("touchstart", (e) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }, { passive: true })

    this.element.addEventListener("touchend", (e) => {
      const diffX = e.changedTouches[0].clientX - startX
      const diffY = e.changedTouches[0].clientY - startY

      // Right only: left has no meaning here, and a vertical scroll is not a swipe.
      if (diffX > 50 && Math.abs(diffX) > Math.abs(diffY) && this.hasFormTarget) {
        this.formTarget.requestSubmit()
      }
    }, { passive: true })
  }
}
