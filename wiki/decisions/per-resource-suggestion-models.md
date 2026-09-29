---
title: Replace ContentChange with per-resource suggestion models
kind: decision
status: proposed
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/curator-dashboard-v2.md
sources:
- sources/planning/pr-151/decisions/2026-02-05-per-resource-suggestion-models.md
- https://github.com/misabegovic/usput.ba/pull/151
- app/models/content_change.rb
- app/models/photo_suggestion.rb
- db/schema.rb
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
# Replace ContentChange with per-resource suggestion models

## Context

ADR-0003 of PR #151 (Tech Lead and Product Manager, 2026-02-05) finds the polymorphic `ContentChange` model broken: JSONB `proposed_data` loses types, so approval sends `["1", "2"]` where associations need integers; file attachments are explicitly excluded from proposals; `merge_contributions!` is a shallow merge in creation order that silently discards an earlier curator's values; the per-model whitelist `safe_attributes_for` must be updated by hand for every new field; and the model has both `changeable_type` and a `changeable_class` string for creates, forcing `.or()` queries. `PhotoSuggestion`, a simple typed per-resource model, works in production. The original is `sources/planning/pr-151/decisions/2026-02-05-per-resource-suggestion-models.md`.

## Decision

Proposed: replace `ContentChange` with `LocationSuggestion` (which also takes photos and replaces `PhotoSuggestion`), `ExperienceSuggestion` and `PlanSuggestion`. Principles: one pending suggestion per resource, enforced by a unique constraint; several curators contribute to that one suggestion, and each contribution is stored in a per-resource contribution table with the same typed columns, so the admin sees who changed what; typed columns instead of JSONB; Active Storage for files; a shared `Suggestable` concern for status, change type, approve, reject and contributions. Admins edit directly; curators suggest. Once live, pending photo suggestions migrate, and `ContentChange`, `ContentChangeContribution`, `CuratorReview`, `PhotoSuggestion`, their controllers and views, and the `curator_edit_delete` flag are removed.

## Alternatives

- Fix `ContentChange` (type casting, attachments, merge). Rejected: the fault is architectural, so fixes would be patches.
- One suggestion per curator, admin picks one. Rejected: duplicate work and the user wants collaboration on one suggestion.
- Field-level suggestions. Rejected for now: no create flow and every field needs its own approval.
- Keep `PhotoSuggestion` separate. Rejected: two workflows for one resource.

## Consequences

Expected: approvals that work, focused tests, no whitelist to maintain, text and photos in one suggestion. Costs: six new tables, columns duplicated between suggestion and contribution, more merge code, and data migrations for `PhotoSuggestion` and `ContentChange`.

## Status notes

Not on main. `db/schema.rb` still has `content_changes` and `photo_suggestions`, and no suggestion tables. #151 never removed `ContentChange` (its proposal path still builds content changes), so merging it would have shipped two proposal systems side by side. Meanwhile main kept building on `ContentChange`: `location_days` for plan stops (#161) and `destroy_with_traveller_records!` (`app/models/content_change.rb`). The absorption of `PhotoSuggestion` is done in neither branch.

This needs a re-decision against main before any table is ported: rewrite this ADR and [curator-dashboard-v2](curator-dashboard-v2.md) against today's `ContentChange`, archiving and the moments moderation queue, and decide whether to retire or fix `ContentChange`. Only then build `LocationSuggestion` with contributions and photos, followed by experience and plan suggestions (salvage report, 2026-09-29).
