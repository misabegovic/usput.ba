---
title: Archive a place instead of deleting it
kind: decision
status: accepted
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- https://github.com/misabegovic/usput.ba/pull/167
- app/models/location.rb
- app/controllers/curator/locations_controller.rb
- app/models/curator_activity.rb
- db/schema.rb
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - repo
    - web
---
# Archive a place instead of deleting it

## Context

Deleting a place took travellers' check-ins and moments with it. This decision has no planning document; it is recorded from commit e3febb0 (PR #167, 2026-09-15, "Archiving moments view and fixes") and the code it introduced.

## Decision

A place is archived, not deleted. Archiving sets `archived_at` on the location: the place leaves the catalogue, travellers' records stay, and `restore!` brings it back. Because archiving is reversible it lands directly, without the proposal flow that guards irreversible changes. Delete remains, but it states what it would cost before going ahead, and archiving and restoring are recorded in the curator activity trail.

## Alternatives

- Hard delete with cascading records, the earlier behaviour. Rejected: travellers lose their check-ins and moments.
- Send retirement through the proposal flow. Not chosen: restore is one click away, so the guard adds nothing (reasoning from the comment on `archive` in `app/controllers/curator/locations_controller.rb`).

## Consequences

Travellers keep their history, and a mistaken retirement is undone in one step. Every catalogue query must exclude archived places, and a real delete becomes a deliberate, separate act.

## Status notes

In force on main. `db/schema.rb` has `locations.archived_at` with a partial index. `app/models/location.rb` has `archived` and `not_archived` scopes, `archive!`, `restore!` and `archived?`; `soft_delete` is an alias of `archive!` so the DSL content executor's delete retires a place instead of destroying it. Moments and plan visits have no cascade, a `before_destroy` guard refuses deletion while travellers hold records, and `destroy_with_traveller_records!` is the one explicit way past it. `Curator::LocationsController` has `archive` and `restore` actions and lists archived places with `?archived=1`; `CuratorActivity` has `archive_location` and `restore_location` actions (`app/models/curator_activity.rb`).
