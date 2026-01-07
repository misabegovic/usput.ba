import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="photo-gallery"
// Photo gallery with horizontal slider and lightbox mode
export default class extends Controller {
  static targets = ["slide", "counter", "dot", "thumbnail", "slider", "lightbox", "lightboxImage", "lightboxCounter", "lightboxThumbnail"]
  static values = {
    index: { type: Number, default: 0 },
    lightboxOpen: { type: Boolean, default: false }
  }

  connect() {
    // Enable keyboard navigation
    this.boundKeyHandler = this.handleKeyDown.bind(this)
    document.addEventListener("keydown", this.boundKeyHandler)

    // Enable swipe on mobile
    this.setupSwipe()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeyHandler)
    this.closeLightbox()
  }

  // Navigate to next slide
  next() {
    const total = this.hasSlideTarget ? this.slideTargets.length : this.thumbnailTargets.length
    const newIndex = (this.indexValue + 1) % total
    this.goToIndex(newIndex)
  }

  // Navigate to previous slide
  previous() {
    const total = this.hasSlideTarget ? this.slideTargets.length : this.thumbnailTargets.length
    const newIndex = (this.indexValue - 1 + total) % total
    this.goToIndex(newIndex)
  }

  // Go to specific slide (from thumbnail or dot click)
  goTo(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this.goToIndex(index)
  }

  // Go to specific index
  goToIndex(index) {
    const total = this.hasSlideTarget ? this.slideTargets.length : this.thumbnailTargets.length
    if (index < 0 || index >= total) return

    // Update slides if present
    if (this.hasSlideTarget) {
      this.slideTargets.forEach((slide, i) => {
        if (i === index) {
          slide.classList.remove("opacity-0", "pointer-events-none")
          slide.classList.add("opacity-100")
        } else {
          slide.classList.remove("opacity-100")
          slide.classList.add("opacity-0", "pointer-events-none")
        }
      })
    }

    // Update counter
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = index + 1
    }

    // Update dots
    this.dotTargets.forEach((dot, i) => {
      if (i === index) {
        dot.classList.remove("bg-white/50", "hover:bg-white/80", "w-2")
        dot.classList.add("bg-white", "w-4")
      } else {
        dot.classList.remove("bg-white", "w-4")
        dot.classList.add("bg-white/50", "hover:bg-white/80", "w-2")
      }
    })

    // Update thumbnails
    this.thumbnailTargets.forEach((thumb, i) => {
      if (i === index) {
        thumb.classList.remove("ring-transparent", "hover:ring-gray-300", "dark:hover:ring-gray-600")
        thumb.classList.add("ring-emerald-500")
      } else {
        thumb.classList.remove("ring-emerald-500")
        thumb.classList.add("ring-transparent", "hover:ring-gray-300", "dark:hover:ring-gray-600")
      }
    })

    // Update lightbox if open
    if (this.lightboxOpenValue && this.hasLightboxImageTarget) {
      const thumb = this.thumbnailTargets[index]
      if (thumb) {
        const img = thumb.querySelector("img")
        if (img) {
          // Get full size URL (remove variants for ActiveStorage)
          let fullUrl = img.src
          this.lightboxImageTarget.src = fullUrl
          this.lightboxImageTarget.alt = img.alt
        }
      }
      if (this.hasLightboxCounterTarget) {
        this.lightboxCounterTarget.textContent = `${index + 1} / ${total}`
      }

      // Update lightbox thumbnails
      this.lightboxThumbnailTargets.forEach((lbThumb, i) => {
        if (i === index) {
          lbThumb.classList.remove("ring-transparent", "opacity-60")
          lbThumb.classList.add("ring-emerald-500", "opacity-100")
        } else {
          lbThumb.classList.remove("ring-emerald-500", "opacity-100")
          lbThumb.classList.add("ring-transparent", "opacity-60")
        }
      })
    }

    this.indexValue = index
  }

  // Open lightbox mode
  openLightbox(event) {
    if (event) {
      const index = parseInt(event.currentTarget.dataset.index, 10)
      if (!isNaN(index)) {
        this.indexValue = index
      }
    }

    if (!this.hasLightboxTarget) return

    this.lightboxOpenValue = true
    this.lightboxTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")

    // Set initial image
    const total = this.thumbnailTargets.length
    const thumb = this.thumbnailTargets[this.indexValue]
    if (thumb && this.hasLightboxImageTarget) {
      const img = thumb.querySelector("img")
      if (img) {
        this.lightboxImageTarget.src = img.src
        this.lightboxImageTarget.alt = img.alt
      }
    }
    if (this.hasLightboxCounterTarget) {
      this.lightboxCounterTarget.textContent = `${this.indexValue + 1} / ${total}`
    }
  }

  // Close lightbox mode
  closeLightbox() {
    if (!this.hasLightboxTarget) return

    this.lightboxOpenValue = false
    this.lightboxTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  // Close lightbox on background click
  closeLightboxOnBackground(event) {
    if (event.target === event.currentTarget) {
      this.closeLightbox()
    }
  }

  // Keyboard navigation
  handleKeyDown(event) {
    // Only handle if this gallery is visible
    if (!this.element.offsetParent) return

    if (event.key === "ArrowRight") {
      this.next()
    } else if (event.key === "ArrowLeft") {
      this.previous()
    } else if (event.key === "Escape" && this.lightboxOpenValue) {
      this.closeLightbox()
    }
  }

  // Touch swipe support
  setupSwipe() {
    let startX = 0
    let startY = 0

    this.element.addEventListener("touchstart", (e) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }, { passive: true })

    this.element.addEventListener("touchend", (e) => {
      const endX = e.changedTouches[0].clientX
      const endY = e.changedTouches[0].clientY
      const diffX = startX - endX
      const diffY = startY - endY

      // Only trigger swipe if horizontal movement is greater than vertical
      if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 50) {
        if (diffX > 0) {
          this.next()
        } else {
          this.previous()
        }
      }
    }, { passive: true })
  }
}
