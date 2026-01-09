import { Controller } from "@hotwired/stimulus"

// Copies admin credentials from shared input fields to hidden form fields before submission
export default class extends Controller {
  static targets = ["usernameField", "passwordField"]
  static values = {
    usernameId: String,
    passwordId: String
  }

  copyCredentials(event) {
    const usernameInput = document.getElementById(this.usernameIdValue)
    const passwordInput = document.getElementById(this.passwordIdValue)

    if (!usernameInput || !passwordInput) {
      console.error("Credential input fields not found")
      return
    }

    const username = usernameInput.value.trim()
    const password = passwordInput.value.trim()

    if (!username || !password) {
      event.preventDefault()
      alert("Please enter your admin credentials before proceeding.")
      return
    }

    // Copy values to hidden fields
    if (this.hasUsernameFieldTarget) {
      this.usernameFieldTarget.value = username
    }
    if (this.hasPasswordFieldTarget) {
      this.passwordFieldTarget.value = password
    }
  }
}
