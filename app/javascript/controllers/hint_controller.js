import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    if (this.#seen) return
    this.element.classList.replace("hidden", "flex")
  }

  dismiss() {
    if (this.keyValue) localStorage.setItem(this.keyValue, "1")
    this.element.classList.replace("flex", "hidden")
  }

  get #seen() {
    return Boolean(this.keyValue) && localStorage.getItem(this.keyValue) !== null
  }
}
