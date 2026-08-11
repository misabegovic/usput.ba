import { Controller } from "@hotwired/stimulus"

// Tap the badge on a walk card to play (or pause) that location's audio tour.
export default class extends Controller {
  static targets = ["player", "playIcon", "pauseIcon"]

  toggle() {
    if (this.playerTarget.paused) {
      this.playerTarget.play()
    } else {
      this.playerTarget.pause()
    }
  }

  playerTargetConnected(player) {
    player.addEventListener("play", () => this.reflect(true))
    player.addEventListener("pause", () => this.reflect(false))
    player.addEventListener("ended", () => this.reflect(false))
  }

  reflect(playing) {
    if (this.hasPlayIconTarget) this.playIconTarget.classList.toggle("hidden", playing)
    if (this.hasPauseIconTarget) this.pauseIconTarget.classList.toggle("hidden", !playing)
  }
}
