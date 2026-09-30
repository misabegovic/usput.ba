---
title: Curator dashboard v2 salvage
kind: initiative
status: superseded
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
superseded_by: decisions/admin-through-avo.md
sources:
- sources/planning/pr-151/README.md
- sources/planning/pr-151/rfcs/0001-curator-dashboard-v2.md
- sources/planning/pr-151/decisions/2026-02-05-per-resource-suggestion-models.md
- sources/planning/pr-151/decisions/2026-02-05-reviews-management-system.md
- sources/planning/pr-151/decisions/2026-02-05-audio-tour-generation-integration.md
- sources/planning/pr-151/decisions/2026-02-05-video-urls-and-cover-photos.md
- sources/planning/pr-151/decisions/2026-02-05-ai-vs-human-suggestion-origin.md
- sources/planning/REVIEW_APPROVAL_SYSTEM.md
- config/routes.rb
- db/schema.rb
- app/models/moment.rb
- app/models/content_change.rb
- app/models/plan.rb
- app/models/experience.rb
- lib/tasks/audio_tours.rake
- https://github.com/misabegovic/usput.ba/pull/151
- https://github.com/misabegovic/usput.ba/pull/152
depends_on:
- state.md
- initiatives/review-approval-system.md
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
    - rel: depends-on
      to: wiki/initiatives/review-approval-system.md
    - rel: superseded-by
      to: wiki/decisions/admin-through-avo.md
---
# Curator dashboard v2 salvage

> Superseded on 2026-09-30: the curator area is removed rather than salvaged ([decision](../decisions/admin-through-avo.md)). Audio tour generation and multiple videos, the two pieces worth keeping, carry over as Avo actions and fields.

## Objective

Take the parts of PR #151 that still earn their place, in an order where each slice ships on its own against today's main, and close #151 pointing here. The one question that blocks the larger half is whether `ContentChange` is retired or fixed.

## Background

PR #151 (branch `claude/review-curator-dashboard-bah58`, last updated 2026-02-05) was never merged. Its planning documents are snapshotted under `sources/planning/pr-151/`: an umbrella RFC and ADR-0003 to ADR-0007, all "Proposed". The brain records them as [curator dashboard v2](../decisions/curator-dashboard-v2.md), [per-resource suggestion models](../decisions/per-resource-suggestion-models.md), [post-moderated reviews](../decisions/post-moderated-reviews.md), [admin audio tour generation](../decisions/admin-audio-tour-generation.md) and [multiple videos and plan covers](../decisions/multiple-videos-and-plan-covers.md). Its merge base is #150 (605291b), and it conflicts with main in eight files after the traveller work of September 2026.

The RFC's premise is that `ContentChange` does not work in production and only `PhotoSuggestion` does. It names six causes: one polymorphic JSONB model cannot cover each resource's associations, photos are excluded from proposals, string form values are not converted back to types on approve, a shallow merge lets the last curator overwrite earlier contributions, "creating" a place that does not exist until approval is confusing, and the working `PhotoSuggestion` proves the per-resource approach (`sources/planning/pr-151/rfcs/0001-curator-dashboard-v2.md`).

What #151 proposes, compared with main on 2026-09-29:

- **Per-resource suggestion models** (ADR-0003): main lacks them. #151 never removed `ContentChange` either, so merging it would ship two proposal systems. Main has kept investing in `ContentChange` (plan stops by day from #161, and approved deletions that go through `destroy_with_traveller_records!`, per `app/models/content_change.rb`).
- **Admin direct CRUD**: partial on main. #149 hides the buttons behind a global `curator_edit_delete` flag; #151 makes it per user. Archiving and restoring places (#167) already act directly.
- **Review moderation** (ADR-0004): main lacks it, and #152's pre-moderation plan competes with #151's post-moderation design; see [review approval system](review-approval-system.md).
- **Audio tour generation from the dashboard** (ADR-0005): main lacks it. `Ai::AudioTourGenerator` is only called from rake tasks and the DSL (`lib/tasks/audio_tours.rake`).
- **Multiple video URLs** (ADR-0006): neither has them; `locations.video_url` is still one string (`db/schema.rb`).
- **Plan cover photo** (ADR-0006): neither has an attachment. `Experience` has `cover_photo`; `Plan` only derives a display photo from its experiences (`app/models/plan.rb`).
- **Human versus AI origin** (ADR-0007): main has `ai_generated` booleans; #151's `origin` and `ai_service` columns exist only on its suggestion tables, and no AI service was rewired.
- **The moderation queue pattern** already exists on main for moments: pending, approved, rejected, with approve and reject actions and activities (`app/models/moment.rb`, `config/routes.rb`).

## Affected personas

- Admins: generate audio tours, edit content directly, and decide proposals.
- Curators: the suggestion flow they use every day, and the only path for their contributions.
- Travellers: indirectly, through audio tours, videos and plan covers.

## Scope

The nine slices, in order, with the reason for each position:

1. **Audio tour generation from the dashboard.** Port `AudioTourGenerateJob`, a `generate_audio_tour` action, the panel on the location show page and three activity actions. Admin only; refuse archived places. First because it is small (about 150 lines of app code), self-contained, and fills a real gap: today only a developer with a shell can generate a tour. ADR-0005 notes the ElevenLabs cost, so the button confirms the price.
2. **Review moderation as #152 wrote it**, phases 1 to 4, ignoring #151's `moderation_status`. Second because the plan is already merged and matches the moment convention. Tracked in [review approval system](review-approval-system.md).
3. **Optional curator flagging of reviews** on top of slice 2's enum. The one piece of ADR-0004 worth keeping; only after slice 2 so there is one status column.
4. **Per-user `curator_edit_delete`** through an actor-aware Flipper check (`User#flipper_id`), without touching the proposal flow. Cheap, and it lets one trusted admin work directly while the global flag stays off.
5. **Admin direct update for locations and experiences** behind the per-user flag. No direct delete: archiving already covers retirement and keeps travellers' records.
6. **Multiple video URLs, part 1**: `locations.video_urls` as JSONB backfilled from `video_url`, experiences separately. Answers issue #80.
7. **Plan cover photo, part 2 of ADR-0006**: an attachment on `Plan` with a fallback chain to the current derived photo.
8. **Decision slice only**: rewrite ADR-0003 and the RFC against today's main (plan stops by day in `ContentChange`, archiving, the moments queue) and decide whether `ContentChange` is retired or fixed. No suggestion tables are ported before this.
9. **After slice 8**: `LocationSuggestion` with contributions and photos, absorbing `PhotoSuggestion`; then experience and plan suggestions; `origin` and `ai_service` last.

Reference only, not ported: #151's unified suggestions index, the admin suggestion show views and the direct delete paths.

## No-gos

- No merge of #151 as a branch; it is taken slice by slice and then closed.
- No second proposal system running beside `ContentChange`.
- No direct delete of places, experiences or plans from the dashboard.
- No post-moderation review statuses.

## Rabbit holes

- **The production claim.** The RFC says `ContentChange` is broken in production, but #154 later fixed proposal approval for accessibility (3f1e63d) and #161 extended it. Whether it works today is (unknown, needs source): slice 8 starts by testing an approve round trip for each resource.
- **Suggestions for resources with travellers' records.** Plans now carry stops, check-ins and moments; a plan suggestion must not rewrite what travellers already hold.
- **Audio cost.** Bulk generation from a button can spend money quickly; keep it one place at a time.
- **Video hosting.** Issue #80 also asks to move videos off YouTube to one S3 or Vimeo account; slice 6 changes the column only.

## Appetite

Slices 1, 4 and 7 are small; slices 2, 5 and 6 are medium; slice 8 is a decision and a document; slice 9 is the largest and is not sized until slice 8 is decided. Calendar estimates are (unknown, needs source).

## Decision needed

**Retire or fix `ContentChange`.** Retire means per-resource suggestion tables with typed columns and one pending suggestion per resource, absorbing `PhotoSuggestion`, and migrating or discarding open proposals. Fix means keeping one polymorphic model and repairing type conversion on approve, deep-merging contributions and including photos, as the RFC's rejected alternative A describes. Retiring matches the pattern that already works (`PhotoSuggestion`, moments); fixing keeps the plan-stop support #161 added and avoids a migration. Until this is decided, slices 8 and 9 do not start. The operator has already chosen to close #151 pointing at this page once slices 1 and 2 are taken.
