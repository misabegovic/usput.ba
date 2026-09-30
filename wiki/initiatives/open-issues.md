---
title: Open issues
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- https://github.com/misabegovic/usput.ba/issues
- config/routes.rb
- db/schema.rb
- app/controllers/new_design_controller.rb
- app/controllers/locations_controller.rb
- app/controllers/plans_controller.rb
- app/models/plan.rb
- app/models/experience.rb
- app/models/browse.rb
- app/services/geoapify_service.rb
- app/views/pwa/service-worker.js
- lib/platform/mcp_server.rb
depends_on:
- state.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/state.md
---
# Open issues

The 17 open GitHub issues on misabegovic/usput.ba as of 2026-09-29, grouped by theme. Titles are translated to English; the note on each says whether recent work already addresses it, judged by reading the current code. Issue bodies were read from GitHub on 2026-09-29. Most were opened in January 2026, before the September traveller work (#161 to #167), so several are partly answered and none has been closed.

## Content quality and data

- [#139](https://github.com/misabegovic/usput.ba/issues/139) **Experience duration and location price.** Asks for simple rules the AI follows (by place type, number of places, distance between them), a retroactive data fix, and teaching the content director agent. Not addressed: `Experience` validates only that `estimated_duration` is positive, and places keep a `budget` field set by enrichment (`app/models/experience.rb`).
- [#85](https://github.com/misabegovic/usput.ba/issues/85) **Fix generated experience descriptions, and duration in general.** The first part (descriptions naming places outside the experience) is struck through as fixed in the issue. The rest, capping an experience at about 6 hours and splitting long ones into parts, is not addressed; no cap exists in the model.
- [#27](https://github.com/misabegovic/usput.ba/issues/27) **Stale locations and data.** Asks for a way to track and fix discrepancies (reporting, regeneration, more data sources). Partly addressed: the DSL quality executor and content validation (#133, #136, #141) and place archiving (#167) exist, but there is no traveller-facing report.
- [#135](https://github.com/misabegovic/usput.ba/issues/135) **A replacement for Geoapify.** Coordinates are not good enough. Not addressed: `GeoapifyService` is still the geocoder and POI source (`app/services/geoapify_service.rb`).
- [#30](https://github.com/misabegovic/usput.ba/issues/30) **Improve season filtering and search, and season generation.** Partly addressed: explore filters by season, treating an empty list as year-round (`Browse.by_season`). Generation quality is not addressed.

## Explore, search and maps

- [#111](https://github.com/misabegovic/usput.ba/issues/111) **Improve explore page filters** (filter on tags). Partly addressed: explore now filters by type, season, budget, duration, rating, city, origin, audio and accessibility (`app/controllers/new_design_controller.rb`), but not by tag. Tags reach search only as full text.
- [#86](https://github.com/misabegovic/usput.ba/issues/86) **Map view** for exploring and for plan, experience and location pages, with nearby places. Largely addressed: a location map (#163), map points and a map panel on places, a route page, and map cards on the plan walk (#164) and the Explore Bosnia deck (#165) (`config/routes.rb`). A map on experience pages is (unverified, 2026-09-29).
- [#153](https://github.com/misabegovic/usput.ba/issues/153) **Cycling trails** (experiences for cyclists). Not addressed: no cycling experience type or trail data exists.
- [#29](https://github.com/misabegovic/usput.ba/issues/29) **Area information**: live conditions for planning (roads, accidents, weather, ice). Not addressed.

## Plans and the traveller

- [#81](https://github.com/misabegovic/usput.ba/issues/81) **Plan create improvements**: let plans include standalone places, not only experiences. Partly addressed: plans have their own stops since #161 (`plan_locations`, `Plan#location_items`), and plan pages load them beside experiences. Whether the plan wizard creates standalone stops is (unverified, 2026-09-29).
- [#79](https://github.com/misabegovic/usput.ba/issues/79) **Mark as visited improvements**: use visits to find similar places or exclude visited ones, and show how many people visited a place. Partly addressed: check-ins are real rows (#161, #164), visited places drop out of the Explore Bosnia deck (#165), and the place page knows whether you visited (`app/controllers/locations_controller.rb`). Similarity recommendations and a public visitor count are not addressed.
- [#2](https://github.com/misabegovic/usput.ba/issues/2) **UX: city or place when creating a plan.** It is unclear why a city is unavailable; tell the user the reason. Not addressed as far as the code shows: `find_city` answers "No locations found nearby" without a reason (`app/controllers/plans_controller.rb`).
- [#24](https://github.com/misabegovic/usput.ba/issues/24) **Offline version improvements.** Partly addressed: a service worker, an offline banner, an install banner, and a walk that lives on the device without an account (#166) exist (`app/views/pwa/service-worker.js`). What "improve" means is not specified in the issue.

## Media

- [#80](https://github.com/misabegovic/usput.ba/issues/80) **Video URLs**: support several videos, promo videos for plans and experiences, and host them on one S3 or Vimeo account instead of YouTube. Not addressed: `locations.video_url` is still one string (`db/schema.rb`). Slice 6 of [curator dashboard v2 salvage](curator-dashboard-v2-salvage.md) covers the column change.

## Curators and the platform

- [#21](https://github.com/misabegovic/usput.ba/issues/21) **Curator dashboard improvements.** The first items (translation and audio refresh flags, text-based audio tours, tags) are struck through as done; what remains is a general better curator experience. Partly addressed by #147 and #149; the rest is tracked in [curator dashboard v2 salvage](curator-dashboard-v2-salvage.md) and [review approval system](review-approval-system.md).
- [#31](https://github.com/misabegovic/usput.ba/issues/31) **MCP integration**: Usput.ba as a tool for LLMs, for data and plan creation, possibly on a self-hosted model. Partly addressed: `lib/platform/mcp_server.rb` exposes the DSL over MCP, but it refuses to run in production and has no plan creation tool, so no outside user can reach it.

## Accessibility

- [#15](https://github.com/misabegovic/usput.ba/issues/15) **Location proposal: accessibility** (the body is a screenshot only). Addressed for wheelchair access by PR #154, merged through #168; see [location accessibility](location-accessibility.md). Other kinds of accessibility have no fields.
