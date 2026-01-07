import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["star", "input"]

  connect() {
    this.updateStars(parseInt(this.inputTarget.value) || 0)
  }

  setRating(event) {
    const rating = parseInt(event.params.value)
    this.inputTarget.value = rating
    this.updateStars(rating)
  }

  updateStars(rating) {
    this.starTargets.forEach((star, index) => {
      const svg = star.querySelector('svg')
      if (!svg) return
      if (index < rating) {
        svg.classList.remove('text-gray-300', 'dark:text-gray-600')
        svg.classList.add('text-amber-400')
      } else {
        svg.classList.remove('text-amber-400')
        svg.classList.add('text-gray-300', 'dark:text-gray-600')
      }
    })
  }
}
