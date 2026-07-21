import { Controller } from "@hotwired/stimulus"
import "leaflet"

// Public mine-proximity check. The server returns coarse bands only —
// no distances or geometry ever reach this controller.
const BAND_STYLES = {
  danger: "border-red-500 bg-red-50 dark:bg-red-900/40 text-red-900 dark:text-red-100",
  caution: "border-amber-500 bg-amber-50 dark:bg-amber-900/40 text-amber-900 dark:text-amber-100",
  no_known: "border-emerald-500 bg-emerald-50 dark:bg-emerald-900/40 text-emerald-900 dark:text-emerald-100",
  out_of_coverage: "border-gray-400 bg-gray-50 dark:bg-gray-800 text-gray-700 dark:text-gray-300",
  unavailable: "border-gray-400 bg-gray-50 dark:bg-gray-800 text-gray-700 dark:text-gray-300",
  error: "border-gray-400 bg-gray-50 dark:bg-gray-800 text-gray-700 dark:text-gray-300"
}
const RESULT_BASE = "mt-4 rounded-xl border-2 px-4 py-3 text-sm font-medium"

export default class extends Controller {
  static targets = ["map", "result", "lat", "lon", "playLink", "zoomHint"]
  static values = { url: String, labels: Object, playUrl: String, areasUrl: String }

  connect() {
    const L = window.L
    this.map = L.map(this.mapTarget, { attributionControl: true }).setView([44.2, 17.8], 8)
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 17,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)
    this.map.on("click", (e) => this.checkPoint(e.latlng.lat, e.latlng.lng))

    // Overlay of recorded suspected areas — generalized boundaries, loaded
    // per viewport once zoomed in far enough for an honest rendering.
    this.areasLayer = L.geoJSON(null, {
      style: { color: "#b91c1c", weight: 1, fillColor: "#dc2626", fillOpacity: 0.35 }
    }).addTo(this.map)
    this.map.on("moveend", () => this.loadAreas())
    this.loadAreas()
  }

  async loadAreas() {
    if (!this.hasAreasUrlValue) return
    if (this.map.getZoom() < 9) {
      this.areasLayer.clearLayers()
      if (this.hasZoomHintTarget) this.zoomHintTarget.classList.remove("hidden")
      this.showOverview()
      return
    }
    if (this.hasZoomHintTarget) this.zoomHintTarget.classList.add("hidden")
    if (this.overviewLayer) this.overviewLayer.remove()
    const b = this.map.getBounds()
    const params = new URLSearchParams({
      west: b.getWest().toFixed(3), south: b.getSouth().toFixed(3),
      east: b.getEast().toFixed(3), north: b.getNorth().toFixed(3)
    })
    try {
      const response = await fetch(`${this.areasUrlValue}?${params}`)
      if (!response.ok) return
      const data = await response.json()
      this.areasLayer.clearLayers()
      this.areasLayer.addData(data)
    } catch {
      // overlay is best-effort; the check endpoint remains authoritative
    }
  }

  disconnect() {
    if (this.map) this.map.remove()
  }

  locate() {
    if (!navigator.geolocation) {
      this.renderResult("error", this.labelsValue.no_gps)
      return
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        this.map.setView([pos.coords.latitude, pos.coords.longitude], 14)
        this.checkPoint(pos.coords.latitude, pos.coords.longitude)
      },
      () => this.renderResult("error", this.labelsValue.no_gps)
    )
  }

  checkManual() {
    const lat = parseFloat(this.latTarget.value)
    const lon = parseFloat(this.lonTarget.value)
    if (Number.isNaN(lat) || Number.isNaN(lon)) {
      this.renderResult("error", this.labelsValue.invalid)
      return
    }
    this.map.setView([lat, lon], 13)
    this.checkPoint(lat, lon)
  }

  async checkPoint(lat, lon) {
    this.latTarget.value = lat.toFixed(5)
    this.lonTarget.value = lon.toFixed(5)
    if (this.marker) this.marker.remove()
    this.marker = window.L.circleMarker([lat, lon], { radius: 8, color: "#047857", weight: 3 }).addTo(this.map)
    this.renderResult("pending", this.labelsValue.checking)

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ lat: lat, lon: lon })
      })
      if (!response.ok) throw new Error("bad response")
      const data = await response.json()
      this.renderResult(data.band, this.labelsValue[data.band] || this.labelsValue.error)
      if (this.hasPlayLinkTarget) {
        this.playLinkTarget.href = `${this.playUrlValue}?lat=${lat.toFixed(5)}&lon=${lon.toFixed(5)}`
        this.playLinkTarget.classList.remove("hidden")
        this.playLinkTarget.classList.add("inline-block")
      }
    } catch {
      this.renderResult("error", this.labelsValue.error)
    }
  }

  // National-zoom dots: one per ~1 km grid cell with a recorded area —
  // distribution without boundary geometry.
  async showOverview() {
    if (this.overviewLayer) {
      this.overviewLayer.addTo(this.map)
      return
    }
    try {
      const response = await fetch(`${this.areasUrlValue}?overview=1`)
      if (!response.ok) return
      const data = await response.json()
      this.overviewLayer = window.L.geoJSON(data, {
        pointToLayer: (feature, latlng) => window.L.circleMarker(latlng, {
          radius: 3, color: "#b91c1c", weight: 1, fillColor: "#dc2626", fillOpacity: 0.7
        })
      }).addTo(this.map)
    } catch {
      // best-effort overlay
    }
  }

  renderResult(band, text) {
    const el = this.resultTarget
    el.className = `${RESULT_BASE} ${BAND_STYLES[band] || BAND_STYLES.error}`
    el.textContent = text
    el.classList.remove("hidden")
  }
}
