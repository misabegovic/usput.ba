import { Controller } from "@hotwired/stimulus"

// Handles "Load More" functionality for explore page
// Each instance manages one resource type (locations, experiences, or plans)
export default class extends Controller {
  static targets = ["container", "button", "loading", "count"]
  static values = {
    url: String,
    resourceType: String,
    page: { type: Number, default: 1 },
    totalCount: Number,
    perPage: { type: Number, default: 3 }
  }

  connect() {
    this.updateButtonVisibility()
  }

  async loadMore(event) {
    event.preventDefault()

    if (this.loading) return
    this.loading = true

    // Show loading state
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.add("hidden")
    }
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }

    try {
      const nextPage = this.pageValue + 1
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set(`${this.resourceTypeValue}_page`, nextPage)
      url.searchParams.set("partial", this.resourceTypeValue)

      // Preserve existing search params
      const currentParams = new URLSearchParams(window.location.search)
      for (const [key, value] of currentParams) {
        if (!url.searchParams.has(key) && key !== `${this.resourceTypeValue}_page` && key !== "partial") {
          url.searchParams.set(key, value)
        }
      }

      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()

        // Append new items to all containers (supports desktop + mobile)
        this.containerTargets.forEach(container => {
          container.insertAdjacentHTML("beforeend", html)
        })

        // Update page counter
        this.pageValue = nextPage

        // Update displayed count
        this.updateCount()
      }
    } catch (error) {
      console.error("Error loading more items:", error)
    } finally {
      this.loading = false
      if (this.hasLoadingTarget) {
        this.loadingTarget.classList.add("hidden")
      }
      this.updateButtonVisibility()
    }
  }

  updateButtonVisibility() {
    if (!this.hasButtonTarget) return

    const loadedCount = this.pageValue * this.perPageValue
    const hasMore = loadedCount < this.totalCountValue

    if (hasMore) {
      this.buttonTarget.classList.remove("hidden")
    } else {
      this.buttonTarget.classList.add("hidden")
    }
  }

  updateCount() {
    if (this.hasCountTarget) {
      const loadedCount = Math.min(this.pageValue * this.perPageValue, this.totalCountValue)
      this.countTarget.textContent = loadedCount
    }
  }
}
