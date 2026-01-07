import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["generateBtn", "costEstimate", "selectedCount", "estChars", "estCost", "search"]

  connect() {
    this.updateCostEstimate()
  }

  updateCostEstimate() {
    const locationCheckboxes = this.element.querySelectorAll('.location-checkbox')
    let count = 0
    let chars = 0

    locationCheckboxes.forEach(cb => {
      if (cb.checked) {
        count++
        chars += parseInt(cb.dataset.chars || 2000)
      }
    })

    if (count > 0) {
      this.costEstimateTarget.classList.remove('hidden')
      this.selectedCountTarget.textContent = count
      this.estCharsTarget.textContent = chars.toLocaleString()
      const cost = (chars / 1000 * 0.30).toFixed(2)
      this.estCostTarget.textContent = '$' + cost
      this.generateBtnTarget.disabled = false
    } else {
      this.costEstimateTarget.classList.add('hidden')
      this.generateBtnTarget.disabled = true
    }
  }

  toggleCity(event) {
    const city = event.target.dataset.city
    const isChecked = event.target.checked
    this.element.querySelectorAll(`.location-checkbox[data-city="${city}"]`).forEach(cb => {
      cb.checked = isChecked
    })
    this.updateCostEstimate()
  }

  selectAll(event) {
    event.preventDefault()
    this.element.querySelectorAll('.location-checkbox').forEach(cb => cb.checked = true)
    this.element.querySelectorAll('.city-checkbox').forEach(cb => cb.checked = true)
    this.updateCostEstimate()
  }

  deselectAll(event) {
    event.preventDefault()
    this.element.querySelectorAll('.location-checkbox').forEach(cb => cb.checked = false)
    this.element.querySelectorAll('.city-checkbox').forEach(cb => cb.checked = false)
    this.updateCostEstimate()
  }

  search(event) {
    clearTimeout(this.searchTimeout)

    if (event.key === 'Enter') {
      event.preventDefault()
      this.performSearch()
      return
    }

    this.searchTimeout = setTimeout(() => {
      this.performSearch()
    }, 500)
  }

  performSearch() {
    const searchInput = this.searchTarget
    const url = new URL(searchInput.dataset.url, window.location.origin)
    if (searchInput.value.trim()) {
      url.searchParams.set('q', searchInput.value.trim())
    }
    window.location.href = url.toString()
  }
}
