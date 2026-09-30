---
title: Product state
kind: reference
status: living
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- sources/planning/README.md
- sources/planning/IMPLEMENTATION.md
- sources/planning/VISION.md
- sources/planning/REVIEW_APPROVAL_SYSTEM.md
- sources/planning/decisions/2026-02-03-remove-platform-database.md
- sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md
- sources/planning/pr-151/rfcs/0001-curator-dashboard-v2.md
- docs/mine_checker/README.md
- config/routes.rb
- db/schema.rb
- lib/platform/cli.rb
- lib/platform/mcp_server.rb
- app/models/review.rb
- app/models/moment.rb
- app/models/location.rb
- app/services/ai/location_enricher.rb
- https://github.com/misabegovic/usput.ba/pull/154
- https://github.com/misabegovic/usput.ba/pull/168
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
# Product state

Where Usput.ba has been, what is true in the code today, what the older planning documents still believe, and where the next 90 days point. This page is the gap map: the distance from Now to Target is the work, and the distance from Now to Perceived is the risk. Git history in this clone is shallow (the earliest visible commit is 2f008b1 on 2026-01-15), so the earliest period is reconstructed from migrations and issue dates.

## Past

**2026-01-03 to 2026-01-14: the catalogue.** The first migrations (`db/migrate/20260103211108_create_locations.rb` onward) create locations, experiences, plans, translations, reviews, users, curator applications, audio tours, the denormalised `browses` search table and Flipper flags. The GitHub repository and its first issues date from 2026-01-07 (issue #2). Content changes (`content_changes`, `curator_activities`) arrive on 2026-01-09.

**2026-01-15 to 2026-01-21: the platform brain.** #123 moves planning into `.claude/planning/`. #124 (2026-01-16) lands "Complete Implementation (Phases 1-17)": a Thor CLI (`bin/platform`), a RubyLLM wrapper (`Platform::Brain`), conversations, a Parslet DSL with executor and validator, knowledge layers 0 to 2 with pgvector, and an MCP server. #126 and #127 split the platform tables into their own database. #133, #134 and #136 add content quality standards, TTS improvements and the BiH boundary check; #138 adds experience type classification; #141 adds DSL content validation against hallucinated places.

**2026-01-22 to 2026-02-04: the curator dashboard.** A burst on 2026-01-22 adds multi-photo `PhotoSuggestion` with direct upload (#143, #144), full content-change capture on curator forms (#146) and Turbo fixes. On 2026-02-03 the platform database is removed and the app consolidates on two databases (primary and Solid Queue), dropping the audit log, prepared prompts, statistics cache and knowledge layers (`sources/planning/decisions/2026-02-03-remove-platform-database.md`). #147 (2026-02-04) rebuilds the curator dashboard (card layout, dark mode, load-more) and deletes `Platform::Brain` and `Platform::Conversation`. #149 hides curator edit, delete and create actions behind the global `curator_edit_delete` Flipper flag.

**2026-02-05: a curator dashboard v2 proposal that did not land.** PR #151 proposes per-resource suggestion models, review moderation, audio tour generation from the dashboard and multiple video URLs. It is never merged; see [curator dashboard v2 salvage](initiatives/curator-dashboard-v2-salvage.md).

**2026-03-21 to 2026-03-25: accessibility.** Delaida Muminovic adds structured accessibility data on locations, a filter on explore and an option in the plan wizard (PR #154, commits 3f1e63d and 23188b1). It stays unmerged until September.

**2026-07-21: Mine Checker.** #157 adds a fail-closed internal mine-proximity check on every location save (PostGIS, EUFOR MICC / BHMAC-derived areas, 500 m buffer) plus the Minolovac minesweeper game. The owner approves a public `/mine-check` page on the same day, answering only in coarse bands (`docs/mine_checker/README.md`). #158 and #159 follow with a Rails 8.1.3.1 security update and bundled `tzinfo-data`.

**2026-09-15: the traveller features (#161 to #167).** #161 gives check-ins (`plan_visits`), moments and plan stops (`plan_locations`) tables of their own; a published moment goes to curator moderation. #162 adds position and route services, #163 a location map. #164 lets a traveller walk a plan as a stack of cards, check in within 100 m and capture a moment. #165 turns explore into a deck of places, nearest first. #166 allows exploring and checking in without an account and replays the walk on sign-in. #167 archives a place instead of deleting it and finishes wiring moments into Browse.

**2026-09-29: planning and accessibility catch up.** #152 merges the review approval plan (`sources/planning/REVIEW_APPROVAL_SYSTEM.md`). #154 is merged onto current main (d3be6c5), with a follow-up so a moment passes the accessible filter when its place does (abf62b0); both land through #168, merged the same day as 7955ae9, which also marks #154 itself merged.

## Now

- **Stack.** Rails 8.1 on PostgreSQL (PostGIS only offline, to build the Mine Checker's static artifacts, per `docs/mine_checker/README.md`), Hotwire, Tailwind, Solid Queue; two databases (`db/schema.rb`, `sources/planning/decisions/2026-02-03-remove-platform-database.md`).
- **Public product.** Home, explore (the Browse-backed search with filters for type, season, budget, duration, rating, city, origin, audio and accessibility), Explore Bosnia (a deck of places, nearest first), location, experience and plan pages, the plan wizard, walking a plan with check-ins, moments with likes, a travel profile that works without an account, reviews, `/mine-check` and the minesweeper game (`config/routes.rb`).
- **Curator dashboard.** Curators browse and propose changes to locations, experiences, plans and audio tours; proposals are `ContentChange` records that admins approve or reject under `curator/admin/content_changes`. Admins also approve photo suggestions, curator applications and users. Moments have a pending, approved, rejected queue (`Moment` enum `moderation_status`). Direct edit, delete and create buttons are hidden unless the global `curator_edit_delete` flag is on. Places are archived and restored rather than deleted.
- **Reviews are unmoderated.** `Review` has no status column; any visitor can post (the controller has no login requirement and still permits `author_name`), and every review counts toward `average_rating` (`app/models/review.rb`, `app/controllers/reviews_controller.rb`).
- **Platform CLI.** `bin/platform` offers `status`, `version`, `query` and `exec` for DSL queries; there is no `chat` command (`lib/platform/cli.rb`). Executors cover schema, table queries, content, curators, external data, infrastructure and quality. The MCP server exists (`lib/platform/mcp_server.rb`) and refuses to run in production.
- **AI content.** `Ai::LocationEnricher`, `Ai::ExperienceTypeClassifier`, `Ai::AudioTourGenerator` and `Ai::ExperienceLocationSyncer` call the LLM directly with prompts under `app/prompts/`. Audio tours are generated from rake tasks and DSL, not from the dashboard.
- **Accessibility.** Locations carry an `accessibility` JSONB (wheelchair level plus five features and notes); Browse rows carry `wheelchair_accessible`. See [location accessibility](initiatives/location-accessibility.md).

## Perceived

What the planning documents in `sources/planning/` still say, and where it no longer matches the code.

- **"Current phase: Phase 1, Core + DSL Foundation."** `.claude/CLAUDE.md` said this until the brain was set up on 2026-09-29, and `sources/planning/README.md` (last updated 2026-02-04) says phases 1 to 4 are complete and phase 5 is next. The commit history says #124 claimed all 17 phases on 2026-01-16. Neither is right: some phases shipped, several were built and later removed, and the product has since moved to traveller features no plan describes.
- **The 17 phases of `IMPLEMENTATION.md`, checked against the code:**
  - Done and still present: 1 in part (CLI, grammar, parser, executor, validator; `Platform::Brain` and `Platform::Conversation` were removed in #147), 5 (external data through `GeoapifyService` and the BiH boundary validator), 6 (content mutations through DSL, without the audit log), 7 and 8 (generation and audio synthesis through the content executor), 11 (`SpamDetector` behind curator DSL commands), 12 in part (infrastructure executor), 15 (admin features under `curator/admin`) and 16 (no separate admin dashboard remains).
  - Built and then removed on 2026-02-03: 2, 3 and 4 (knowledge layers 0 to 2 and pgvector) and 13 (prepared prompts).
  - Not present as planned: 10 (approval runs through the curator dashboard, not DSL commands), 14 (no REST API; MCP exists but is dev-only), 9 is a demonstration rather than code.
- **The conversational brain.** `VISION.md` describes Platform replacing the admin dashboard with a chat interface. There is no chat: the CLI runs single queries for agents, and `Ai::LocationEnricher` still carries a deprecation note pointing to `bin/platform chat`, which does not exist (`app/services/ai/location_enricher.rb`).
- **The MCP server still exposes prepared prompts.** `lib/platform/mcp_server.rb` offers `prepare_fix`, `prepare_feature` and a prompts listing that call DSL commands removed with `PreparedPrompt` on 2026-02-03; they would return errors (unverified, 2026-09-29).
- **AI services on the DSL.** `sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md` is still "Proposed"; the four services call the LLM directly.
- **ContentChange works.** The dashboard treats it as the proposal system and #161 extended it for plan stops, while the #151 RFC states it does not work in production (only photo suggestions do). This is unresolved and is the central decision in [curator dashboard v2 salvage](initiatives/curator-dashboard-v2-salvage.md).
- **Two review moderation designs.** `REVIEW_APPROVAL_SYSTEM.md` (pre-moderation) is merged; #151's ADR-0004 (post-moderation) is not. Neither is implemented.

## Target

Next 90 days (to about 2026-12-28), drawn from the open initiatives and issues. None of this is committed yet.

- **Rebuild usput from scratch** (decided 2026-09-30): in place on a long-lived branch, no backwards compatibility, an empty database, the old site up until launch. Version 1 is places and explore, plans and walking, reviews with Jev, and the AI content pipeline with Langfuse; admin in Avo, the curator area left out. The order and the open questions are on [initiatives](initiatives/index.md).
- **Earn from audio tours** (decided 2026-09-30): a subscription through Stripe, everything else free ([paid audio tours](initiatives/paid-audio-tours.md)).
- **Keep `roundhouse check` clean from the rebuild's first commit**, so compiling stays possible later ([Roundhouse](initiatives/roundhouse-analysis-and-compile.md)).
- **Bring the planning documents in line with the code**, so the Perceived list above shrinks: the brain pages under `wiki/` are meant to replace `.claude/planning/` as the working description.
