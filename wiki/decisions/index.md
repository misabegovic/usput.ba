---
title: Decisions
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
sources:
- AGENTS.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - repo
---
# Decisions

Architecture decision records, one choice per page. Accepted pages describe the code as it is; proposed pages are designs not yet adopted, most of them from the unmerged pull request #151. The [decision log](log.md) lists all of them in date order.

## Accepted

- [DSL-first architecture for the Platform](dsl-first-platform-architecture.md)
- [Platform implementation choices](platform-implementation-choices.md)
- [Introspection and self-improvement in P0](introspection-in-p0.md)
- [Restore all DSL executor functionality in modules](restore-all-dsl-executors.md)
- [Remove the platform database and keep two databases](remove-platform-database.md)
- [Mine Checker data from EUFOR maps](mine-data-from-eufor-maps.md)
- [Archive a place instead of deleting it](archive-places-not-delete.md)

## Proposed

- [Migrate the AI services into DSL executors](ai-services-into-dsl.md)
- [Curator dashboard v2 (RFC-0001)](curator-dashboard-v2.md)
- [Replace ContentChange with per-resource suggestion models](per-resource-suggestion-models.md)
- [Post-moderated reviews with curator flagging](post-moderated-reviews.md)
- [Admin-only audio tour generation from the dashboard](admin-audio-tour-generation.md)
- [Several video links per place and a cover photo for plans](multiple-videos-and-plan-covers.md)
- [AI changes arrive as suggestions marked with their origin](ai-suggestions-carry-origin.md)

## Superseded

- [Simplify the DSL executor by archiving unused query types](executor-simplification.md)

## Log

- [Decision log](log.md)
