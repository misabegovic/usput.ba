import { Controller } from "@hotwired/stimulus"
import { travelProfileService } from "services/travel_profile_service"
import { planSyncService } from "services/plan_sync_service"

// The device's side of the session doors: it hands over what the browser is
// holding when a traveller signs in or signs up, and drops that traveller's copy
// when they sign out. Filled on submit, not on load: an inline script here never
// ran on a Turbo visit, which is how a guest's walk was being lost.
export default class extends Controller {
  static targets = ["profileData", "plansData"]

  connect() {
    this.element.addEventListener("submit", this.fill)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.fill)
  }

  fill = () => {
    if (this.hasProfileDataTarget) this.profileDataTarget.value = travelProfileService.forSignIn()
    if (this.hasPlansDataTarget) this.plansDataTarget.value = planSyncService.getPlansForRegistration()
  }

  // Runs while the page still carries the scope, which is what makes the key
  // resolvable — after the redirect there is no traveller left to name.
  clear() {
    travelProfileService.clearForCurrentTraveller()
  }
}
