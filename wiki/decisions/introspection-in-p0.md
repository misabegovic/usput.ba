---
title: Introspection and self-improvement in P0
kind: decision
status: accepted
updated: 2026-09-29
repos:
  - usput.ba
confidence: medium
sources:
  - sources/planning/adr/2025-01-15-full-introspection-p0.md
  - sources/planning/decisions/2026-02-03-remove-platform-database.md
  - lib/platform/dsl/executors/infrastructure.rb
  - lib/platform/dsl/executors/external.rb
  - lib/platform/dsl/executor.rb
---

# Introspection and self-improvement in P0

## Context

The first plan put introspection (the Platform reading its own code and logs) and self-improvement (the Platform preparing fix prompts) at P2, as extras after content generation. On 2025-01-15 the Product Owner asked for both in P0. The original record is `sources/planning/adr/2025-01-15-full-introspection-p0.md`.

## Decision

Introspection and self-improvement become P0, reasoning that a Platform that does not understand itself is not a real brain. P0 grows from phases 1 to 9 to phases 1 to 11. Remote access stays P2; admin mode and cleanup stay P3.

Introspection covers code analysis (read a file, search, list files, complexity), log analysis (errors, slow queries, exceptions, failing external APIs) and infrastructure monitoring (queue, database health, memory, response times, job failures). Self-improvement covers preparing fix, feature and migration prompts and managing them (list, show, mark executed).

## Alternatives

- Keep both at P2 as the original plan had it. The Product Owner overruled this.

## Consequences

The Platform can spot problems early and give the admin a view of system health in conversation. P0 is bigger and the MVP later, and the Platform needs access to code and logs. Mitigations: introspection is read only, prepared prompts are only suggestions that a human chooses to run, and log access can be limited to production-safe queries.

## Status notes

Introspection holds. `lib/platform/dsl/executor.rb` dispatches `infrastructure_query`, `logs_query` and `code_query`; logs and system health live in `lib/platform/dsl/executors/infrastructure.rb`, and file reading, code search, models and routes in `lib/platform/dsl/executors/external.rb`.

Self-improvement does not. The prepared prompts store (`PreparedPrompt`) and the prompts executor were deleted on 2026-02-03 because agents act directly and never read them, see [remove-platform-database](remove-platform-database.md).
