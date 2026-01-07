import { Controller } from "@hotwired/stimulus"

// Audio Tour controller for multilingual audio playback with custom player controls
// Allows users to switch between different language versions of audio tours
export default class extends Controller {
  static targets = [
    "player", "playButton", "playIcon", "pauseIcon", "progress", "currentTime", "duration",
    "languageButton", "languageMenu", "currentLanguage"
  ]
  static values = {
    currentLocale: String,
    audioUrls: Object // { locale: url, ... }
  }

  connect() {
    this.isPlaying = false

    // Close language menu when clicking outside
    this.clickOutsideHandler = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)

    if (this.hasPlayerTarget) {
      this.playerTarget.addEventListener("loadedmetadata", () => {
        this.updateDuration()
      })

      this.playerTarget.addEventListener("timeupdate", () => {
        this.updateProgress()
      })

      this.playerTarget.addEventListener("ended", () => {
        this.onEnded()
      })
    }

    // Load user's preferred language from localStorage
    this.loadPreferredLanguage()
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  // ==================== Player Controls ====================

  togglePlay() {
    if (!this.hasPlayerTarget) return

    if (this.isPlaying) {
      this.playerTarget.pause()
      this.isPlaying = false
    } else {
      this.playerTarget.play()
      this.isPlaying = true
    }
    this.updatePlayButton()
  }

  updatePlayButton() {
    if (this.hasPlayIconTarget && this.hasPauseIconTarget) {
      if (this.isPlaying) {
        this.playIconTarget.classList.add("hidden")
        this.pauseIconTarget.classList.remove("hidden")
      } else {
        this.playIconTarget.classList.remove("hidden")
        this.pauseIconTarget.classList.add("hidden")
      }
    }
  }

  rewind() {
    if (this.hasPlayerTarget) {
      this.playerTarget.currentTime = Math.max(0, this.playerTarget.currentTime - 10)
    }
  }

  forward() {
    if (this.hasPlayerTarget) {
      this.playerTarget.currentTime = Math.min(this.playerTarget.duration, this.playerTarget.currentTime + 10)
    }
  }

  seek() {
    if (this.hasProgressTarget && this.hasPlayerTarget && this.playerTarget.duration) {
      const seekTime = (this.progressTarget.value / 100) * this.playerTarget.duration
      this.playerTarget.currentTime = seekTime
    }
  }

  updateProgress() {
    if (this.hasProgressTarget && this.hasPlayerTarget && this.playerTarget.duration) {
      const progress = (this.playerTarget.currentTime / this.playerTarget.duration) * 100
      this.progressTarget.value = progress
    }

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
    this.updatePlayButton()
    if (this.hasProgressTarget) {
      this.progressTarget.value = 0
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

  // ==================== Language Switching ====================

  // Toggle language selection menu
  toggleMenu(event) {
    event.stopPropagation()
    if (this.hasLanguageMenuTarget) {
      this.languageMenuTarget.classList.toggle("hidden")
    }
  }

  // Switch to a different language
  selectLanguage(event) {
    event.preventDefault()
    const locale = event.currentTarget.dataset.locale
    const languageName = event.currentTarget.dataset.languageName
    const audioUrl = event.currentTarget.dataset.audioUrl

    if (!audioUrl || !this.hasPlayerTarget) {
      console.error("No audio URL for locale:", locale)
      return
    }

    // Remember playback state
    const wasPlaying = this.isPlaying

    // Update audio source
    this.playerTarget.src = audioUrl
    this.playerTarget.load()

    // Update current locale
    this.currentLocaleValue = locale

    // Update UI to show current language
    if (this.hasCurrentLanguageTarget) {
      this.currentLanguageTarget.textContent = languageName
    }

    // Update active state on language buttons
    this.updateActiveLanguageButton(locale)

    // Save preference to localStorage
    this.savePreferredLanguage(locale)

    // Close menu
    this.closeMenu()

    // If was playing, continue playback
    if (wasPlaying) {
      this.playerTarget.play()
        .then(() => {
          this.isPlaying = true
          this.updatePlayButton()
        })
        .catch(e => console.log("Autoplay prevented:", e))
    }
  }

  // Close the language menu
  closeMenu() {
    if (this.hasLanguageMenuTarget) {
      this.languageMenuTarget.classList.add("hidden")
    }
  }

  // Handle clicks outside the menu
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeMenu()
    }
  }

  // Update which language button appears active
  updateActiveLanguageButton(activeLocale) {
    this.languageButtonTargets.forEach(button => {
      const locale = button.dataset.locale
      if (locale === activeLocale) {
        button.classList.add("bg-white/20", "font-medium")
        button.classList.remove("hover:bg-white/10")
      } else {
        button.classList.remove("bg-white/20", "font-medium")
        button.classList.add("hover:bg-white/10")
      }
    })
  }

  // Save preferred language to localStorage
  savePreferredLanguage(locale) {
    try {
      localStorage.setItem("audio_tour_locale", locale)
    } catch (e) {
      // localStorage not available, ignore
    }
  }

  // Load and apply preferred language
  loadPreferredLanguage() {
    try {
      const savedLocale = localStorage.getItem("audio_tour_locale")
      if (savedLocale && this.audioUrlsValue && this.audioUrlsValue[savedLocale]) {
        // Find the button for the saved locale and click it
        const button = this.languageButtonTargets.find(b => b.dataset.locale === savedLocale)
        if (button && savedLocale !== this.currentLocaleValue) {
          // Simulate click to switch to preferred language
          button.click()
        }
      }
    } catch (e) {
      // localStorage not available, ignore
    }
  }

  // Get current locale value
  get currentLocale() {
    return this.currentLocaleValue || "bs"
  }
}
