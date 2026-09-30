---
title: AI changes arrive as suggestions marked with their origin
kind: decision
status: superseded
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/per-resource-suggestion-models.md
superseded_by: decisions/admin-through-avo.md
sources:
- sources/planning/pr-151/decisions/2026-02-05-ai-vs-human-suggestion-origin.md
- https://github.com/misabegovic/usput.ba/pull/151
- db/schema.rb
- app/services/ai/location_enricher.rb
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
      to: wiki/decisions/per-resource-suggestion-models.md
    - rel: superseded-by
      to: wiki/decisions/admin-through-avo.md
---
# AI changes arrive as suggestions marked with their origin

> Superseded on 2026-09-30: it depended on suggestion models that will not be built ([decision](admin-through-avo.md)).

## Context

ADR-0007 of PR #151 (2026-02-05) points out that every AI service writes straight to the database: `Ai::LocationEnricher` saves descriptions, translations and tags; `Ai::AudioTourGenerator` saves tours; `Ai::ExperienceLocationSyncer` attaches locations; `Ai::ExperienceTypeClassifier` adds experience types; and the Platform DSL executor saves records. AI content is live at once, with no review, so hallucinated history, generic tone, conflicting facts and hard rollbacks all reach users. The original is `sources/planning/pr-151/decisions/2026-02-05-ai-vs-human-suggestion-origin.md`.

## Decision

Proposed: AI output goes through the same suggestion workflow as curators' proposals. Each suggestion carries `origin` (human or AI generated) and `ai_service` (which service made it). AI services act as a dedicated system user ("Usput AI") and create suggestions instead of writing; the dashboard shows human and AI suggestions in separate tabs. The enricher and classifier create location suggestions, the syncer creates experience suggestions, and translations ride on the suggestion. Audio tour generation stays direct, because an admin's click is itself the approval. An auto-approve list per service exists but starts empty. When a human suggestion is already pending, the AI adds a contribution to it rather than opening a second one.

## Alternatives

- Only flag resources as AI generated. Rejected: a flag prevents nothing.
- A separate AI review queue model. Rejected: two inboxes and duplicated approval logic.
- A draft or published status on every resource. Rejected: a new status on four or more models and every public query.

## Consequences

Expected: nothing AI-made is live without a human, clear provenance, one workflow, easy rejection and gradual trust through auto-approve. Costs: a slower pipeline with an admin bottleneck for batches, a system account to guard, two-step translations, and a non-trivial rewrite of four services.

## Status notes

Not on main. Main marks provenance with `ai_generated` booleans on `locations`, `experiences`, `plans` and `browses` (`db/schema.rb`), and the AI services still write directly (for example `app/services/ai/location_enricher.rb`). In #151 the `origin` and `ai_service` columns exist only on its unmerged suggestion tables, and no AI service was rewired. This depends on [per-resource-suggestion-models](per-resource-suggestion-models.md) and needs the same re-decision against main; the salvage report of 2026-09-29 puts origin tracking last in its order.
