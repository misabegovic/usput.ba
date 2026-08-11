import { Controller } from "@hotwired/stimulus"

// Uploads as soon as a photo is picked — no Add button. requestSubmit, not
// submit, so Turbo handles it and only this step is replaced.
export default class extends Controller {
  static targets = ["input", "form"]

  select() {
    if (this.inputTarget.files?.length) this.formTarget.requestSubmit()
  }
}
