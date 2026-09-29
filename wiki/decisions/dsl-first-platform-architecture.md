---
title: DSL-first architecture for the Platform
kind: decision
status: accepted
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- sources/planning/architecture/2025-01-15-dsl-first-architecture.md
- sources/planning/decisions/2026-02-03-remove-platform-database.md
- lib/platform/dsl/parser.rb
- lib/platform/dsl/executor.rb
- lib/platform/cli.rb
- lib/platform/mcp_server.rb
- config/database.yml
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
# DSL-first architecture for the Platform

## Context

On 2025-01-15 the PM, Tech Lead and Product Owner chose how the Platform (the conversational AI brain that replaces the admin dashboard) should reason over content expected to grow past 1,000,000 records of locations, experiences and plans. Three approaches were weighed. The original record is `sources/planning/architecture/2025-01-15-dsl-first-architecture.md`.

## Decision

The Platform uses a query language (DSL) modelled on Grafana's LogQL. The language model writes DSL queries, a parser and executor run them against indexed data, and the model reasons over the structured result instead of over raw rows.

Knowledge was planned in four layers: Layer 0 (schema, stats and health, always in context, about 2K tokens), Layer 1 (AI summaries per region or category, loaded on demand), Layer 2 (semantic clusters in pgvector), and Layer 3 (raw records, reached only through indexed queries). The DSL is English; the Platform answers the admin in Bosnian.

## Alternatives

- Tools only: the model calls tools that read the database and reasons over what comes back. Rejected because a model cannot reason over millions of rows.
- pgvector first: precompute embeddings, run similarity search, reason over the top N. Rejected as mathematical similarity without real understanding.

## Consequences

The design scales and keeps the context window small, and pgvector is confined to cluster search. The cost is a parser, an executor, a carefully designed grammar, background jobs for Layers 1 and 2, query cost estimation, rate limits and timeouts, and a longer Phase 1.

## Status notes

The DSL core holds in today's code. `lib/platform/dsl/parser.rb` (Parslet), `lib/platform/dsl/grammar.rb` and `lib/platform/dsl/executor.rb` exist, and `bin/platform exec` (`lib/platform/cli.rb`) plus an MCP server (`lib/platform/mcp_server.rb`) expose it.

Two parts no longer match. The layered knowledge above Layer 0 was removed on 2026-02-03 together with the separate platform database and pgvector, see [remove-platform-database](remove-platform-database.md); `db/schema.rb` enables only `plpgsql` and `lib/platform/knowledge/` is gone. The in-app LLM wrapper (`lib/platform/brain.rb`, `conversation.rb`) was deleted in commit 9e2b1b8 (#147, 2026-02-04): the model that writes DSL is now an outside agent such as Claude Code calling `bin/platform exec`, not a Rails class.
