---
title: Restore all DSL executor functionality in modules
kind: decision
status: accepted
updated: 2026-09-29
repos:
  - usput.ba
confidence: medium
supersedes: decisions/executor-simplification.md
sources:
  - sources/planning/adr/ADR-2026-01-16-restore-all-executor-functionality.md
  - sources/planning/decisions/2026-02-03-remove-platform-database.md
  - lib/platform/dsl/executor.rb
  - lib/platform/dsl/executors.rb
---

# Restore all DSL executor functionality in modules

## Context

Earlier on 2026-01-16 the team archived 13 of the executor's 19 query types to a `future/` folder, per [executor-simplification](executor-simplification.md). After discussion the same day they chose to bring everything back at once. The original record is `sources/planning/adr/ADR-2026-01-16-restore-all-executor-functionality.md`.

## Decision

All 19 query types return to full function, but in focused modules rather than one file. `executor.rb` becomes a dispatcher of about 200 lines, and each module owns a group: Schema, TableQuery, Infrastructure (infrastructure and logs), Prompts (prompts, improvement, prompt actions), Content (mutation, generation, audio), Curator (proposals, applications, approval, curators, curator management), Knowledge (summaries, clusters) and External (external and code queries). Skipped tests are re-enabled and the legacy file is deleted once verified.

## Alternatives

- Keep only the 6 production query types active, as the earlier proposal did. Reversed.
- Delete the unused code outright. Not chosen.

## Consequences

Every query type works, the code stays organised by concern, and the tests come back.

## Status notes

The module structure holds. `lib/platform/dsl/executor.rb` is 166 lines and dispatches to modules autoloaded in `lib/platform/dsl/executors.rb`: Schema, TableQuery, Infrastructure, Content, Curator, External, plus a later Quality module (`quality_query` and `validation`, first added in #133 on 2026-01-17).

Two modules named here are gone. Knowledge and Prompts were deleted on 2026-02-03 with the platform database, see [remove-platform-database](remove-platform-database.md). Today the dispatcher handles 16 query types, not 19.
