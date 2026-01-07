import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["icon", "label"]
  static values = {
    storageKey: { type: String, default: "theme" }
  }

  connect() {
    // Apply saved theme on connect
    this.applyTheme(this.currentTheme)

    // Listen for theme changes from other instances
    this.handleThemeChange = this.handleThemeChange.bind(this)
    window.addEventListener("theme:changed", this.handleThemeChange)
  }

  disconnect() {
    window.removeEventListener("theme:changed", this.handleThemeChange)
  }

  handleThemeChange(event) {
    // Update icon when another controller instance changes the theme
    this.updateIcon(event.detail.theme)
    this.updateLabel(event.detail.theme)
  }

  toggle() {
    const newTheme = this.currentTheme === "dark" ? "light" : "dark"
    this.applyTheme(newTheme)
    this.saveTheme(newTheme)

    // Broadcast theme change to all other instances
    window.dispatchEvent(new CustomEvent("theme:changed", { detail: { theme: newTheme } }))
  }

  applyTheme(theme) {
    const html = document.documentElement

    if (theme === "dark") {
      html.classList.add("dark")
    } else {
      html.classList.remove("dark")
    }

    this.updateIcon(theme)
    this.updateLabel(theme)
  }

  updateIcon(theme) {
    if (!this.hasIconTarget) return

    if (theme === "dark") {
      // Sun icon for dark mode (click to switch to light)
      this.iconTarget.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"></path>
        </svg>
      `
    } else {
      // Moon icon for light mode (click to switch to dark)
      this.iconTarget.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"></path>
        </svg>
      `
    }
  }

  updateLabel(theme) {
    if (!this.hasLabelTarget) return
    this.labelTarget.textContent = theme === "dark" ? "Light Mode" : "Dark Mode"
  }

  saveTheme(theme) {
    try {
      localStorage.setItem(this.storageKeyValue, theme)
    } catch (e) {
      // localStorage might be disabled
      console.warn("Could not save theme preference:", e)
    }
  }

  get currentTheme() {
    // Check localStorage first
    try {
      const stored = localStorage.getItem(this.storageKeyValue)
      if (stored === "dark" || stored === "light") {
        return stored
      }
    } catch (e) {
      // localStorage might be disabled
    }

    // Check if dark class is already applied (from inline script)
    if (document.documentElement.classList.contains("dark")) {
      return "dark"
    }

    // Default to light
    return "light"
  }
}
