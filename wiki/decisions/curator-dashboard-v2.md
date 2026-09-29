---
title: Curator dashboard v2 (RFC-0001)
kind: decision
status: proposed
updated: 2026-09-29
repos:
  - usput.ba
confidence: medium
sources:
  - sources/planning/pr-151/rfcs/0001-curator-dashboard-v2.md
  - https://github.com/misabegovic/usput.ba/pull/151
  - app/models/content_change.rb
  - app/models/location.rb
  - app/controllers/curator/locations_controller.rb
  - app/views/curator/locations/index.html.erb
---

# Curator dashboard v2 (RFC-0001)

## Context

RFC-0001, written for PR #151 on 2026-02-05, claims the polymorphic `ContentChange` proposal model does not work in production and only `PhotoSuggestion` does. It names six problems: one JSONB model cannot cover each resource's shape (many to many links on locations, ordered locations on experiences, day schedules on plans); photos are silently dropped from proposals; string form values are not cast back on approval; merging contributions with a shallow hash merge lets the last curator overwrite earlier ones; "creating" a location that does not exist until approval confuses curators; and `PhotoSuggestion` proves the per-resource approach works but the lesson was never applied. With the `curator_edit_delete` flag off in production, curators could only suggest photos. The original is `sources/planning/pr-151/rfcs/0001-curator-dashboard-v2.md`.

## Decision

Proposed, as an umbrella for five ADRs:

- Two modes of work: admins get plain direct create, update and delete; curators only suggest, and an admin approves or rejects.
- Per-resource suggestion models replace `ContentChange` and absorb `PhotoSuggestion`, see [per-resource-suggestion-models](per-resource-suggestion-models.md).
- Review moderation with curator flagging, see [post-moderated-reviews](post-moderated-reviews.md).
- Admin-only audio tour generation from the location page, see [admin-audio-tour-generation](admin-audio-tour-generation.md).
- Several video links per place and a cover photo for plans, see [multiple-videos-and-plan-covers](multiple-videos-and-plan-covers.md).
- Suggestions record whether a human or an AI service made them, see [ai-suggestions-carry-origin](ai-suggestions-carry-origin.md).

## Alternatives

The RFC's alternatives are argued in its child ADRs; the main one, fixing `ContentChange` in place, is recorded in [per-resource-suggestion-models](per-resource-suggestion-models.md).

## Consequences

Had it shipped: a working content workflow for curators, direct control for admins, reviews under moderation and audio tours generated without a console. The cost was a large rewrite of models, controllers, views and tests in one PR.

## Status notes

PR #151 was never merged and conflicts with main in 8 files. Main moved the other way. It kept investing in `ContentChange` (plan stops with `location_days` from #161, and `destroy_with_traveller_records!` in `app/models/content_change.rb`), hid edit and delete buttons behind a global Flipper `:curator_edit_delete` flag in #149 (`app/views/curator/locations/index.html.erb`), and lets archiving a place land directly without a proposal ([archive-places-not-delete](archive-places-not-delete.md)). A per-user version of the flag (#151's `User#flipper_id`) is still worth taking. The per-resource part needs a fresh decision against main before any porting: retire `ContentChange` or fix it. The operator chose to close #151 and point it at a salvage initiative that takes the pieces one at a time (salvage report, 2026-09-29).
