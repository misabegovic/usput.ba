---
title: Post-moderated reviews with curator flagging
kind: decision
status: superseded
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/curator-dashboard-v2.md
superseded_by: decisions/jev-flags-reviews.md
sources:
- sources/planning/pr-151/decisions/2026-02-05-reviews-management-system.md
- sources/planning/REVIEW_APPROVAL_SYSTEM.md
- https://github.com/misabegovic/usput.ba/pull/151
- https://github.com/misabegovic/usput.ba/pull/152
- db/schema.rb
- app/models/moment.rb
enola_intent:
  page:
    type: decision
    status: superseded
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/decisions/curator-dashboard-v2.md
    - rel: superseded-by
      to: wiki/decisions/jev-flags-reviews.md
---
# Post-moderated reviews with curator flagging

> Superseded on 2026-09-30 by [Jev flags reviews](jev-flags-reviews.md).

## Context

ADR-0004 of PR #151 (Product Manager and Tech Lead, 2026-02-05) notes that the polymorphic `Review` model (rating 1 to 5, comment, author name, on locations, experiences and plans) has no moderation: every review is visible at once, curators cannot see or filter reviews, there is no per-resource view and no bulk action. `Curator::ReviewsController` has only index, show and destroy. The original is `sources/planning/pr-151/decisions/2026-02-05-reviews-management-system.md`.

## Decision

Proposed: a two-layer post-moderation system. Reviews gain `moderation_status` (unreviewed, approved, flagged, removed) with who moderated, when and notes; unreviewed reviews stay visible on purpose. Curators flag a review (a `review_flags` table, one flag per curator per review, with a reason: spam, inappropriate, inaccurate or other), which moves it to flagged. Admins approve, remove (a soft delete) or act in bulk. Public pages switch to a `visible` scope.

## Alternatives

- Admin delete only. Rejected: curators cannot help and it does not scale.
- Pre-moderation, hiding every review until an admin approves it. Rejected: it would choke user content on a platform with a small admin team.
- AI auto-moderation. Rejected for now as costly, error prone and too much for current volume.

## Consequences

Expected: spam can be flagged and removed, curators take part, soft delete allows recovery, and there is an audit trail. Costs: every existing review starts as unreviewed, every public query must use the new scope, and one more table.

## Status notes

Not on main: `reviews` in `db/schema.rb` has no status column. #151's implementation also never filtered `removed` reviews out of public pages or the average rating.

This competes with `sources/planning/REVIEW_APPROVAL_SYSTEM.md` (#152, merged 2026-09-29), which chooses the option this ADR rejects: pre-moderation with `status` pending, approved or rejected (default pending), `reviewed_by` and `reviewed_at`, login required, authors seeing their own pending reviews, averages from approved reviews only, and rejected reviews editable and resubmittable. #152 matches the existing moments convention (`Moment` has `moderation_status` pending, approved, rejected in `app/models/moment.rb`). Both designs claim the same column. Once REVIEW_APPROVAL_SYSTEM.md ships, this ADR should be marked superseded by it. Only the curator flagging layer (`ReviewFlag` and a flag action) is worth keeping, as an optional follow-up on top of #152's status (salvage report, 2026-09-29).
