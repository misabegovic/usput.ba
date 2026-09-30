---
title: Remove the platform database and keep two databases
kind: decision
status: accepted
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- sources/planning/decisions/2026-02-03-remove-platform-database.md
- config/database.yml
- db/schema.rb
- lib/platform/dsl/executors.rb
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - repo
---
# Remove the platform database and keep two databases

## Context

The project ran three PostgreSQL databases: primary (the application), queue (Solid Queue jobs) and platform. The platform database held `PlatformAuditLog` (an audit trail of DSL actions), `PreparedPrompt` (fix and feature prompts), `PlatformStatistic` (cached stats) and the knowledge layers (`KnowledgeSummary`, `KnowledgeCluster`, `ClusterMembership`) with pgvector embeddings. A usage review found that agents call the CLI (`bin/platform exec`) directly rather than any API, nobody reads the audit log, prepared prompts go unused because agents act directly, the knowledge layers go unused because DSL queries suffice, and keyword search makes embeddings unnecessary. The original record, by Muhamed and Claude on 2026-02-03, is `sources/planning/decisions/2026-02-03-remove-platform-database.md`.

## Decision

Remove the platform database entirely and keep only primary and queue. That deletes the seven platform models, the knowledge and prompts executors, `lib/platform/knowledge/`, the platform jobs, the platform migrations and schema, and the platform section of `database.yml`. Audit logging is stripped from the remaining executors and from the spam detector.

## Alternatives

- Merge the platform database into primary. Rejected: it needs migrations and pgvector in primary.
- Keep only the audit log. Rejected: nobody uses it.
- Audit through the Rails logger. Left open for later if a need appears.

## Consequences

A simpler architecture with less to maintain: about 15,000 lines and 50 files removed, and the test count fell from 3,635 to 2,725. The trade-offs are no audit trail of DSL actions and no semantic search, both judged acceptable because neither was used.

## Status notes

The code matches. `config/database.yml` defines only the primary and queue databases (`db/queue_schema.rb` beside `db/schema.rb`, no platform schema), `db/schema.rb` enables only `plpgsql` (no vector extension), and `lib/platform/dsl/executors.rb` autoloads no Knowledge or Prompts executor. This decision retires parts of [dsl-first-platform-architecture](dsl-first-platform-architecture.md), [platform-implementation-choices](platform-implementation-choices.md) and the self-improvement half of [introspection-in-p0](introspection-in-p0.md). It landed in code with commit 9e2b1b8 (#147, 2026-02-04).
