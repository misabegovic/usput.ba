---
title: Several video links per place and a cover photo for plans
kind: decision
status: proposed
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/curator-dashboard-v2.md
sources:
- sources/planning/pr-151/decisions/2026-02-05-video-urls-and-cover-photos.md
- https://github.com/misabegovic/usput.ba/pull/151
- db/schema.rb
- app/models/experience.rb
- app/models/plan.rb
enola_intent:
  page:
    type: decision
    status: proposed
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/decisions/curator-dashboard-v2.md
---
# Several video links per place and a cover photo for plans

## Context

ADR-0006 of PR #151 (2026-02-05) notes that `Location` has a single `video_url` string, though a place may have a YouTube tour, a drone shot, a reel and a TikTok, while experiences and plans have no video at all. For covers, locations have many photos with variants, experiences have one `cover_photo` without variants, and plans have none: they borrow from their experiences, so a plan without experiences has no cover and an admin cannot pick a specific one. The original is `sources/planning/pr-151/decisions/2026-02-05-video-urls-and-cover-photos.md`.

## Decision

Proposed: replace `video_url` on locations with a JSONB array `video_urls`, migrating existing values, and add the same column to experiences, with URL validation in the model and a small Stimulus controller to add and remove fields. Give `Plan` its own attached `cover_photo`, with a fallback chain: the plan's own photo, then an experience's cover, then a location photo. Add thumb, medium and large variants to experience and plan covers. Suggestion models gain the matching proposed fields.

## Alternatives

- A separate video table (`LocationVideo` with platform and title). Rejected as too much for a list of links; it can come later if metadata is needed.
- Keep one `video_url` and add another to experiences. Rejected: it does not solve several videos per place.

## Consequences

Expected: many videos per place, videos on experiences, admin-chosen plan covers and consistent image variants, with old data kept. Costs: JSONB has no constraints so validation lives in the model, a new bit of JavaScript, and possible confusion over which plan image wins (settled by the fallback order).

## Status notes

Not on main, and not in #151 either: #151 never implemented the video migration. `db/schema.rb` still has a single `locations.video_url`. `Experience` already has `has_one_attached :cover_photo` with a fallback to location photos (`app/models/experience.rb`); `Plan` still has no cover of its own and derives one from its experiences (`display_cover_photo` in `app/models/plan.rb`). The salvage report of 2026-09-29 splits this into two later slices: `locations.video_urls` with a backfill first (experiences separately), then the plan cover photo with its fallback chain.
