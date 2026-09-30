---
title: Platform DSL
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- lib/platform.rb
- lib/platform/dsl.rb
- lib/platform/dsl/grammar.rb
- lib/platform/dsl/executor.rb
- lib/platform/dsl/executors.rb
- lib/platform/dsl/executors/table_query.rb
- lib/platform/dsl/executors/content.rb
- lib/platform/dsl/executors/external.rb
- lib/platform/dsl/llm_helper.rb
- lib/platform/dsl/content_validator.rb
- lib/platform/cli.rb
- lib/platform/mcp_server.rb
- bin/platform
- bin/platform-mcp
- bin/platform-prod
- config/database.yml
- config/queue.yml
- test/lib/platform/mcp_server_test.rb
- PLATFORM.md
- sources/planning/VISION.md
- sources/planning/IMPLEMENTATION.md
- sources/planning/architecture/2025-01-15-dsl-first-architecture.md
- sources/planning/architecture/2025-01-15-implementation-decisions.md
- sources/planning/adr/2025-01-15-full-introspection-p0.md
- sources/planning/adr/ADR-2026-01-16-restore-all-executor-functionality.md
- sources/planning/decisions/2026-02-03-remove-platform-database.md
- sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md
- https://github.com/misabegovic/usput.ba/pull/124
depends_on:
- architecture/overview.md
- architecture/ai-content-pipeline.md
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
    relations:
    - rel: depends-on
      to: wiki/architecture/overview.md
    - rel: depends-on
      to: wiki/architecture/ai-content-pipeline.md
---
# Platform DSL

"Platform" is the name the plans give to an autonomous AI brain for
Usput.ba. What exists in code today is narrower: a pipe-style query and
command language (the DSL) over the application's own models, run from a
Thor CLI (`bin/platform`) and a stdio MCP server (`bin/platform-mcp`).
Agents such as Claude Code call it directly. There is no built-in
conversation loop, no `Platform::Brain` and no knowledge layer. This page
describes what is implemented, then what the plans describe, then the gap.

## What the plans describe (Perceived)

`sources/planning/VISION.md` describes Platform as an autonomous agent with
three levels of awareness: content (locations, experiences, plans), its own
code, and its infrastructure. It generates content, finds bugs and prepares
fix prompts for a human to hand to Claude Code, but never writes code, runs
migrations or deploys by itself. It sketches a `Platform::Brain` with
reasoning, memory and action parts, interfaces through a CLI with `chat`
and `ask`, a REST API under `/api/platform/`, and MCP, plus storage for a
knowledge layer and prepared prompts. All generated Bosnian content is to
be checked for ijekavica before it is saved.

The DSL-first ADR of 2025-01-15
(`sources/planning/architecture/2025-01-15-dsl-first-architecture.md`)
chooses how that brain reaches data: the LLM writes queries in a
LogQL-inspired DSL, a parser and executor run them, and the LLM reasons over
structured results. It rejects "tools only" (does not scale past what fits
in context) and "pgvector first" (similarity without understanding). It
plans four knowledge layers: L0 stats and schema always in context, L1
AI summaries on demand, L2 semantic clusters in pgvector, L3 raw records by
indexed query. Its planned files are `brain.rb`, `conversation.rb`,
`dsl/parser.rb`, `dsl/executor.rb`, `dsl/grammar.rb` and
`knowledge/layer0..2.rb`.

The companion ADR on implementation decisions
(`sources/planning/architecture/2025-01-15-implementation-decisions.md`)
picks Parslet over Treetop, OpenAI `text-embedding-ada-002` for cluster
embeddings, on-demand cached summaries, an English DSL with Bosnian
conversation, friendly errors with technical detail on request, partial
commit for batch operations, and unit plus integration tests on fixtures.

The full-introspection ADR (`sources/planning/adr/2025-01-15-full-introspection-p0.md`)
moves code reading, log analysis, infrastructure monitoring and
"self-improvement" (`prepare fix for ...`, `prepare feature ...`,
`prompts | list`) from P2 into P0.

`sources/planning/IMPLEMENTATION.md` breaks this into 17 phases, from the
CLI and DSL foundation through knowledge layers 0 to 2, external data,
mutations, generation, audio, approval, curator management, introspection,
self-improvement, remote access (REST and MCP), a curator dashboard admin
mode, removal of the old admin dashboard, and polish. Every task checkbox
in that file is still unticked. Commit `497af8b` (#124, 2026-01-16) is
titled "[Platform] Complete Implementation (Phases 1-17)".

## What is implemented (Now)

**Entry points.** `bin/platform` boots Rails and starts `Platform::CLI`
(`lib/platform/cli.rb`), which has four commands: `status`, `version`,
`query` and `exec`. `exec` takes one query or a `--batch` file (one query
per line), prints JSON by default, and exits non-zero on parse or execution
errors. Both `query` and `exec` refuse to run in production unless
`PLATFORM_CLI_ENABLED=true`. `bin/platform-prod` loads `.env.local`,
requires `PROD_DATABASE_URL`, and runs `bin/platform` in development mode;
`config/database.yml` then points the primary connection at that URL.
`Platform.version` returns `0.1.0` (`lib/platform.rb`).

**Language.** `Platform::DSL.execute` parses a string with
`Platform::DSL::Parser` (built on the Parslet grammar in
`lib/platform/dsl/grammar.rb`) and hands the AST to
`Platform::DSL::Executor`. The grammar covers:

- `schema | stats`, `schema | describe <table>`, `schema | health`;
- table queries with filters and pipe operations, such as
  `locations { city: "Mostar" } | count` or
  `experiences | aggregate count() by city`, over the tables in
  `Executors::TableQuery::TABLE_MAP` (locations, experiences, plans,
  plan_experiences, audio_tours, users, reviews, translations, browse,
  curator_applications, content_changes);
- mutations: `create`, `update ... set { }`, `delete`;
- generation: `generate description for ...`, `generate translations for
  ... to [...]`, `generate experience from locations [...]`;
- audio: `synthesize audio for ...` with optional locale and voice,
  `estimate audio cost for ...`;
- curator work: `curators`, `block curator`, `unblock curator` (the
  `proposals`, `applications`, `approve` and `reject` commands were removed
  on 2026-09-30 with what they acted on);
- introspection: `code` (read_file, search, grep, structure, models,
  routes), `logs`, `infrastructure`;
- quality: `quality`, `validate location`, `validate experience from
  locations [...]`, `scan suspicious patterns`, `find duplicates for
  location`;
- `external` queries to Geoapify (geocode, reverse geocode, POI search,
  duplicate and location validation), paced by `Ai::RateLimiter`.

**Executor.** `Executor.execute` switches on the AST type and delegates to
seven modules under `lib/platform/dsl/executors/`: `Schema`, `TableQuery`,
`Infrastructure`, `Content`, `Curator`, `External` and `Quality`. It also
keeps a block of private delegation methods so older tests can reach module
internals through `send`.

**Content writes.** Creating a location requires coordinates, looks for an
existing location at the same fuzzy coordinates first, and goes through
`LocationCreator`; other records are saved with `ai_generated: true`
(`lib/platform/dsl/executors/content.rb`). Locations pass through
`ContentValidator`, which flags name patterns that often mean a
hallucinated place, duplicates, a Geoapify miss, coordinates outside BiH,
and known places in the wrong city (#141); if the validator itself raises,
creation is not blocked. Writes go straight to the tables, not through
curator proposals. Generation calls the LLM through `LLMHelper`
(`RubyLLM.chat` on the default model) with prompts built inline in the
executor, and audio calls `Ai::AudioTourGenerator`.

**MCP server.** `lib/platform/mcp_server.rb` speaks JSON-RPC over stdio,
protocol `2024-11-05`, server name `platform-mcp`. It refuses production
unless `PLATFORM_MCP_ENABLED=true`. It lists five tools
(`platform_execute`, `platform_status`, `platform_prompts`, `prepare_fix`,
`prepare_feature`), three resources (`platform://schema`,
`platform://prompts`, `platform://infrastructure`) and two prompts
(`analyze_location`, `city_report`). `platform_execute` is the tool that
does real work; the others build DSL strings and run them.

**Tests.** `test/lib/platform/` holds tests for the CLI, the DSL (parser,
grammar, executor, each executor module, mutations, generation, audio,
approval, curator, introspection, validator, content validator) and the
MCP server.

## The gap between plan and code

- **No brain, no conversation.** `lib/platform/brain.rb`,
  `conversation.rb`, `tools/` and `knowledge/` do not exist.
  `lib/platform.rb` itself says the components are the CLI and the DSL, and
  that agents call the CLI directly. The CLI has no `chat` or `ask`, yet the
  `@deprecated` note on `Ai::LocationEnricher` still tells readers to use
  `bin/platform chat`.
- **No knowledge layer, no pgvector, no prepared prompts.** The platform
  database that held `KnowledgeSummary`, `KnowledgeCluster`,
  `PreparedPrompt`, `PlatformAuditLog` and `PlatformStatistic` was removed
  on 2026-02-03, together with the `knowledge` and `prompts` executors,
  because agents used the CLI directly and none of it was read
  (`sources/planning/decisions/2026-02-03-remove-platform-database.md`).
  This reverses both the layered design of the DSL-first ADR and the
  self-improvement half of the introspection ADR, and the 2026-01-16 ADR
  that had restored those executors
  (`sources/planning/adr/ADR-2026-01-16-restore-all-executor-functionality.md`).
- **Dead MCP surface.** The grammar has no `prompts` or `prepare` rule and
  `TABLE_MAP` has no `prompts` table, so the `platform_prompts`,
  `prepare_fix` and `prepare_feature` tools and the `platform://prompts`
  resource return errors when called. Their tests stub `DSL.execute`, so
  the suite stays green (`test/lib/platform/mcp_server_test.rb`).
- **Leftover scheduling.** The development and test block of
  `config/queue.yml` still schedules `Platform::StatisticsJob`,
  `Platform::SummaryGenerationJob` and `Platform::ClusterGenerationJob`,
  which were deleted.
- **No REST API.** Phase 14's `api/platform/` controllers do not exist;
  `config/routes.rb` has no `/api` routes.
- **AI services are not yet behind the DSL.** The 2026-02-04 proposal to
  move `Ai::LocationEnricher`, `Ai::ExperienceTypeClassifier`,
  `Ai::AudioTourGenerator` and `Ai::ExperienceLocationSyncer` behind DSL
  operations such as `enrich`, `classify_experience_types` and
  `sync_locations` has status "proposed" and an empty approval list
  (`sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md`).
  Only audio synthesis is wired into the DSL today. See
  [AI content pipeline](ai-content-pipeline.md).
- **Stale pointers.** `PLATFORM.md` and the planning documents point to
  `.claude/planning/`, which no longer exists; the documents now live in
  `sources/planning/`.

## Target

The last written target is the 2026-02-04 migration plan: wrap each AI
service in a DSL executor, move rake tasks, jobs and controllers onto DSL
calls, split and batch the enricher, add deprecation warnings, document,
and remove the legacy services by Q4 2026. It has not been approved and no
executor from it exists (unverified, 2026-09-29, against any branch other
than `main`).
