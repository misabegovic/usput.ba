// localStorage and sessionStorage that cannot break a page. Some private-
// browsing modes and locked-down WebViews throw on any access, or on a write
// once the quota is full; then values live in memory for the visit instead,
// and are lost when the tab closes. Same three calls as window.localStorage.
function guarded(open) {
  const memory = new Map()

  const native = (() => {
    try {
      const store = open()
      const probe = "__usput_storage_probe__"
      store.setItem(probe, probe)
      store.removeItem(probe)
      return store
    } catch {
      return null
    }
  })()

  return {
    get persistent() {
      return native !== null
    },

    getItem(key) {
      if (native) {
        try {
          return native.getItem(key)
        } catch {
          // fall through to memory
        }
      }
      return memory.has(key) ? memory.get(key) : null
    },

    setItem(key, value) {
      const text = String(value)
      if (native) {
        try {
          native.setItem(key, text)
          return
        } catch {
          // quota or access refused: keep it for this visit
        }
      }
      memory.set(key, text)
    },

    removeItem(key) {
      memory.delete(key)
      if (native) {
        try {
          native.removeItem(key)
        } catch {
          // nothing to remove
        }
      }
    }
  }
}

export const storage = guarded(() => window.localStorage)
export const session = guarded(() => window.sessionStorage)
