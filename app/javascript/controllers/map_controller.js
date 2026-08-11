import { Controller } from "@hotwired/stimulus"
import { positionService } from "services/position_service"
import { distanceKm, profileFor, summarise, fetchRoute } from "services/route_service"
import "leaflet"

const L = window.L

// Below this the pins stand alone: a town fits on screen, which is where the
// operator wants to stop seeing bubbles.
const CLUSTER_UNTIL_ZOOM = 13
const CHIP_MS = 4000
const FOCUS_ZOOM = 15
// Every map on the page wants the same catalogue, and the explore reel mounts
// one per card. Fetch it once per page, and keep it for the session so moving
// between places does not re-download the country. The version is the newest
// content edit, so a stale copy is simply a key nobody asks for.
let cataloguePromise = null

function catalogue(version) {
  if (cataloguePromise) return cataloguePromise

  const key = `usput_map_points/${version}`
  const held = sessionStorage.getItem(key)
  if (held) {
    try {
      cataloguePromise = Promise.resolve(JSON.parse(held))
      return cataloguePromise
    } catch {
      sessionStorage.removeItem(key)
    }
  }

  cataloguePromise = fetch("/locations/map_points", { headers: { Accept: "application/json" } })
    .then((response) => (response.ok ? response.json() : Promise.reject(new Error(response.status))))
    .then((points) => {
      try {
        Object.keys(sessionStorage)
          .filter((held) => held.startsWith("usput_map_points/") && held !== key)
          .forEach((stale) => sessionStorage.removeItem(stale))
        sessionStorage.setItem(key, JSON.stringify(points))
      } catch {
        // A full quota is not a reason to lose the map.
      }
      return points
    })
    .catch(() => {
      // null is "we could not load", [] is "there is nothing" — the map says
      // different things about each, and a retry is only sane for the first.
      cataloguePromise = null
      return null
    })

  return cataloguePromise
}

// Renders a simple OpenStreetMap view with pins, plus a full-viewport toggle.
// No API key required — tiles come from openstreetmap.org.
//
// Each point: { lat, lng, name, main?, url? }
export default class extends Controller {
  static targets = ["container", "fullscreenButton", "expandIcon", "collapseIcon", "panel", "panelFrame"]
  static values = {
    lat: Number,
    lng: Number,
    points: Array,
    userLocation: Boolean,
    catalogue: Boolean,
    // A cache key, not a number: as Number it coerced to NaN and every version
    // shared one sessionStorage entry.
    catalogueVersion: String,
    byFootLabel: String,
    byCarLabel: String,
    loadFailedLabel: String,
    noPositionLabel: String,
    noRouteLabel: String,
  }

  // A deck mounts one of these per card behind a hidden panel. display:none has
  // no box, so those wait for the panel to open instead of building N maps.
  connect() {
    if (this.element.getClientRects().length > 0) return this.#build()

    this.revealObserver = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.#build()
    })
    this.revealObserver.observe(this.element)
  }

  #build() {
    if (this.map) return
    this.revealObserver?.disconnect()

    this.expanded = false
    this.selectedId = this.pointsValue.find((point) => point.main)?.id

    this.map = L.map(this.containerTarget, { scrollWheelZoom: false })
      .setView([this.latValue, this.lngValue], 15)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map)

    const bounds = []
    this.pointsValue.forEach((point) => {
      bounds.push([point.lat, point.lng])
      // With the catalogue on, this place is drawn by it — clustered like the
      // rest, so zooming out groups it instead of leaving one pin behind.
      if (this.catalogueValue) return

      L.marker([point.lat, point.lng], { icon: this.#iconFor({ selected: point.main }) })
        .addTo(this.map)
        .bindPopup(this.#popupFor(point))
    })

    if (bounds.length > 1) {
      this.map.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 })
    }

    if (this.catalogueValue) this.#loadCatalogue()
    if (this.userLocationValue) this.#locateUser()

    if (this.hasFullscreenButtonTarget) {
      L.DomEvent.disableClickPropagation(this.fullscreenButtonTarget)
    }

    // The panel sits inside the map element so it survives the fullscreen
    // toggle, which means Leaflet would otherwise treat every click and scroll
    // inside it as a map gesture — including the links Turbo needs to handle.
    if (this.hasPanelTarget) {
      L.DomEvent.disableClickPropagation(this.panelTarget)
      L.DomEvent.disableScrollPropagation(this.panelTarget)
    }

    this.onKeydown = (event) => {
      if (event.key === "Escape" && this.expanded) this.toggleFullscreen()
    }
    document.addEventListener("keydown", this.onKeydown)

    // Hidden-panel maps lay out at zero size; re-measure + locate on reveal.
    this.onResize = () => {
      this.map?.invalidateSize()
      if (this.userLocationValue && !this.located && this.#onScreen()) this.#locateUser()
    }
    window.addEventListener("resize", this.onResize)
  }

  // The whole catalogue, clustered. chunkedLoading is read by addLayers alone,
  // so adding markers one at a time opted out of it and blocked the main thread.
  async #loadCatalogue() {
    const points = await catalogue(this.catalogueVersionValue)
    if (!this.map) return
    if (points === null) return this.#showChip(this.loadFailedLabelValue)
    if (points.length === 0) return

    // Fetched here, not at module top level, where eager controller loading put
    // the plugin on the home page, the login page and the profile.
    await import("leaflet.markercluster")
    if (!this.map) return

    this.clusters = L.markerClusterGroup({
      chunkedLoading: true,
      disableClusteringAtZoom: CLUSTER_UNTIL_ZOOM,
      spiderfyOnMaxZoom: false,
      showCoverageOnHover: false,
    })

    this.markers = new Map()

    const markers = points.map((point) => {
      const selected = point.id === this.selectedId
      const marker = L.marker([point.lat, point.lng], {
        icon: this.#iconFor({ selected }),
        zIndexOffset: selected ? 1000 : 0,
      })
      marker.on("click", () => {
        this.#select(point.id)
        this.#routeTo(point)
        // Only the maps that carry a panel open one; the walk and the reel
        // keep their own surface and just re-route.
        if (!this.hasPanelTarget) return
        if (!this.expanded) this.toggleFullscreen()
        this.#openPanel(point.id)
      })
      this.markers.set(point.id, marker)
      return marker
    })

    this.clusters.addLayers(markers)
    this.map.addLayer(this.clusters)
  }

  #iconFor({ selected = false } = {}) {
    const width = selected ? 34 : 24
    const height = selected ? 46 : 33

    return L.divIcon({
      className: "",
      html: `<svg width="${width}" height="${height}" viewBox="0 0 24 33">
        <path d="M12 0C5.37 0 0 5.37 0 12c0 8.25 12 21 12 21s12-12.75 12-21C24 5.37 18.63 0 12 0z"
              fill="${selected ? "#059669" : "#e11d48"}" stroke="#ffffff" stroke-width="2.5"/>
        <circle cx="12" cy="12" r="4.2" fill="#ffffff"/>
      </svg>`,
      iconSize: [width, height],
      iconAnchor: [width / 2, height],
      popupAnchor: [0, -height],
    })
  }

  // Selection follows the traveller: the place they arrived on starts selected,
  // and clicking another hands the larger icon over to it.
  #select(id) {
    if (this.selectedId === id) return

    const previous = this.markers?.get(this.selectedId)
    if (previous) previous.setIcon(this.#iconFor())

    const next = this.markers?.get(id)
    if (next) {
      next.setIcon(this.#iconFor({ selected: true }))
      next.setZIndexOffset(1000)
    }
    this.selectedId = id
  }

  // Walking directions to whatever was tapped. A route is only honest from
  // where the traveller actually is, so without a fix there is no line — the
  // page's own place is not where they are standing.
  #routeTo(point) {
    this.routeTarget = point
    this.#clearPath()

    const measured = positionService.measured()
    if (!measured) {
      this.#focusOn(point, null)
      this.#showChip(this.noPositionLabelValue, { clearAfterMs: CHIP_MS })
      return
    }

    this.routeOrigin = [measured.latitude, measured.longitude]
    this.#drawPath(this.routeOrigin, point)
    this.#followUser()
  }

  #openPanel(id) {
    if (!this.hasPanelTarget) return

    this.map.closePopup()
    // The frame belongs to this map, not to the place shown, so the response
    // comes back wearing the asking frame's id — a deck has one map per card.
    const frame = encodeURIComponent(this.panelFrameTarget.id)
    this.panelFrameTarget.src = `/locations/${id}/map_panel?frame=${frame}`
    this.panelTarget.classList.remove("hidden")
    requestAnimationFrame(() => this.map?.invalidateSize())
  }

  closePanel() {
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.add("hidden")
    this.panelFrameTarget.removeAttribute("src")
    this.panelFrameTarget.innerHTML = ""
    requestAnimationFrame(() => this.map?.invalidateSize())
  }


  #locateUser() {
    if (!navigator.geolocation) return
    this.located = true
    this.#onFirstFix((coords) => {
      const here = [coords.latitude, coords.longitude]
      const target = this.routeTarget || this.pointsValue[0]
      this.userMarker = L.circleMarker(here, { radius: 8, color: "#ffffff", weight: 2, fillColor: "#2563eb", fillOpacity: 1 }).addTo(this.map)
      this.#followUser()
      if (!target) return
      this.routeTarget = target
      this.routeOrigin = here
      this.#drawPath(here, target)
    })
  }

  // One fix from the shared watcher, whether or not it has one yet.
  #onFirstFix(handler) {
    const held = positionService.measured()
    if (held) return handler(held)

    const stop = positionService.subscribe(
      (coords) => {
        stop()
        handler(coords)
      },
      () => {
        stop()
        this.located = false
        this.#showChip(this.noPositionLabelValue, { clearAfterMs: CHIP_MS })
      }
    )
  }

  // The dot walks with you. The route does not re-fetch — navigation is the
  // hand-off's job, so there is nothing here to keep correcting.
  #followUser() {
    if (this.unfollow) return

    this.unfollow = positionService.subscribe((coords) => {
      if (!this.#onScreen()) return this.#stopFollowing()
      this.userMarker?.setLatLng([coords.latitude, coords.longitude])
    })
  }

  // offsetParent is null for a fixed element, and fullscreen makes the map
  // fixed — so testing it stopped the position following the moment the map
  // went fullscreen. Client rects are honest for both.
  #onScreen() {
    return this.containerTarget.getClientRects().length > 0
  }

  #stopFollowing() {
    this.unfollow?.()
    this.unfollow = undefined
    this.located = false
  }

  #clearPath() {
    this.routeLayer?.remove()
    this.routeChip?.remove()
    this.routeLayer = this.routeChip = null
  }

  // The real walking route when the proxy can deliver one, and no line at all
  // otherwise — a straight line between two points is not a route.
  async #drawPath(here, target) {
    const profile = profileFor(distanceKm(here[0], here[1], target.lat, target.lng))

    // Through the service like every other caller: this is the app's only
    // request to the routing upstream, so it is the only place that has to be
    // counted when the quota is the question.
    const route = await fetchRoute({ fromLat: here[0], fromLng: here[1], toLat: target.lat, toLng: target.lng, profile })
    if (!route) {
      this.#focusOn(target, null)
      return this.#showChip(this.noRouteLabelValue, { clearAfterMs: CHIP_MS })
    }

    this.routeLayer = L.polyline(route.points, { color: "#2563eb", weight: 4, opacity: 0.85 }).addTo(this.map)
    this.#addRouteChip(route)
    this.#focusOn(target, profile === "foot-walking" ? route.points : null)
  }

  // A walk is worth looking at whole. A drive across the country is not — two
  // points that far apart zoom out past anything legible, so show the
  // destination instead.
  #focusOn(target, points) {
    if (points) return this.#frame(points)
    this.map.setView([target.lat, target.lng], FOCUS_ZOOM)
  }

  // Phones have less room than the desktop route framing assumes, and two
  // distant points would otherwise zoom out past anything legible.
  #frame(points) {
    const tight = this.containerTarget.clientWidth < 480
    this.map.fitBounds(points, { padding: tight ? [16, 16] : [30, 30], maxZoom: 15 })
  }

  #addRouteChip(route) {
    this.#showChip(summarise(route, { byFoot: this.byFootLabelValue, byCar: this.byCarLabelValue }))
  }

  #showChip(text, { clearAfterMs } = {}) {
    clearTimeout(this.chipTimer)
    this.routeChip?.remove()
    const chip = L.control({ position: "bottomleft" })
    chip.onAdd = () => {
      const el = L.DomUtil.create("div")
      el.className = "rounded-full bg-white/95 px-3 py-1 text-xs font-semibold text-gray-900 shadow dark:bg-gray-900/90 dark:text-gray-100"
      el.textContent = text
      return el
    }
    chip.addTo(this.map)
    this.routeChip = chip
    if (clearAfterMs) this.chipTimer = setTimeout(() => this.#clearChip(), clearAfterMs)
  }

  #clearChip() {
    this.routeChip?.remove()
    this.routeChip = null
  }


  toggleFullscreen() {
    // The button is in the markup before the panel that holds it is revealed.
    if (!this.map) return

    this.expanded = !this.expanded
    if (!this.expanded) this.closePanel()
    // Expanding is a request to see the place, not just more map.
    if (this.expanded && this.selectedId) this.#openPanel(this.selectedId)
    const style = this.containerTarget.style

    if (this.expanded) {
      Object.assign(style, { position: "fixed", inset: "0", width: "100%", height: "100%", zIndex: "9999", borderRadius: "0", margin: "0" })
      document.body.style.overflow = "hidden"
    } else {
      for (const prop of ["position", "inset", "width", "height", "zIndex", "borderRadius", "margin"]) style[prop] = ""
      document.body.style.overflow = ""
    }

    if (this.hasExpandIconTarget) this.expandIconTarget.classList.toggle("hidden", this.expanded)
    if (this.hasCollapseIconTarget) this.collapseIconTarget.classList.toggle("hidden", !this.expanded)

    requestAnimationFrame(() => this.map?.invalidateSize())
  }

  disconnect() {
    this.revealObserver?.disconnect()
    clearTimeout(this.chipTimer)
    this.#stopFollowing()
    document.removeEventListener("keydown", this.onKeydown)
    window.removeEventListener("resize", this.onResize)
    document.body.style.overflow = ""
    this.clusters?.clearLayers()
    this.clusters = null
    this.map?.remove()
    this.map = null
  }

  // Build the popup as a DOM node so the location name is never interpreted as
  // HTML (safe against markup in names).
  #popupFor(point) {
    const el = document.createElement(point.url ? "a" : "span")
    el.textContent = point.name
    el.className = "font-medium text-emerald-600"
    if (point.url) el.href = point.url
    return el
  }
}
