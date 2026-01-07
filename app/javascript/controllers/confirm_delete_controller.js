import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]
  static values = { text: String }

  connect() {
    this.validate()
  }

  validate() {
    const isValid = this.inputTarget.value === this.textValue
    this.buttonTarget.disabled = !isValid
  }
}
