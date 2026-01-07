import { Controller } from "@hotwired/stimulus"

// Mobile slider controller for horizontal scrolling with dots navigation
export default class extends Controller {
  static targets = ["container", "slide", "dots"]
  static values = {
    autoplay: { type: Boolean, default: false },
    interval: { type: Number, default: 5000 }
  }

  connect() {
    this.currentIndex = 0
    this.setupObserver()
    this.updateDots()

    if (this.autoplayValue && this.slideTargets.length > 1) {
      this.startAutoplay()
    }
  }

  disconnect() {
    this.stopAutoplay()
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  setupObserver() {
    const options = {
      root: this.containerTarget,
      rootMargin: "0px",
      threshold: 0.5
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          const index = this.slideTargets.indexOf(entry.target)
          if (index !== -1) {
            this.currentIndex = index
            this.updateDots()
          }
        }
      })
    }, options)

    this.slideTargets.forEach((slide) => {
      this.observer.observe(slide)
    })
  }

  goToSlide(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this.scrollToIndex(index)
  }

  next() {
    const nextIndex = (this.currentIndex + 1) % this.slideTargets.length
    this.scrollToIndex(nextIndex)
  }

  previous() {
    const prevIndex = (this.currentIndex - 1 + this.slideTargets.length) % this.slideTargets.length
    this.scrollToIndex(prevIndex)
  }

  scrollToIndex(index) {
    const slide = this.slideTargets[index]
    if (slide) {
      slide.scrollIntoView({
        behavior: "smooth",
        block: "nearest",
        inline: "start"
      })
      this.currentIndex = index
      this.updateDots()
    }
  }

  updateDots() {
    if (!this.hasDotsTarget) return

    const dots = this.dotsTarget.querySelectorAll("[data-dot]")
    dots.forEach((dot, index) => {
      if (index === this.currentIndex) {
        dot.classList.remove("bg-gray-300", "dark:bg-gray-600")
        dot.classList.add("bg-emerald-500", "dark:bg-emerald-400")
      } else {
        dot.classList.remove("bg-emerald-500", "dark:bg-emerald-400")
        dot.classList.add("bg-gray-300", "dark:bg-gray-600")
      }
    })
  }

  startAutoplay() {
    this.autoplayTimer = setInterval(() => {
      this.next()
    }, this.intervalValue)
  }

  stopAutoplay() {
    if (this.autoplayTimer) {
      clearInterval(this.autoplayTimer)
    }
  }

  pauseAutoplay() {
    this.stopAutoplay()
  }

  resumeAutoplay() {
    if (this.autoplayValue && this.slideTargets.length > 1) {
      this.startAutoplay()
    }
  }
}
