---
title: Feature inventory
kind: reference
status: living
updated: 2026-10-08
repos:
- usput.ba
confidence: medium
sources:
- config/routes.rb
- README.md
- app/controllers/new_design_controller.rb
- app/controllers/explore_bosnia_controller.rb
- app/controllers/plans_controller.rb
- app/controllers/plans/visits_controller.rb
- app/controllers/moments_controller.rb
- app/controllers/locations_controller.rb
- app/controllers/map_routes_controller.rb
- app/controllers/reviews_controller.rb
- app/controllers/user_plans_controller.rb
- app/controllers/travel_profiles_controller.rb
- app/controllers/mine_check_public_controller.rb
- app/controllers/minesweeper_controller.rb
- app/controllers/concerns/records_visits.rb
- app/controllers/curator/locations_controller.rb
- app/controllers/curator/moments_controller.rb
- app/models/browse.rb
- app/models/location.rb
- app/models/audio_tour.rb
- app/models/review.rb
- app/services/ai/audio_tour_generator.rb
- app/services/guest_visits_importer.rb
- app/views/layouts/application.html.erb
- public/sw.js
- config/application.rb
- docs/mine_checker/README.md
- sources/planning/REVIEW_APPROVAL_SYSTEM.md
- https://github.com/misabegovic/usput.ba/pull/124
- https://github.com/misabegovic/usput.ba/pull/138
- https://github.com/misabegovic/usput.ba/pull/141
- https://github.com/misabegovic/usput.ba/pull/143
- https://github.com/misabegovic/usput.ba/pull/147
- https://github.com/misabegovic/usput.ba/pull/149
- https://github.com/misabegovic/usput.ba/pull/152
- https://github.com/misabegovic/usput.ba/pull/154
- https://github.com/misabegovic/usput.ba/pull/157
- https://github.com/misabegovic/usput.ba/pull/161
- https://github.com/misabegovic/usput.ba/pull/162
- https://github.com/misabegovic/usput.ba/pull/163
- https://github.com/misabegovic/usput.ba/pull/164
- https://github.com/misabegovic/usput.ba/pull/165
- https://github.com/misabegovic/usput.ba/pull/166
- https://github.com/misabegovic/usput.ba/pull/167
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
---
# Feature inventory

This is what Usput.ba ships as of 2026-09-29, grouped by what a person does with it. It reads the code on the `usput-brain` branch, whose HEAD (`abf62b0`) is `origin/main` plus the accessibility work merged from #154. Git history in this repository starts at 2026-01-15 (commit `2f008b1`, #123), so a feature marked "before 2026-01-15" existed in that first commit and its real landing date is unknown. For the roles named here see [personas](personas.md); for the entities see [domain](domain.md).

## Timeline at a glance

| Date | Change | PR |
|------|--------|----|
| before 2026-01-15 | Locations, experiences, plans, plan wizard, reviews, audio tours, Browse search, curator proposals, photo suggestions, curator applications, PWA | (history starts at #123) |
| 2026-01-16 | Platform DSL, CLI and Knowledge Layer (phases 1 to 17) | [#124](https://github.com/misabegovic/usput.ba/pull/124) |
| 2026-01-19 | Experience types classification and plan filtering | [#138](https://github.com/misabegovic/usput.ba/pull/138) |
| 2026-01-21 | DSL content validation against hallucinated places | [#141](https://github.com/misabegovic/usput.ba/pull/141) |
| 2026-01-22 | Several photos per photo suggestion | [#143](https://github.com/misabegovic/usput.ba/pull/143) |
| 2026-02-04 | Curator dashboard redesign; edit and delete behind a flag | [#147](https://github.com/misabegovic/usput.ba/pull/147), [#149](https://github.com/misabegovic/usput.ba/pull/149) |
| 2026-07-21 | Mine Checker and the Minolovac game | [#157](https://github.com/misabegovic/usput.ba/pull/157) |
| 2026-09-15 | Check-ins, moments and plan stops as tables | [#161](https://github.com/misabegovic/usput.ba/pull/161) |
| 2026-09-15 | Position and route services | [#162](https://github.com/misabegovic/usput.ba/pull/162) |
| 2026-09-15 | Location map | [#163](https://github.com/misabegovic/usput.ba/pull/163) |
| 2026-09-15 | Walk a plan, check in, capture a moment | [#164](https://github.com/misabegovic/usput.ba/pull/164) |
| 2026-09-15 | Explore Bosnia deck | [#165](https://github.com/misabegovic/usput.ba/pull/165) |
| 2026-09-15 | Guest explore and check-in, replayed at sign-in | [#166](https://github.com/misabegovic/usput.ba/pull/166) |
| 2026-09-15 | Archiving places, moments view, likes, moment links | [#167](https://github.com/misabegovic/usput.ba/pull/167) |
| 2026-09-29 | Location accessibility merged onto main's work | [#154](https://github.com/misabegovic/usput.ba/pull/154) |
| 2026-09-30 | Accounts through Devise: email sign-in, confirmation, reset, ending sessions | [#171](https://github.com/misabegovic/usput.ba/pull/171), [#172](https://github.com/misabegovic/usput.ba/pull/172) |
| 2026-09-30 | Sign in with Google | [#173](https://github.com/misabegovic/usput.ba/pull/173) |

## Accounts

- **Sign-in by email.** Accounts use Devise: a traveller registers with a username, an email and a password, and signs in with the email. A new account works at once and must confirm its email within three days to keep signing in. A forgotten password is reset by email; asking never reveals whether an address has an account ([decision](../decisions/accounts-through-devise.md); `app/models/user.rb`, `app/controllers/users/`).
- **Account page.** `/account/edit` changes the username, email and password with the current password. A new email only takes effect once confirmed, and both the old address and the account holder are told when an email or password changes (`app/views/users/registrations/edit.html.erb`).
- **Ending sessions.** One button signs the traveller out of every other browser. A password change or reset does the same, and a blocked account is signed out on its next request. All of them rotate one per-user token that Devise checks on every request (`User#authenticatable_salt`, `User#end_sessions`, `User#block!`).
- **Google sign-in.** "Continue with Google" on the sign-in and registration pages links a Google account to the usput account with the same verified email, or creates a confirmed one. An email Google has not verified links to nothing, and the guest walk comes along ([decision](../decisions/accounts-through-devise.md); `app/services/google_account.rb`).
- **Limits and mail.** Sign-in, registration, reset and confirmation requests are rate limited in Solid Cache. Mail is sent from jobs in the visitor's language, through Postmark in production and to `/letter_opener` in development.

## Explore and search

- **Home page.** Shows positive reviews (rating 3 or more), the newest approved public moments, and trending locations and experiences with a rating of at least 3.5 (`app/controllers/new_design_controller.rb`, `home`).
- **Explore.** `/explore` searches one index, `Browse`, across locations, experiences, public plans and approved public moments. Filters: type, city, budget, minimum rating, season, duration, tag, AI or human origin, audio support, accessibility and a nearby radius, with a sort order. Results page with load-more. A search that matches a single place expands to nearby items (`new_design_controller.rb`, `explore`, `build_browse_queries`; `app/models/browse.rb`). The most liked moments rank first ([#167](https://github.com/misabegovic/usput.ba/pull/167)).
- **Explore Bosnia deck.** `/explore-bosnia` deals places as a deck of cards, nearest first. Position orders the deck but does not bound it, so a traveller anywhere gets the whole country. Paging uses a keyset cursor because a check-in removes a place from the set. Categories combine, and a filter turned off stays off. Places already reached drop out, and an empty deck says whether nothing is here or everything has been visited. Without a browser location the deck is ordered from the city the request's IP suggests ([#165](https://github.com/misabegovic/usput.ba/pull/165); `app/controllers/explore_bosnia_controller.rb`).
- **Retired places stay hidden.** An archived location leaves Browse and the traveller-facing scopes ([#167](https://github.com/misabegovic/usput.ba/pull/167); `app/models/location.rb`, `places`).

## Plans and the plan wizard

- **Plan wizard.** `/plans/wizard` (optionally for a city) finds the nearest city from coordinates or by name, then `POST /plans/generate` builds a plan without saving it, from the city, duration, budget, a `meat_lover` flag, interests and an accessibility requirement. It falls back to no filters when nothing matches. The generated plan lives in localStorage and `/plans/view` renders it client-side. `/plans/recommendations` suggests experiences, standalone locations and popular plans for the city (`app/controllers/plans_controller.rb`). Present before 2026-01-15; experience-type filtering landed in [#138](https://github.com/misabegovic/usput.ba/pull/138).
- **Saved plans.** A signed-in traveller syncs plans from the device, creates, edits and deletes them, shares one publicly and toggles visibility (`app/controllers/user_plans_controller.rb`).
- **Plan stops.** A plan holds experiences and standalone locations per day, ordered by position ([#161](https://github.com/misabegovic/usput.ba/pull/161)).

## Walking a plan: check-ins and moments

- **Walk.** `/plans/:id/start` walks a plan as a stack of cards, nearest first. Each card carries a map, the audio tour and the check-in ([#164](https://github.com/misabegovic/usput.ba/pull/164)).
- **Check-in.** Browser and server ask the same question: is the traveller within 100 m? The distance is one constant, `MAX_VISIT_DISTANCE_KM`, used by every surface (`app/controllers/concerns/records_visits.rb`). A warm and cold hint under the button tracks the distance. Admins check in from anywhere. The PR notes that 100 m is a testing value meant to drop to about 10 m ([#164](https://github.com/misabegovic/usput.ba/pull/164)).
- **Guest walk.** A visitor explores, walks and checks in without an account. The walk stays on the device and is replayed into ordinary rows once, at sign-in or sign-up. The replay cannot be re-verified on the server: the 100 m gate ran in the browser ([#166](https://github.com/misabegovic/usput.ba/pull/166); `app/services/guest_visits_importer.rb`, `MAX_VISITS = 500`).
- **Moments.** At a place already reached, a traveller captures a photo and a note. A moment is private; publishing sends it to a curator, and only an approved public moment is visible to others or searchable. Photos are served by the app's own action after a session check, never by a signed storage URL ([#164](https://github.com/misabegovic/usput.ba/pull/164)). Photos can be taken in the app, and iPhone photos are converted before upload ([#167](https://github.com/misabegovic/usput.ba/pull/167)).
- **Moments view and likes.** A moment opens in a full view with who took it, where, the note, a download and a like. A like is its own record and needs a login. Each moment has its own URL (`/moments/:id`) with a link preview. A place's page has a shelf of its moments, loaded as the traveller scrolls ([#167](https://github.com/misabegovic/usput.ba/pull/167); `config/routes.rb`).
- **Travel profile.** `/profile` shows plans, moments and visited places. Visited places and counts come from check-in rows, not from the device copy (`app/controllers/travel_profiles_controller.rb`).

## Maps and routing

- **Location map.** The location page carries a map of the whole catalogue, loaded once as coordinates only and cached in the browser, stamped with the newest content edit. Pins cluster until a town fits on screen. Tapping a pin opens that place's card beside the map; navigation is handed to Google ([#163](https://github.com/misabegovic/usput.ba/pull/163); `app/controllers/locations_controller.rb`, `map_points`, `map_panel`).
- **Position and routes.** One browser service asks for the location once and shares the reading. One service measures distance and switches from walking to driving at 5 km. Routes come from OpenRouteService through `/route`, so the key stays on the server. The origin is rounded to about 110 m for caching, timeouts are not cached, and lookups are limited to 30 a minute per address ([#162](https://github.com/misabegovic/usput.ba/pull/162); `app/controllers/map_routes_controller.rb`).
- The map library loads only on pages that draw a map ([#167](https://github.com/misabegovic/usput.ba/pull/167)).

## Audio tours

Narrated tours per location and language, played on the location page, the walk card and the deck card (`config/routes.rb`, `locations#audio_tour`; [#164](https://github.com/misabegovic/usput.ba/pull/164), [#165](https://github.com/misabegovic/usput.ba/pull/165)). An AI writes the script and text-to-speech renders it, by default ElevenLabs (`app/services/ai/audio_tour_generator.rb`). Curators manage tours through proposals. Present before 2026-01-15.

## Reviews

Anyone can rate a location, experience or plan from 1 to 5 with an optional comment and name; no login is required and there is no moderation (`app/controllers/reviews_controller.rb`; `app/models/review.rb`). Reviews stream back in place on deck cards ([#165](https://github.com/misabegovic/usput.ba/pull/165)). A curator can propose deleting a review (`app/controllers/curator/reviews_controller.rb`). Login-required, moderated reviews are planned, not built ([#152](https://github.com/misabegovic/usput.ba/pull/152); `sources/planning/REVIEW_APPROVAL_SYSTEM.md`).

## Curator dashboard and moderation

- **Dashboard.** `/curator` shows counts, review and audio coverage statistics, recent items and recent curator activity (`app/controllers/curator/dashboard_controller.rb`). Card layout, load-more and dark mode arrived in [#147](https://github.com/misabegovic/usput.ba/pull/147).
- **Direct editing.** Curators create and edit places, experiences, plans and audio tours in the admin at `/admin`; only admins delete. The proposals that admins approved or rejected, present before 2026-01-15, were removed on 2026-09-30.
- **Photos** are uploaded on the place in the admin at `/admin`, where a filter lists places with no photos or fewer than three; the photo suggestions of [#143](https://github.com/misabegovic/usput.ba/pull/143) were removed on 2026-09-30. The curator start page's "needs photos" button opens that filter.
- **Moment moderation queue** with pending, approved and rejected counts ([#164](https://github.com/misabegovic/usput.ba/pull/164); `app/controllers/curator/moments_controller.rb`). It is linked from the mobile menu since [#167](https://github.com/misabegovic/usput.ba/pull/167).
- **Archiving.** A place is archived instead of deleted, so check-ins and moments survive, and it can be restored. Delete states what it would cost first. Archiving is recorded in the curator activity trail ([#167](https://github.com/misabegovic/usput.ba/pull/167)).
- **Admin tools.** Manage and unblock users (`config/routes.rb`, `curator/admin`); remove a review from the reviews list. Curator applications were removed on 2026-09-30; roles change in the new admin at `/admin`.

## Accessibility

A location records wheelchair access (full, partial, none, unknown), five features and notes, and its page shows an accessibility card before the map. Explore has an accessible filter, and the plan wizard can require accessible places, which must also not be archived. Moments pass the accessible filter when their place does ([#154](https://github.com/misabegovic/usput.ba/pull/154), merged as `d3be6c5` and followed by `abf62b0`, both merged through [#168](https://github.com/misabegovic/usput.ba/pull/168) as `7955ae9` on 2026-09-29). Sources: `app/models/location.rb`, `app/models/browse.rb` (`by_accessible`), `app/controllers/plans_controller.rb` (`find_matching_locations`).

## Mine Checker and Minolovac

- **Internal check.** Every location coordinate change is checked against recorded mine-suspected areas in BiH, and a match within 500 m blocks the save. The message never reveals geometry; details go to an internal audit log ([#157](https://github.com/misabegovic/usput.ba/pull/157); `docs/mine_checker/README.md`).
- **Public check.** `/mine-check` answers in coarse bands only (danger within 500 m, caution to 2 km, no known intersections with the data date and a "not a guarantee" caveat, out of coverage, unavailable). It shows simplified area outlines for the current view, is rate limited to 30 checks a minute per IP, and carries a permanent warning pointing to BHMAC (`app/controllers/mine_check_public_controller.rb`; `docs/mine_checker/README.md`, "Faza 2").
- **Minolovac.** `/minesweeper` is an educational minesweeper over real map tiles, where a mine is any grid cell that overlaps a recorded suspected area. An empty board is not playable, and the page says an empty cell is never a safety statement (`app/controllers/minesweeper_controller.rb`; `docs/mine_checker/README.md`).

Details: [architecture/mine-checker.md](../architecture/mine-checker.md).

## Offline and PWA

The app has a web manifest, install banner and offline banner, and registers `/sw.js`. That service worker precaches the home page, an offline page, the manifest and icons, and serves HTML network first with a cache fallback (`app/views/layouts/application.html.erb`; `public/sw.js`). There is no offline mode for walking or checking in beyond the device-held guest walk. Present before 2026-01-15.

## Translations

The interface ships in 16 locales, with English as the default (`config/application.rb`). Content fields are translated per record and fall back along a locale chain; a place's name and description resolve in one query since [#166](https://github.com/misabegovic/usput.ba/pull/166). Audio tours are generated per locale (`app/models/audio_tour.rb`). AI generates translations through the Platform DSL (see [architecture/ai-content-pipeline.md](../architecture/ai-content-pipeline.md)).
