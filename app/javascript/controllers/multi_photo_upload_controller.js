import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "placeholder", "previewContainer", "previews", "count", "area"]

  select(event) {
    const files = event.target.files
    if (!files || files.length === 0) return

    // Validate file count
    if (files.length > 10) {
      alert("Maximum 10 photos allowed")
      this.clearAll()
      return
    }

    // Show preview container, hide placeholder
    this.placeholderTarget.classList.add("hidden")
    this.previewContainerTarget.classList.remove("hidden")
    this.areaTarget.classList.remove("border-dashed", "border-gray-300")
    this.areaTarget.classList.add("border-solid", "border-emerald-500")

    // Update count
    this.countTarget.textContent = `${files.length} photo${files.length > 1 ? 's' : ''} selected`

    // Clear existing previews
    this.previewsTarget.innerHTML = ""

    // Create previews for each file
    Array.from(files).forEach((file, index) => {
      this.createPreview(file, index)
    })
  }

  createPreview(file, index) {
    const wrapper = document.createElement("div")
    wrapper.className = "relative aspect-square"

    const img = document.createElement("img")
    img.src = URL.createObjectURL(file)
    img.className = "w-full h-full object-cover rounded-lg"
    img.alt = file.name

    const badge = document.createElement("div")
    badge.className = "absolute top-1 right-1 bg-emerald-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs"
    badge.textContent = index + 1

    wrapper.appendChild(img)
    wrapper.appendChild(badge)
    this.previewsTarget.appendChild(wrapper)
  }

  clearAll() {
    this.inputTarget.value = ""
    this.previewsTarget.innerHTML = ""
    this.previewContainerTarget.classList.add("hidden")
    this.placeholderTarget.classList.remove("hidden")
    this.areaTarget.classList.add("border-dashed", "border-gray-300")
    this.areaTarget.classList.remove("border-solid", "border-emerald-500")
  }
}
