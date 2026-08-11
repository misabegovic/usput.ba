// Route Service
// The only thing in the app that measures a distance, decides whether a place
// is walkable, or asks the routing proxy for a line. The map, the deck and the
// check-in all read from here, so a card and the map it opens can never
// disagree about how far away somewhere is or how you would get there.

const EARTH_RADIUS_KM = 6371

// Past this a route is asked for by car rather than on foot. One number, read
// by every surface — tuning it changes the profile and every label at once.
export const WALKING_LIMIT_KM = 5

export function distanceKm(lat1, lng1, lat2, lng2) {
  if (Number.isNaN(lat2) || Number.isNaN(lng2)) return Infinity

  const toRad = (deg) => (deg * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(a))
}

export function profileFor(km) {
  return km > WALKING_LIMIT_KM ? "driving-car" : "foot-walking"
}

// null on any refusal — a throttled or failed lookup leaves the caller showing
// whatever it had, rather than guessing a route.
export async function fetchRoute({ fromLat, fromLng, toLat, toLng, profile }) {
  const query = new URLSearchParams({ from_lat: fromLat, from_lng: fromLng, to_lat: toLat, to_lng: toLng, profile })

  try {
    const response = await fetch(`/route?${query}`, { headers: { Accept: "application/json" } })
    if (!response.ok) return null
    return await response.json()
  } catch {
    return null
  }
}

export function summarise(route, { byFoot, byCar }) {
  const km = (route.distance_m / 1000).toFixed(1)
  const min = Math.max(1, Math.round(route.duration_s / 60))
  return `${km} km · ${min} min · ${route.profile === "driving-car" ? byCar : byFoot}`
}
