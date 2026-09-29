---
title: Simplify the DSL executor by archiving unused query types
kind: decision
status: superseded
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
superseded_by: decisions/restore-all-dsl-executors.md
sources:
- sources/planning/archive/ADR-2026-01-16-executor-simplification.md
- sources/planning/adr/ADR-2026-01-16-restore-all-executor-functionality.md
enola_intent:
  page:
    type: decision
    status: superseded
    scope:
    - usput.ba
    origin:
    - other
    relations:
    - rel: superseded-by
      to: wiki/decisions/restore-all-dsl-executors.md
---
# Simplify the DSL executor by archiving unused query types

## Context

On 2026-01-16 `Platform::DSL::Executor` had grown to 3,001 lines, 140 methods, 19 query types and more than 125 case branches. Only 6 query types were used in production: `schema_query`, `table_query`, `infrastructure_query`, `prompts_query`, `logs_query` and `improvement`. The other 13 were implemented and unit tested but not documented to the language model. The original proposal is `sources/planning/archive/ADR-2026-01-16-executor-simplification.md`.

## Decision

Recommended option: split the executor into focused modules, keep the 6 used query types active (core down to about 500 lines), and move the 13 unused ones (content, curator, knowledge, external) into an archived `executors/future/` folder, skipping their tests. Estimated effort 2 to 4 hours; expected to cut coverage warnings from 170 to under 50.

## Alternatives

- Delete the 13 unused query types (about 2,000 lines). Simplest, but they would have to be rewritten when needed.
- Keep the file as is and add tests. No refactoring risk, but the God object stays hard to test.

## Consequences

The archive step was carried out the same day and reversed within hours.

## Status notes

Superseded on 2026-01-16 by [restore-all-dsl-executors](restore-all-dsl-executors.md), which kept the module split but brought all 19 query types back. No `executors/future/` folder exists in today's tree.
