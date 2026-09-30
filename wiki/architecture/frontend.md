---
title: Frontend
kind: reference
status: living
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
sources:
- config/importmap.rb
- app/javascript/controllers/index.js
- app/javascript/controllers/plan_deck_controller.js
- app/javascript/controllers/explore_geo_controller.js
- app/javascript/controllers/geo_visit_controller.js
- app/javascript/controllers/map_controller.js
- app/javascript/controllers/instant_moment_controller.js
- app/javascript/controllers/local_data_controller.js
- app/javascript/controllers/offline_banner_controller.js
- app/javascript/controllers/pwa_install_controller.js
- app/javascript/controllers/theme_controller.js
- app/javascript/controllers/mine_check_controller.js
- app/javascript/controllers/minesweeper_controller.js
- app/javascript/controllers/multi_photo_upload_controller.js
- app/javascript/services/leaflet_service.js
- app/javascript/services/position_service.js
- app/javascript/services/route_service.js
- app/javascript/services/travel_profile_service.js
- app/javascript/services/plan_sync_service.js
- app/controllers/concerns/records_visits.rb
- app/controllers/explore_bosnia_controller.rb
- app/controllers/map_routes_controller.rb
- app/services/camera_photo.rb
- app/services/guest_visits_importer.rb
- app/services/maps/ip_position.rb
- app/views/layouts/application.html.erb
- app/views/plans/_moment_instant_form.html.erb
- app/views/pwa/service-worker.js
- public/sw.js
- app/assets/stylesheets/application.tailwind.css
- config/routes.rb
- sources/planning/DEVELOPER_ONBOARDING.md
- sources/planning/TAILWIND_GUIDE.md
- https://github.com/misabegovic/usput.ba/pull/162
- https://github.com/misabegovic/usput.ba/pull/163
- https://github.com/misabegovic/usput.ba/pull/164
- https://github.com/misabegovic/usput.ba/pull/165
- https://github.com/misabegovic/usput.ba/pull/166
- https://github.com/misabegovic/usput.ba/pull/167
depends_on:
- architecture/overview.md
- architecture/conventions.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/architecture/overview.md
    - rel: depends-on
      to: wiki/architecture/conventions.md
---
# Frontend

The browser side is server-rendered ERB with Hotwire. Turbo handles
navigation and partial page updates, Stimulus controllers add behaviour,
and plain ES modules under `app/javascript/services/` hold logic that
several controllers must agree on. There is no bundler: `config/importmap.rb`
pins Turbo, Stimulus, Active Storage, every controller and service, and a
vendored Leaflet 1.9.4 with markercluster 1.5.3. Styling is Tailwind 4. The
September 2026 work (#162 to #167) rebuilt the traveller experience around
position, a map, and a deck of cards you walk through.

## Controllers and services

`app/javascript/controllers/index.js` eager-loads every controller on every
page (`eagerLoadControllersFrom`). There are 35 controller files. The main
groups:

- **Deck and walk:** `plan_deck`, `explore_geo`, `geo_visit`,
  `card_audio`, `card_menu`, `deck_filters`, `deck_pagination`.
- **Map:** `map`, `mine_check`, `minesweeper`.
- **Moments and photos:** `instant_moment`, `multi_photo_upload`,
  `photo_gallery`, `avatar_upload`.
- **Plans and profile:** `plan_wizard`, `plan_viewer`, `my_plans`,
  `add_to_plan`, `travel_profile`, `local_data`.
- **Shell:** `navigation`, `dropdown`, `flash`, `theme`, `cookie_consent`,
  `offline_banner`, `pwa_install`, `share`, `load_more`, `star_rating`.
- **Curator:** `curator_filters`, `curator_menu`.

The services each own one concern so no two screens can disagree (#162):

- `position_service.js` is the only code that calls
  `navigator.geolocation`. It asks once, publishes one reading to every
  subscriber, remembers the last position, refuses to let a fix whose error
  bar is wider than the 100 m check-in gate decide that gate, and treats a
  reading older than five minutes as stale when the traveller returns.
- `route_service.js` is the only code that measures distance, decides
  walking versus driving at `WALKING_LIMIT_KM = 5`, and asks the routing
  proxy for a line. Routes come from OpenRouteService through
  `MapRoutesController` (`GET /route`), so the API key stays on the server;
  the origin is rounded to about 110 m so nearby travellers share one cached
  route, timeouts are not cached, and lookups are limited to 30 a minute per
  address.
- `leaflet_service.js` is the only code that loads Leaflet (#167).
- `travel_profile_service.js` is the only owner of the device's travel
  profile in `localStorage`, keyed by a digest of the signed-in account so
  two people on one browser keep separate stores.
- `plan_sync_service.js` syncs plans between `localStorage` and
  `/user/plans/sync`. It still uses the storage keys `visitumo_plans` and
  `visitumo_active_plan`, an older product name.

## Lazy loading the map library (#167)

Leaflet is a UMD bundle that sets `window.L` when evaluated. Because Stimulus
eager-loads every controller, three controllers that imported Leaflet at the
top of the file made the home page, sign-in, sign-up and the profile each
load 147 KB for a map they never drew. Now `loadLeaflet()` in
`leaflet_service.js` imports it on first use and caches the promise.
`map_controller.js`, `mine_check_controller.js` and
`minesweeper_controller.js` call it when they build a map. If the import
fails it resolves to `null`, the panel stays blank rather than breaking the
page, and the next map to open tries again.

## The map (#163)

The location page carries a real map through `shared/_map_canvas`. It loads
the whole catalogue once as coordinates only (`GET
/locations/map_points`), caches it for the session stamped with the newest
content edit so a curator's change is picked up, and fetches one place's
card when a pin is tapped (`/locations/:id/map_panel`). Pins cluster until
zoom 13 (`CLUSTER_UNTIL_ZOOM`), then stand alone. Navigation is handed to
Google Maps. Since #167 a new place appears on the map without a reload.

## The card deck: explore and walk

One deck serves two surfaces, both driven by `plan_deck_controller.js`:

- **Walk a plan** (#164, `GET /plans/:id/start`). A plan's places stack as
  cards, nearest first. Each card carries the map, the audio tour and the
  check-in.
- **Explore Bosnia** (#165, `/explore-bosnia` and
  `/explore-bosnia/:category`). Explore opens straight into a deck of
  places instead of category tiles. Position orders the deck but does not
  bound it: a traveller anywhere is dealt the whole country, closest first.
  Paging walks a cursor of distance and id rather than an offset, because a
  check-in removes a place from the set and an offset would skip one
  (`ExploreBosniaController`). Categories combine, and a filter switched off
  stays off. Reached places drop out, and an empty deck says whether there
  is nothing here or you have been to all of it.

The deck keeps 15 cards behind the traveller (`KEEP_BEHIND`), re-deals only
when the traveller has moved at least 0.2 km (`MIN_REDEAL_KM`), and never
re-deals on its own. With no position yet, `explore_geo_controller.js` waits
up to 12 s for a first fix, then falls back; a traveller who never answers
the prompt gets a deck ordered from the city their IP suggests
(`Maps::IpPosition`).

**Check-in.** Server and browser ask one question: are you within 100 m?
The constant is `RecordsVisits::MAX_VISIT_DISTANCE_KM = 0.1`, and
`geo_visit_controller.js` receives the geofence from the server rather than
keeping its own. A hint under the button warms as the distance falls, and
its warmest band is the gate itself. Admins can check in from anywhere. #164
notes the distance is 100 m for testing and meant to drop to about 10 m.

**Guests** (#166). A visitor can explore, walk and check in without an
account; the walk lives on the device. Signing in or up replays it once
through `local_data_controller.js` and `GuestVisitsImporter` into ordinary
visit rows on the same find-or-create plan. The pull request notes that a
guest's check-in cannot be verified by the server: the 100 m gate ran in
the browser and the replay is trusted.

## Camera and photos

At a reached place a traveller captures a moment: a photo and a note,
private until published, and visible to others only after a curator
approves it (#164). The upload form (`plans/_moment_instant_form`) uses a
hidden `file_field` with `accept: "image/*"`, which lets a phone offer its
camera, and `instant_moment_controller.js` submits as soon as a file is
picked, with `requestSubmit` so Turbo replaces only that step. On the
server, `CameraPhoto.as_jpeg` converts HEIC and HEIF uploads to JPEG with
libvips before they are attached, because moments accept only JPEG, PNG,
GIF and WebP (#167). Moment photos are streamed by the app's own action
after a session check, never by a signed storage URL, and only in a fixed
list of sizes (#164). Curator photos are uploaded in the admin (Avo).

## PWA and offline

The app ships a manifest (`/manifest`, rendered from
`app/views/pwa/manifest.json.erb`, and a static `public/manifest.json`) and
registers a service worker from the layout. There are two service worker
files, and only one is live:

- `public/sw.js` (cache `usput-v3`) is the one the layout registers
  (`navigator.serviceWorker.register("/sw.js")` in
  `app/views/layouts/application.html.erb`). It precaches the home page,
  `offline.html`, the manifest and icons; uses network-first for pages with
  `offline.html` as the fallback, cache-first for assets and images,
  stale-while-revalidate for JSON, and network-only for audio, video, range
  requests and Active Storage; and skips cross-origin and `/admin` requests.
  Its background sync handler is a placeholder.
- `app/views/pwa/service-worker.js` (cache `web-cache-v2`, network-first
  for everything) is served at `/service-worker` by `config/routes.rb` but
  nothing registers it.

`offline_banner_controller.js` shows a banner with a link to the travel
profile when the browser goes offline. `pwa_install_controller.js` shows an
install prompt on mobile and a desktop note that the app exists on mobile.

## Design system notes

- `application.tailwind.css` defines the theme in an `@theme` block:
  a `primary` blue scale from `#e6f0ff` to `#000a1a` and an orange
  `accent` (`#f97316`, with light and dark variants), plus component
  classes. `sources/planning/TAILWIND_GUIDE.md` describes buttons, cards,
  badges, animations, glass effects and dark mode by class on `<html>`.
- `theme_controller.js` stores the light or dark choice in `localStorage`
  under `theme`; views pair every colour with a `dark:` variant.
- Many public and mine-safety components use Tailwind's emerald, amber and
  red scales directly rather than the `primary` tokens (for example the
  band styles in `mine_check_controller.js`), so the palette in the guide
  and the palette on screen differ (unverified, 2026-09-29, from a sample of
  views).
- `sources/planning/DEVELOPER_ONBOARDING.md` requires all JavaScript to be
  Stimulus: no inline handlers, no jQuery. The layout's service worker
  registration is an inline script with a CSP nonce, the one exception
  seen.
