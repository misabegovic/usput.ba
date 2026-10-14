---
title: Decision log
kind: reference
status: living
updated: 2026-10-08
repos:
- usput.ba
confidence: medium
sources:
- sources/planning/architecture/2025-01-15-dsl-first-architecture.md
- sources/planning/architecture/2025-01-15-implementation-decisions.md
- sources/planning/adr/2025-01-15-full-introspection-p0.md
- sources/planning/archive/ADR-2026-01-16-executor-simplification.md
- sources/planning/adr/ADR-2026-01-16-restore-all-executor-functionality.md
- sources/planning/decisions/2026-02-03-remove-platform-database.md
- sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md
- sources/planning/pr-151/rfcs/0001-curator-dashboard-v2.md
- sources/planning/pr-151/decisions/2026-02-05-per-resource-suggestion-models.md
- sources/planning/pr-151/decisions/2026-02-05-reviews-management-system.md
- sources/planning/pr-151/decisions/2026-02-05-audio-tour-generation-integration.md
- sources/planning/pr-151/decisions/2026-02-05-video-urls-and-cover-photos.md
- sources/planning/pr-151/decisions/2026-02-05-ai-vs-human-suggestion-origin.md
- docs/mine_checker/ADR-001-mine-data-source.md
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
# Decision log

Every recorded decision for Usput.ba in date order, oldest first. Dates are those of the original document (for the archiving decision, the merge of PR #167). Status reflects the code as checked on 2026-09-29; each page's `## Status notes` gives the file paths.

| Date | Decision | Status | Gist |
|------|----------|--------|------|
| 2025-01-15 | [DSL-first architecture for the Platform](dsl-first-platform-architecture.md) | accepted | The model writes LogQL-style DSL queries over layered knowledge; the DSL survives, the upper layers were later removed. |
| 2025-01-15 | [Platform implementation choices](platform-implementation-choices.md) | accepted | Parslet, ada-002 embeddings, on-demand summaries, English DSL, friendly errors, partial commits, unit and integration tests. |
| 2025-01-15 | [Introspection and self-improvement in P0](introspection-in-p0.md) | accepted | Code, log and infrastructure introspection move to P0; the prepared-prompts half was removed on 2026-02-03. |
| 2026-01-16 | [Simplify the DSL executor by archiving unused query types](executor-simplification.md) | superseded | Keep 6 used query types, archive 13; reversed the same day. |
| 2026-01-16 | [Restore all DSL executor functionality in modules](restore-all-dsl-executors.md) | accepted | All 19 query types back, split into modules; 16 remain after the platform database removal. |
| 2026-02-03 | [Remove the platform database and keep two databases](remove-platform-database.md) | accepted | Drop the unused audit log, prepared prompts, stats cache and pgvector knowledge layers; keep primary and queue. |
| 2026-02-04 | [Migrate the AI services into DSL executors](ai-services-into-dsl.md) | proposed | Wrap, migrate, then retire the four AI services behind DSL verbs; never approved, not started. |
| 2026-02-05 | [Curator dashboard v2 (RFC-0001)](curator-dashboard-v2.md) | superseded | Admins edit directly, curators suggest per resource, plus reviews, audio and media; PR #151 unmerged. |
| 2026-02-05 | [Replace ContentChange with per-resource suggestion models](per-resource-suggestion-models.md) | superseded | Typed location, experience and plan suggestions with contributions; needs a re-decision against main. |
| 2026-02-05 | [Post-moderated reviews with curator flagging](post-moderated-reviews.md) | superseded | Visible-until-removed reviews with flags; competes with the pre-moderation plan in REVIEW_APPROVAL_SYSTEM.md. |
| 2026-02-05 | [Admin-only audio tour generation from the dashboard](admin-audio-tour-generation.md) | proposed | A background job behind an admin button on the location page; first slice to salvage from #151. |
| 2026-02-05 | [Several video links per place and a cover photo for plans](multiple-videos-and-plan-covers.md) | proposed | `video_urls` JSONB on locations and experiences, a plan cover with fallbacks; built nowhere yet. |
| 2026-02-05 | [AI changes arrive as suggestions marked with their origin](ai-suggestions-carry-origin.md) | superseded | AI services create suggestions with `origin` and `ai_service` instead of writing directly. |
| 2026-07-20 | [Mine Checker data from EUFOR maps](mine-data-from-eufor-maps.md) | accepted | Phase 1 uses vectors extracted from EUFOR MICC maps, internal only, 500 m buffer; staleness no longer blocks in code. |
| 2026-09-15 | [Archive a place instead of deleting it](archive-places-not-delete.md) | accepted | `archived_at` retires a place and keeps travellers' records; restorable, logged, no proposal needed. |
| 2026-09-30 | [Jev flags reviews; flagged reviews wait for an admin](jev-flags-reviews.md) | accepted | Reviews stay live; the hosted TypeSafe Jev API hides negative or unsafe ones until an admin looks; the author always sees theirs. |
| 2026-09-30 | [Admin work moves to Avo; the curator area is removed](admin-through-avo.md) | accepted | Avo Community replaces the hand-built curator area; roles basic, curator and admin enforced in the app. |
| 2026-09-30 | [Avo now; compiling with Roundhouse and Spinel later](avo-now-compile-later.md) | accepted | Avo is adopted; Roundhouse is used for `check` only until compiling fits what usput uses. |
| 2026-09-30 | [Audio tours are paid by subscription; everything else stays free](audio-tours-by-subscription.md) | accepted | EUR 3 a week, 6 a month, 39 a year, all renewing, first stop free, through Stripe from a company abroad. |
| 2026-09-30 | [Accounts through Devise, signed in by email](accounts-through-devise.md) | accepted | Devise with confirmation (three-day grace), reset through Postmark, a rotating session token to sign out everywhere; replaces #171's session rows. |
| 2026-10-08 | [Capturing a moment needs a check-in at the place](capture-needs-a-check-in.md) | accepted | A moment is created only where the traveller checked in, on any plan; the upload tile waits for the visit. |
