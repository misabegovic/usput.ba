---
title: Review approval system
kind: initiative
status: superseded
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
superseded_by: initiatives/jev-review-flagging.md
sources:
- sources/planning/REVIEW_APPROVAL_SYSTEM.md
- sources/planning/pr-151/decisions/2026-02-05-reviews-management-system.md
- app/models/review.rb
- app/models/moment.rb
- app/controllers/reviews_controller.rb
- app/models/curator_activity.rb
- config/routes.rb
- db/schema.rb
- https://github.com/misabegovic/usput.ba/pull/152
- https://github.com/misabegovic/usput.ba/pull/151
depends_on:
- state.md
enola_intent:
  page:
    type: initiative
    status: superseded
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/state.md
    - rel: superseded-by
      to: wiki/initiatives/jev-review-flagging.md
---
# Review approval system

> Superseded on 2026-09-30 by the operator's decision that [Jev flags reviews](../decisions/jev-flags-reviews.md): reviews stay live and only flagged ones wait for an admin.

## Objective

Every review a traveller writes passes a curator or admin before the public sees it. Only signed-in users can review, the author always sees their own review whatever its status, and the average rating counts approved reviews only.

## Background

The plan was written on 2026-02-07 and merged as a planning document through PR #152 on 2026-09-29 (`sources/planning/REVIEW_APPROVAL_SYSTEM.md`, status "Proposed"). Nothing of it is implemented yet.

Today a review is live the moment it is saved. The `reviews` table has no status column (`db/schema.rb`), `Review` belongs to a user only optionally and recalculates `average_rating` from every review (`app/models/review.rb`), and `ReviewsController` has no login requirement and still permits a free-text `author_name` (`app/controllers/reviews_controller.rb`). Curators can list, view and delete reviews but cannot approve them (`config/routes.rb`).

The plan's decisions, translated from the Bosnian table:

- Only signed-in users can review; the name comes from `user.username` and the name field leaves the form.
- A new review starts `pending`. Only its author sees it while pending.
- Curators and admins approve or reject it on the curator dashboard, which opens on the pending filter by default.
- The author can edit a review at any time. Editing a rejected review sends it back to pending.
- A user may leave more than one review per resource.
- The public average counts approved reviews only; a signed-in user's view also counts their own pending reviews.
- No notifications: the author sees the status on the page.
- Every existing review moves to pending and must be approved.
- Approving and rejecting are recorded as `review_approved` and `review_rejected` curator activities.

The plan is laid out in five phases: migration and model (status, `reviewed_by`, `reviewed_at`), public controller and form, curator approve and reject, activity integration, and tests.

**A competing design exists.** PR #151 (never merged) carries ADR-0004, a post-moderation design: reviews are visible at once with a `moderation_status` of unreviewed, approved, flagged or removed, curators flag and admins approve or remove (`sources/planning/pr-151/decisions/2026-02-05-reviews-management-system.md`; recorded as [post-moderated reviews](../decisions/post-moderated-reviews.md)). Both designs claim the same column. #151's `removed` status is also never filtered from public pages or the average, so it is incomplete as written.

**The house convention already exists.** `Moment` uses `enum :moderation_status, { pending: 0, approved: 1, rejected: 2 }`, a curator queue with approve and reject actions, and `approve_moment` and `reject_moment` activities (`app/models/moment.rb`, `app/models/curator_activity.rb`). The #152 plan matches it; #151 does not.

## Affected personas

- Travellers who write reviews: they must sign in, and they wait for approval.
- Travellers who read reviews: they see fewer, vetted reviews and an average that may drop or rise when every existing review goes to pending.
- Curators: a new moderation queue beside moments, photo suggestions and proposals.
- Admins: the same queue, plus the decision on the existing backlog.

## Scope

- The five phases of `sources/planning/REVIEW_APPROVAL_SYSTEM.md` as written, for locations, experiences and plans.
- Naming aligned with `Moment` where the plan leaves room (enum values pending, approved, rejected).
- Curator approve and reject from the index and the show page, with activity logging.

## No-gos

- No post-moderation status set from #151 (unreviewed, flagged, removed). Pre-moderation is the chosen direction.
- No notifications to the author.
- No anonymous reviews after the change.
- No automatic or AI moderation in this pass.

## Rabbit holes

- **The backlog.** Moving every existing review to pending empties public ratings until curators work through it. The plan accepts this; the size of the backlog is (unknown, needs source).
- **Two averages.** A per-user average that includes their own pending reviews means the displayed rating depends on who is looking, which interacts with caching and with sort orders that read the stored `average_rating`.
- **`reviews_count` is a counter cache over all reviews** and would disagree with the approved-only average unless it is changed too; the plan keeps it as the total.
- **Explore and Explore Bosnia** stream a reviews panel in place (#165); those paths need the same `visible_to` filtering as the location page.
- **Guest travellers.** Since #166 a visitor can explore and check in without an account; requiring sign-in to review is a step up from that flow and should say so on the form.

## Appetite

Medium, the size the PR #151 salvage review gives this slice (slice 2 in [curator dashboard v2 salvage](curator-dashboard-v2-salvage.md)). A calendar estimate is (unknown, needs source). The plan touches one migration, `Review` and the `Reviewable` concern, the public and curator review controllers and their views, `CuratorActivity`, and three test files (`sources/planning/REVIEW_APPROVAL_SYSTEM.md`).

## Decision needed

- Confirm pre-moderation (#152) over post-moderation (#151 ADR-0004), and record it as a decision.
- Confirm that every existing review goes to pending, or approve the existing ones in the migration instead.
- Decide whether curator flagging (the one part of #151's design worth keeping) is a follow-up on top of the pending, approved, rejected enum, or dropped.
