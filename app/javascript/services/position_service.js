// Position Service
// The only thing in the app that talks to navigator.geolocation. It asks once,
// publishes one reading, and asks again only when the traveller says so — so
// the deck, the map and the check-in all quote the same position, and none of
// them re-orders itself under the traveller while they are reading it.

const STORAGE_KEY = "usput-last-position"
const COARSE_TIMEOUT_MS = 8000
// A laptop has no GPS, so every fix is a network lookup. Reusing one the device
// already holds is the difference between instant and a round-trip.
const MAX_REUSE_MS = 60000
// The check-in gate is 100 m, so a fix whose own error bar is wider than that
// cannot decide it. A laptop reports wifi fixes in the hundreds or thousands.
const GATE_ACCURACY_M = 100
// Only long enough to bridge a provider stall, never long enough to be a
// different place: the explore deck freezes whatever it is first handed.
const REMEMBERED_MAX_AGE_MS = 120000
const ACQUIRE_TIMEOUT_MS = 10000
// Past this, a held reading is treated as a guess about a place the traveller
// may have left. Short enough that reopening the app in another town re-asks,
// long enough that flicking away and back does not.
const STALE_MS = 300000

export class PositionService {
  constructor() {
    this.subscribers = new Set()
    this.failureSubscribers = new Set()
    this.#restore()
    this.#useDevPosition()
    this.#refreshOnReturn()
  }

  // Coming back to the app is when a held reading is most likely to be wrong:
  // it may have been closed in one town and reopened in another three hours
  // later. Both events are needed — a phone returning from the background often
  // restores the page from cache without re-running anything, which fires
  // pageshow and not visibilitychange.
  #refreshOnReturn() {
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) this.refreshIfStale()
    })
    window.addEventListener("pageshow", (event) => {
      if (event.persisted) this.refreshIfStale()
    })
  }

  // Silent when nothing has changed: a fresh reading republishes the same
  // coordinates and every surface re-renders to the same numbers.
  refreshIfStale() {
    if (!this.asked || this.pinned) return
    if (this.fixedAt && Date.now() - this.fixedAt < STALE_MS) return

    this.refresh()
  }

  // Coarse always: it says where the device was, so it can never decide a gate.
  // Its age is not judged here — this runs once, at import, and the service
  // outlives every Turbo navigation, so a fix restored as recent would still be
  // reported as recent an hour later.
  #restore() {
    const held = this.stored()
    if (!held) return

    // Orients even without an age — a store written before ages were kept still
    // says where the device was, and current() never decides anything.
    this.last = held
    if (!held.at) return

    this.fixedAt = held.at
    this.coarse = true
    this.remembered = true
  }

  #useDevPosition() {
    const value = document.querySelector('meta[name="dev-position"]')?.content
    if (!value) return

    const [ latitude, longitude ] = value.split(",").map(Number)
    if (!isFinite(latitude) || !isFinite(longitude)) return

    this.pinned = true
    this.publish({ coords: { latitude, longitude, accuracy: 5 }, timestamp: Date.now() })
  }

  failure() {
    return this.lastFailure || null
  }

  // The freshest fix we hold, or the one this device ended on last time. Good
  // enough to order a deck or place a marker.
  current() {
    return this.last
  }

  // One status, derived when it is asked. Every surface reads this rather than
  // assembling its own rule from the flags underneath, which is what let the
  // deck, the map and the check-in disagree about whether a position was held.
  status() {
    if (!this.#usable()) {
      if (this.lastFailure) {
        return this.lastFailure.code === this.lastFailure.PERMISSION_DENIED ? "denied" : "unavailable"
      }
      return this.acquiring ? "locating" : "unknown"
    }
    return this.coarse ? "coarse" : "precise"
  }

  // A remembered fix expires while the tab stays open, so its age is measured
  // now rather than at construction.
  #usable() {
    if (!this.fixedAt) return false
    if (!this.remembered) return true
    return Date.now() - this.fixedAt <= REMEMBERED_MAX_AGE_MS
  }

  // Measured this session, or remembered recently. Orients; never gates.
  measured() {
    return this.#usable() ? this.last : null
  }

  // Measured, recent, and accurate enough to decide the gate on its own.
  fresh(maxAgeMs = 15000) {
    if (!this.#usable() || this.coarse) return null
    return Date.now() - this.fixedAt <= maxAgeMs ? this.last : null
  }

  // Recent, at whatever accuracy it came with — the reading carries its own
  // error bar, so a caller can widen its gate instead of refusing. Refusing
  // outright is what left a laptop, and a position set in developer tools,
  // unable to check in anywhere at all.
  recent(maxAgeMs = 15000) {
    if (!this.#usable()) return null
    return Date.now() - this.fixedAt <= maxAgeMs ? this.last : null
  }

  // A device that is not moving reports once and then stays silent, so the fix
  // it gave only ages. Refusing it leaves a traveller standing at the place
  // with nothing to press; asking for a new one is the way out. maximumAge is
  // zero deliberately — a cached reading is precisely what already aged out.
  // Low accuracy first, and a short deadline. This is the shape the branches
  // where check-in always worked used, and the reason is the platform rather
  // than the product: a high-accuracy request waits on a satellite lock that a
  // desktop never gets and a phone indoors may take a minute to get, while the
  // network lookup beside it answers in about a second. Accuracy no longer
  // decides whether a reading is usable — it only widens the gate — so the fast
  // answer is the right one to ask for, and the precise one is an upgrade that
  // is allowed to fail.
  acquire(maxAgeMs = 15000) {
    const held = this.recent(maxAgeMs)
    if (held) return Promise.resolve(held)
    if (!navigator.geolocation) return Promise.resolve(null)

    return this.#ask({ enableHighAccuracy: false, timeout: COARSE_TIMEOUT_MS, maximumAge: MAX_REUSE_MS })
      .then((position) => position || this.#ask({ enableHighAccuracy: true, timeout: ACQUIRE_TIMEOUT_MS, maximumAge: MAX_REUSE_MS }))
      .then(() => this.last || null)
  }

  // Resolves rather than rejects, and always resolves: some providers answer
  // neither callback, and the deadline in the options is only honoured by an
  // implementation still willing to run.
  // Looks without telling anyone. A prompt that asks the traveller whether they
  // have moved has to know the answer first, and publishing here would re-deal
  // the deck underneath them — which is the thing they were going to be asked
  // about. Cheap and reusable on purpose: it costs no routing request and is
  // allowed to hand back a reading the device already had.
  peek() {
    if (!navigator.geolocation) return Promise.resolve(null)

    return new Promise((resolve) => {
      const deadline = setTimeout(() => resolve(null), COARSE_TIMEOUT_MS + 1000)
      const done = (value) => { clearTimeout(deadline); resolve(value) }

      navigator.geolocation.getCurrentPosition(
        (position) => done({ latitude: position.coords.latitude, longitude: position.coords.longitude }),
        () => done(null),
        { enableHighAccuracy: false, timeout: COARSE_TIMEOUT_MS, maximumAge: MAX_REUSE_MS }
      )
    })
  }

  #ask(options) {
    this.acquiring = true
    return new Promise((resolve) => {
      const done = (value) => { clearTimeout(deadline); this.acquiring = false; resolve(value) }
      const deadline = setTimeout(() => done(null), (options.timeout || ACQUIRE_TIMEOUT_MS) + 1000)

      navigator.geolocation.getCurrentPosition(
        (position) => { this.publish(position); done(position) },
        (error) => { this.reportFailure(error); done(null) },
        options
      )
    })
  }

  // Returns an unsubscribe. The first subscriber triggers the one ask.
  subscribe(callback, onFailure) {
    this.subscribers.add(callback)
    if (onFailure) this.failureSubscribers.add(onFailure)
    const held = this.measured()
    if (held) callback(held)
    // start() will not re-ask a device that already failed.
    else if (this.lastFailure && onFailure) onFailure(this.lastFailure)
    this.start()

    return () => {
      this.subscribers.delete(callback)
      if (onFailure) this.failureSubscribers.delete(onFailure)
      if (this.subscribers.size === 0) this.stop()
    }
  }

  // One position, asked for once. A watcher only reports when the traveller
  // moves, which is what left someone standing still holding a reading that
  // could only age, and it re-ordered the deck under them as they read it. A
  // new position is asked for by the traveller — refresh(), below.
  start() {
    if (this.pinned || this.asked || !navigator.geolocation) return

    this.asked = true
    this.refresh()
  }

  // The explicit update. Always acquires: the whole point of pressing it is
  // that the held reading is the one the traveller has judged out of date.
  refresh() {
    this.asked = true
    if (!navigator.geolocation) return Promise.resolve(null)

    // maximumAge zero: the point of asking again is that what we hold is the
    // thing in doubt. A failure keeps the old reading rather than clearing it —
    // stale beats nothing.
    return this.#ask({ enableHighAccuracy: false, timeout: COARSE_TIMEOUT_MS, maximumAge: 0 })
      .then((position) => position || this.#ask({ enableHighAccuracy: true, timeout: ACQUIRE_TIMEOUT_MS, maximumAge: 0 }))
      .then(() => this.last || null)
  }


  reportFailure(error) {
    if (error.code === error.PERMISSION_DENIED) this.clear()
    // Only a total absence of position is worth telling a surface about. The
    // accurate watcher timing out while the coarse seed already landed is the
    // expected case indoors, not a failure the traveller needs to see. Asked of
    // what is usable now: a remembered fix that has since expired suppressed
    // every failure behind it, leaving the deck waiting on a card that could
    // not explain itself.
    if (this.#usable()) return
    this.announceFailure(error)
  }

  announceFailure(error) {
    this.lastFailure = error
    this.failureSubscribers.forEach((callback) => callback(error))
  }

  // Nothing runs between asks, so there is nothing to tear down. Kept because
  // subscribe() hands back an unsubscribe and callers still release it.
  stop() {}

  clear() {}

  // Stamped when we received it, not by the device's clock. Taking the device
  // timestamp was meant to stop a reused fix looking recent, and it made every
  // reading on a skewed clock look ancient instead — which is the same refusal,
  // reached by a worse route. Reuse is handled where it belongs: acquire() asks
  // with maximumAge zero, so nothing cached reaches here unannounced.
  publish({ coords: { latitude, longitude, accuracy } }, { coarse = false } = {}) {
    this.last = { latitude, longitude, accuracy }
    this.fixedAt = Date.now()
    // The reading decides this, not the caller. The high-accuracy watcher
    // returns wifi-grade fixes on a laptop too, and a caller publishing one as
    // fine relabelled it for every surface that asks.
    this.coarse = coarse || !(accuracy <= GATE_ACCURACY_M)
    this.remembered = false
    this.lastFailure = null
    this.persist()
    this.subscribers.forEach((callback) => callback(this.last))
  }

  persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...this.last, at: this.fixedAt }))
    } catch {
      // A full or blocked store is not worth failing a walk over.
    }
  }

  stored() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      const parsed = raw ? JSON.parse(raw) : null
      return parsed?.latitude && parsed?.longitude ? parsed : null
    } catch {
      return null
    }
  }
}

export const positionService = new PositionService()
