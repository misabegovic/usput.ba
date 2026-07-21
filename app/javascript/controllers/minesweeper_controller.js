import { Controller } from "@hotwired/stimulus"
import "leaflet"

// Classic minesweeper over a map backdrop. Mine placement is random and
// fictional, generated in the browser per game — first click is always safe.
const HIDDEN_CLASSES =
  "aspect-square rounded-sm bg-emerald-700/90 hover:bg-emerald-600/90 border border-emerald-900/40 cursor-pointer select-none flex items-center justify-center text-xs sm:text-sm"
const REVEALED_CLASSES =
  "aspect-square rounded-sm bg-white/60 dark:bg-gray-900/50 border border-white/30 select-none flex items-center justify-center text-xs sm:text-sm font-bold"
const NUMBER_COLORS = [
  "", "text-blue-700", "text-green-800", "text-red-700", "text-indigo-800",
  "text-amber-800", "text-teal-800", "text-gray-900", "text-gray-600"
]

export default class extends Controller {
  static targets = ["board", "mines", "timer", "status", "map", "fact", "surroundings", "surroundingsMap"]
  static values = { rows: Number, cols: Number, mines: Number, labels: Object, lat: Number, lon: Number, zoom: Number, areasUrl: String }

  connect() {
    this.initBackdrop()
    this.newGame()
  }

  disconnect() {
    this.stopTimer()
    if (this.backdrop) this.backdrop.remove()
    if (this.surroundingsMapInstance) this.surroundingsMapInstance.remove()
  }

  // Educational context: a fully interactive map around the board location
  // with the REAL recorded-area overlay (boundaries zoomed in, dots zoomed
  // out) — so the fictional game sits next to the real picture.
  toggleSurroundings() {
    const panel = this.surroundingsTarget
    panel.classList.toggle("hidden")
    if (panel.classList.contains("hidden") || this.surroundingsMapInstance) return

    const L = window.L
    const map = L.map(this.surroundingsMapTarget).setView([this.latValue, this.lonValue], 12)
    this.surroundingsMapInstance = map
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 17,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(map)
    L.circleMarker([this.latValue, this.lonValue], { radius: 8, color: "#047857", weight: 3 }).addTo(map)
    this.surroundingsAreas = L.geoJSON(null, {
      style: { color: "#b91c1c", weight: 1, fillColor: "#dc2626", fillOpacity: 0.35 },
      pointToLayer: (feature, latlng) => L.circleMarker(latlng, {
        radius: 3, color: "#b91c1c", weight: 1, fillColor: "#dc2626", fillOpacity: 0.7
      })
    }).addTo(map)
    map.on("moveend", () => this.loadSurroundingAreas())
    this.loadSurroundingAreas()
  }

  async loadSurroundingAreas() {
    if (!this.hasAreasUrlValue || !this.surroundingsMapInstance) return
    const map = this.surroundingsMapInstance
    try {
      let url
      if (map.getZoom() < 9) {
        url = `${this.areasUrlValue}?overview=1`
      } else {
        const b = map.getBounds()
        const params = new URLSearchParams({
          west: b.getWest().toFixed(3), south: b.getSouth().toFixed(3),
          east: b.getEast().toFixed(3), north: b.getNorth().toFixed(3)
        })
        url = `${this.areasUrlValue}?${params}`
      }
      const response = await fetch(url)
      if (!response.ok) return
      const data = await response.json()
      this.surroundingsAreas.clearLayers()
      this.surroundingsAreas.addData(data)
    } catch {
      // best-effort overlay
    }
  }

  // Non-interactive OSM backdrop — purely scenery behind the fictional board.
  initBackdrop() {
    if (!this.hasMapTarget || !window.L) return
    this.backdrop = window.L.map(this.mapTarget, {
      center: [this.latValue, this.lonValue],
      zoom: this.zoomValue,
      zoomControl: false, dragging: false, scrollWheelZoom: false,
      doubleClickZoom: false, boxZoom: false, keyboard: false,
      touchZoom: false, attributionControl: true
    })
    window.L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 17,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.backdrop)
  }

  newGame() {
    this.stopTimer()
    this.seconds = 0
    this.placed = false
    this.over = false
    this.flagCount = 0
    this.revealedCount = 0
    this.grid = []
    this.timerTarget.textContent = "0"
    this.statusTarget.textContent = ""
    if (this.hasFactTarget) {
      this.factTarget.textContent = ""
      this.factTarget.classList.add("hidden")
    }
    this.updateMinesLeft()
    this.buildBoard()
  }

  buildBoard() {
    const board = this.boardTarget
    board.innerHTML = ""
    board.style.gridTemplateColumns = `repeat(${this.colsValue}, minmax(0, 1fr))`
    for (let r = 0; r < this.rowsValue; r++) {
      const row = []
      for (let c = 0; c < this.colsValue; c++) {
        const cell = { mine: false, revealed: false, flagged: false, count: 0 }
        const btn = document.createElement("button")
        btn.type = "button"
        btn.className = HIDDEN_CLASSES
        btn.addEventListener("click", () => this.onCellClick(r, c))
        btn.addEventListener("contextmenu", (e) => {
          e.preventDefault()
          this.toggleFlag(r, c)
        })
        btn.addEventListener("touchstart", () => this.startLongPress(r, c), { passive: true })
        btn.addEventListener("touchend", () => this.cancelLongPress())
        btn.addEventListener("touchmove", () => this.cancelLongPress())
        cell.el = btn
        row.push(cell)
        board.appendChild(btn)
      }
      this.grid.push(row)
    }
  }

  startLongPress(r, c) {
    this.longPressed = false
    this.pressTimer = setTimeout(() => {
      this.longPressed = true
      this.toggleFlag(r, c)
    }, 400)
  }

  cancelLongPress() {
    clearTimeout(this.pressTimer)
  }

  onCellClick(r, c) {
    if (this.longPressed) {
      this.longPressed = false
      return
    }
    this.reveal(r, c)
  }

  placeMines(safeR, safeC) {
    let placed = 0
    while (placed < this.minesValue) {
      const r = Math.floor(Math.random() * this.rowsValue)
      const c = Math.floor(Math.random() * this.colsValue)
      const cell = this.grid[r][c]
      if (cell.mine) continue
      if (Math.abs(r - safeR) <= 1 && Math.abs(c - safeC) <= 1) continue
      cell.mine = true
      placed++
    }
    this.eachCell((cell, r, c) => {
      cell.count = this.neighbors(r, c).filter(([nr, nc]) => this.grid[nr][nc].mine).length
    })
  }

  reveal(r, c) {
    if (this.over) return
    const cell = this.grid[r][c]
    if (cell.revealed || cell.flagged) return
    if (!this.placed) {
      this.placeMines(r, c)
      this.placed = true
      this.startTimer()
    }
    if (cell.mine) {
      this.lose(cell)
      return
    }
    const stack = [[r, c]]
    while (stack.length > 0) {
      const [cr, cc] = stack.pop()
      const current = this.grid[cr][cc]
      if (current.revealed || current.flagged) continue
      current.revealed = true
      this.revealedCount++
      this.renderRevealed(current)
      if (current.count === 0) {
        this.neighbors(cr, cc).forEach(([nr, nc]) => {
          if (!this.grid[nr][nc].revealed) stack.push([nr, nc])
        })
      }
    }
    if (this.revealedCount === this.rowsValue * this.colsValue - this.minesValue) {
      this.win()
    }
  }

  toggleFlag(r, c) {
    if (this.over) return
    const cell = this.grid[r][c]
    if (cell.revealed) return
    cell.flagged = !cell.flagged
    this.flagCount += cell.flagged ? 1 : -1
    cell.el.textContent = cell.flagged ? "\u{1F6A9}" : ""
    this.updateMinesLeft()
  }

  renderRevealed(cell) {
    cell.el.className = REVEALED_CLASSES
    if (cell.count > 0) {
      cell.el.textContent = cell.count
      cell.el.classList.add(NUMBER_COLORS[cell.count])
    } else {
      cell.el.textContent = ""
    }
  }

  lose(hitCell) {
    this.over = true
    this.stopTimer()
    this.eachCell((cell) => {
      if (!cell.mine) return
      cell.el.className = REVEALED_CLASSES
      cell.el.classList.add("bg-red-200/80", "dark:bg-red-900/60")
      cell.el.textContent = cell === hitCell ? "\u{1F4A5}" : "\u{1F4A3}"
    })
    this.statusTarget.textContent = this.labelsValue.lose
    this.showFact()
  }

  win() {
    this.over = true
    this.stopTimer()
    this.eachCell((cell) => {
      if (cell.mine && !cell.flagged) cell.el.textContent = "\u{1F6A9}"
    })
    this.flagCount = this.minesValue
    this.updateMinesLeft()
    this.statusTarget.textContent = this.labelsValue.win
    this.showFact()
  }

  // One real aggregate fact per finished game — numbers only, no geometry.
  showFact() {
    const facts = this.labelsValue.facts
    if (!this.hasFactTarget || !facts || facts.length === 0) return
    this.factIndex = ((this.factIndex ?? Math.floor(Math.random() * facts.length)) + 1) % facts.length
    this.factTarget.textContent = facts[this.factIndex]
    this.factTarget.classList.remove("hidden")
  }

  startTimer() {
    this.timerInterval = setInterval(() => {
      this.seconds++
      this.timerTarget.textContent = this.seconds
    }, 1000)
  }

  stopTimer() {
    if (this.timerInterval) clearInterval(this.timerInterval)
    this.timerInterval = null
  }

  updateMinesLeft() {
    this.minesTarget.textContent = Math.max(0, this.minesValue - this.flagCount)
  }

  neighbors(r, c) {
    const result = []
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) continue
        const nr = r + dr
        const nc = c + dc
        if (nr >= 0 && nr < this.rowsValue && nc >= 0 && nc < this.colsValue) {
          result.push([nr, nc])
        }
      }
    }
    return result
  }

  eachCell(fn) {
    for (let r = 0; r < this.rowsValue; r++) {
      for (let c = 0; c < this.colsValue; c++) {
        fn(this.grid[r][c], r, c)
      }
    }
  }
}
