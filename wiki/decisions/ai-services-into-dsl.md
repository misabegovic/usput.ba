---
title: Migrate the AI services into DSL executors
kind: decision
status: proposed
updated: 2026-09-29
repos:
  - usput.ba
confidence: medium
depends_on:
  - decisions/dsl-first-platform-architecture.md
sources:
  - sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md
  - app/services/ai/location_enricher.rb
  - lib/platform/dsl/executors/content.rb
  - lib/tasks/audio_tours.rake
  - lib/tasks/experience_types_cleanup.rake
---

# Migrate the AI services into DSL executors

## Context

Four AI services call the language model with their own logic: `Ai::LocationEnricher` (descriptions, history, tags, experience types), `Ai::ExperienceTypeClassifier`, `Ai::AudioTourGenerator` (script plus text to speech) and `Ai::ExperienceLocationSyncer` (finds locations named in experience descriptions). All already load prompts from `app/prompts/` through `PromptHelper`, rate limit through `Ai::OpenaiQueue`, and are well tested. The problems named on 2026-02-04: `LocationEnricher` is marked deprecated with no migration path, none of the services is reachable from the Platform DSL, there is no common interface for AI operations, and batch, metadata and translation logic is buried inside services. The original proposal, by the Tech Lead and Developer, is `sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md`.

## Decision

Proposed: the DSL becomes the only interface for AI operations, through a staged migration that never deletes a service before its replacement works. Six phases were planned: wrap each service in a DSL executor (`enrich`, `classify_experience_types`, `generate_audio`, `sync_locations`) with no logic change; move rake tasks, jobs and controllers onto DSL calls; refactor (split `LocationEnricher` into metadata, descriptions and history modules, batch calls, cache results); switch on deprecation warnings; write guides; and remove the legacy services in Q4 2026. Rollback options were a feature flag, running both modes side by side, or reverting.

## Alternatives

The document weighs no alternative to migrating. Its rollback plan (flag, dual mode, revert) is the only fallback it names.

## Consequences

Expected gains: one consistent interface, composable pipelines (filter, then enrich, then classify), easier testing and central monitoring. Expected costs: about six weeks of work, two parallel paths from Q1 to Q3 2026, migration docs, and possible performance regressions.

## Status notes

Never approved: the approval checkboxes in the original are empty and the approval date says TBD. The code shows no migration.

- No `ai_enrich`, `ai_classify`, `ai_audio` or `ai_sync` executor exists under `lib/platform/dsl/executors/`.
- Only audio is reachable through the DSL: `lib/platform/dsl/executors/content.rb` calls `Ai::AudioTourGenerator` directly. That predates this proposal.
- The four services remain in `app/services/ai/`, and `LocationEnricher` has been split into `metadata_generator`, `description_generator`, `historical_generator` and `applicator` under `app/services/ai/location_enricher/`, which is phase 3's split done inside the service instead of the executor.
- Rake tasks still call services directly (`lib/tasks/audio_tours.rake`, `lib/tasks/experience_types_cleanup.rake`).
- The deprecation note on `Ai::LocationEnricher` points to `bin/platform chat`, a command the CLI no longer has.

The original also cites the introspection ADR as "the DSL-first decision"; the DSL-first decision is [dsl-first-platform-architecture](dsl-first-platform-architecture.md).
