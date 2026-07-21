import { Controller } from "@hotwired/stimulus"

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
  static targets = ["board", "mines", "timer", "status", "map"]
  static values = { rows: Number, cols: Number, mines: Number, labels: Object }

  connect() {
    this.newGame()
  }

  disconnect() {
    this.stopTimer()
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
    this.updateMinesLeft()
    this.buildBoard()
  }

  hideMap() {
    this.mapTarget.classList.add("hidden")
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
