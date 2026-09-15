// Leaflet Service
// The only thing in the app that loads Leaflet. Leaflet is a UMD bundle that
// publishes window.L as a side effect of evaluating, so a controller importing
// it at module level pays for it on every page — Stimulus eager-loads every
// controller, and most pages draw no map. Every map is built through here, so
// the library arrives where one is actually drawn and the guarantee that it is
// there before L.map runs lives in one file rather than in each controller.

let loading = null

// Resolves to the library, or to null when it could not be fetched. Null rather
// than a rejection because a map that cannot load is a blank panel, not a broken
// page — the same contract the catalogue fetch uses.
export function loadLeaflet() {
  if (window.L) return Promise.resolve(window.L)
  if (loading) return loading

  loading = import("leaflet")
    .then(() => window.L)
    .catch(() => {
      // Losing the network once must not pin the failure for the session: the
      // next map to open tries again.
      loading = null
      return null
    })

  return loading
}
