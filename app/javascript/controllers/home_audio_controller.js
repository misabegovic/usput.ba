import { Controller } from "@hotwired/stimulus"

// Simple audio player for home page bento grid demo
export default class extends Controller {
  static targets = ["player", "playIcon", "pauseIcon", "currentTime", "duration", "bars"]

  connect() {
    this.isPlaying = false

    if (this.hasPlayerTarget) {
      // Try to update duration if metadata is already loaded
      if (this.playerTarget.readyState >= 1) {
        this.updateDuration()
      }

      this.playerTarget.addEventListener("loadedmetadata", () => {
        this.updateDuration()
      })

      // Fallback: also listen for durationchange event
      this.playerTarget.addEventListener("durationchange", () => {
        this.updateDuration()
      })

      this.playerTarget.addEventListener("timeupdate", () => {
        this.updateCurrentTime()
      })

      this.playerTarget.addEventListener("ended", () => {
        this.onEnded()
      })

      // Force load metadata if not yet loaded
      if (this.playerTarget.readyState === 0) {
        this.playerTarget.load()
      }
    }
  }

  togglePlay() {
    if (!this.hasPlayerTarget) return

    if (this.isPlaying) {
      this.playerTarget.pause()
      this.isPlaying = false
    } else {
      this.playerTarget.play()
      this.isPlaying = true
    }
    this.updateUI()
  }

  updateUI() {
    // Toggle play/pause icons
    if (this.hasPlayIconTarget && this.hasPauseIconTarget) {
      if (this.isPlaying) {
        this.playIconTarget.classList.add("hidden")
        this.pauseIconTarget.classList.remove("hidden")
      } else {
        this.playIconTarget.classList.remove("hidden")
        this.pauseIconTarget.classList.add("hidden")
      }
    }

    // Animate bars when playing
    if (this.hasBarsTarget) {
      const bars = this.barsTarget.querySelectorAll("div")
      bars.forEach(bar => {
        if (this.isPlaying) {
          bar.style.animationPlayState = "running"
        } else {
          bar.style.animationPlayState = "paused"
        }
      })
    }
  }

  updateCurrentTime() {
    if (this.hasCurrentTimeTarget && this.hasPlayerTarget) {
      this.currentTimeTarget.textContent = this.formatTime(this.playerTarget.currentTime)
    }
  }

  updateDuration() {
    if (this.hasDurationTarget && this.hasPlayerTarget && this.playerTarget.duration) {
      this.durationTarget.textContent = this.formatTime(this.playerTarget.duration)
    }
  }

  onEnded() {
    this.isPlaying = false
    this.updateUI()
    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = "0:00"
    }
  }

  formatTime(seconds) {
    if (isNaN(seconds) || !isFinite(seconds)) {
      return "0:00"
    }
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }
}
