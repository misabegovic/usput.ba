import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input"]

  submit() {
    if (this.inputTarget.files.length > 0) {
      this.formTarget.submit()
    }
  }
}
