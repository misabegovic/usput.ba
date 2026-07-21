import { Controller } from "@hotwired/stimulus"
import "leaflet"

// Educational minesweeper: the board is a geographic grid drawn on real map
// tiles, and the mine cells come from the server — cells that intersect
// recorded mine-suspected areas. Zoom and pan are free so players can study
// the terrain. There is no first-click protection: the data is what it is.
const FOG_STYLE = { color: "#065f46", weight: 1, fillColor: "#059669", fillOpacity: 0.8 }
const REVEALED_STYLE = { color: "#9ca3af", weight: 1, fillColor: "#ffffff", fillOpacity: 0.05 }
const MINE_STYLE = { color: "#7f1d1d", weight: 1, fillColor: "#dc2626", fillOpacity: 0.65 }
const NUMBER_COLORS = [
  "", "#1d4ed8", "#166534", "#b91c1c", "#3730a3", "#92400e", "#0f766e", "#111827", "#4b5563"
]

export default class extends Controller {
  static targets = ["map", "mines", "timer", "status", "fact"]
  static values = {
    rows: Number, cols: Number, south: Number, west: Number,
    dlat: Number, dlon: Number, mines: Array, labels: Object
  }

  connect() {
    this.initMap()
    this.newGame()
  }

  disconnect() {
    this.stopTimer()
    if (this.leaflet) this.leaflet.remove()
  }

  initMap() {
    const L = window.L
    this.leaflet = L.map(this.mapTarget, { attributionControl: true })
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 17,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.leaflet)
    this.boardBounds = [
      [this.southValue, this.westValue],
      [this.southValue + this.rowsValue * this.dlatValue, this.westValue + this.colsValue * this.dlonValue]
    ]
    this.leaflet.fitBounds(this.boardBounds, { padding: [20, 20] })
    this.cellLayer = L.layerGroup().addTo(this.leaflet)
    this.markLayer = L.layerGroup().addTo(this.leaflet)
  }

  newGame() {
    this.stopTimer()
    this.seconds = 0
    this.timerTarget.textContent = "0"
    this.statusTarget.textContent = ""
    if (this.hasFactTarget) {
      this.factTarget.textContent = ""
      this.factTarget.classList.add("hidden")
    }
    this.over = false
    this.started = false
    this.flagCount = 0
    this.revealedCount = 0
    this.mineSet = new Set(this.minesValue.map(([r, c]) => `${r},${c}`))
    this.updateMinesLeft()

    this.cellLayer.clearLayers()
    this.markLayer.clearLayers()
    this.grid = []
    for (let r = 0; r < this.rowsValue; r++) {
      const row = []
      for (let c = 0; c < this.colsValue; c++) {
        const rect = window.L.rectangle(this.cellBounds(r, c), FOG_STYLE)
        rect.on("click", () => this.reveal(r, c))
        rect.on("contextmenu", (e) => {
          window.L.DomEvent.stop(e)
          this.toggleFlag(r, c)
        })
        rect.addTo(this.cellLayer)
        row.push({ rect: rect, revealed: false, flagged: false, marker: null })
      }
      this.grid.push(row)
    }
  }

  cellBounds(r, c) {
    return [
      [this.southValue + r * this.dlatValue, this.westValue + c * this.dlonValue],
      [this.southValue + (r + 1) * this.dlatValue, this.westValue + (c + 1) * this.dlonValue]
    ]
  }

  cellCenter(r, c) {
    return [
      this.southValue + (r + 0.5) * this.dlatValue,
      this.westValue + (c + 0.5) * this.dlonValue
    ]
  }

  isMine(r, c) {
    return this.mineSet.has(`${r},${c}`)
  }

  adjacentMines(r, c) {
    let count = 0
    this.neighbors(r, c).forEach(([nr, nc]) => { if (this.isMine(nr, nc)) count++ })
    return count
  }

  reveal(r, c) {
    if (this.over) return
    const cell = this.grid[r][c]
    if (cell.revealed || cell.flagged) return
    if (!this.started) {
      this.started = true
      this.startTimer()
    }
    if (this.isMine(r, c)) {
      this.lose(r, c)
      return
    }
    const stack = [[r, c]]
    while (stack.length > 0) {
      const [cr, cc] = stack.pop()
      const current = this.grid[cr][cc]
      if (current.revealed || current.flagged) continue
      current.revealed = true
      this.revealedCount++
      current.rect.setStyle(REVEALED_STYLE)
      const n = this.adjacentMines(cr, cc)
      if (n > 0) {
        this.placeMark(cr, cc, `<span style="color:${NUMBER_COLORS[n]};font-weight:800;font-size:14px;text-shadow:0 0 3px #fff,0 0 3px #fff">${n}</span>`)
      } else {
        this.neighbors(cr, cc).forEach(([nr, nc]) => {
          if (!this.grid[nr][nc].revealed) stack.push([nr, nc])
        })
      }
    }
    if (this.revealedCount === this.rowsValue * this.colsValue - this.mineSet.size) {
      this.win()
    }
  }

  toggleFlag(r, c) {
    if (this.over) return
    const cell = this.grid[r][c]
    if (cell.revealed) return
    cell.flagged = !cell.flagged
    this.flagCount += cell.flagged ? 1 : -1
    if (cell.flagged) {
      cell.marker = this.placeMark(r, c, '<span style="font-size:14px">\u{1F6A9}</span>')
    } else if (cell.marker) {
      this.markLayer.removeLayer(cell.marker)
      cell.marker = null
    }
    this.updateMinesLeft()
  }

  placeMark(r, c, html) {
    const marker = window.L.marker(this.cellCenter(r, c), {
      interactive: false,
      icon: window.L.divIcon({ className: "", html: html, iconSize: [20, 20], iconAnchor: [10, 10] })
    })
    marker.addTo(this.markLayer)
    return marker
  }

  lose(hitR, hitC) {
    this.over = true
    this.stopTimer()
    this.mineSet.forEach((key) => {
      const [r, c] = key.split(",").map(Number)
      this.grid[r][c].rect.setStyle(MINE_STYLE)
      const symbol = r === hitR && c === hitC ? "\u{1F4A5}" : "\u{1F4A3}"
      this.placeMark(r, c, `<span style="font-size:14px">${symbol}</span>`)
    })
    this.statusTarget.textContent = this.labelsValue.lose
    this.showFact()
  }

  win() {
    this.over = true
    this.stopTimer()
    this.mineSet.forEach((key) => {
      const [r, c] = key.split(",").map(Number)
      const cell = this.grid[r][c]
      cell.rect.setStyle(MINE_STYLE)
      if (!cell.flagged) this.placeMark(r, c, '<span style="font-size:14px">\u{1F6A9}</span>')
    })
    this.flagCount = this.mineSet.size
    this.updateMinesLeft()
    this.statusTarget.textContent = this.labelsValue.win
    this.showFact()
  }

  // One real aggregate fact per finished game — numbers only.
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
    this.minesTarget.textContent = Math.max(0, this.mineSet.size - this.flagCount)
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
}
