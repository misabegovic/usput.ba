import { Controller } from "@hotwired/stimulus"

// Turbo's own lazy frame cannot do this: the slots have to be direct children of
// the scroll container to size and snap, which leaves the frame display:contents,
// and a boxless element never intersects.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => { if (entries.some((entry) => entry.isIntersecting)) this.load() },
      { root: this.element.closest("[data-controller~='plan-deck']"), rootMargin: "300px" }
    )
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async load() {
    if (this.loading) return
    this.loading = true
    this.observer.disconnect()

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      if (!response.ok) throw new Error(response.status)
      window.Turbo.renderStreamMessage(await response.text())
    } catch {
      // Scrolling past and back is then a retry, rather than a deck that ends
      // early and looks complete.
      this.loading = false
      this.observer.observe(this.element)
    }
  }
}
