---
title: Enola for usput
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- architecture/overview.md
- decisions/admin-through-avo.md
- decisions/avo-now-compile-later.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- brain.config.yml
- AGENTS.md
- .github/workflows/ci.yml
- config/routes.rb
- app/controllers/curator/base_controller.rb
- app/models/content_change.rb
- app/models/user.rb
- lib/platform/dsl/executors/curator.rb
- lib/platform/dsl/executors/table_query.rb
- lib/platform/dsl/executors/infrastructure.rb
- lib/platform/dsl/executors/content.rb
- app/services/ai/openai_queue.rb
- app/services/mine_checker/point_check.rb
- app/controllers/mine_check_public_controller.rb
- https://github.com/enola-labs/enola
---
# Enola for usput

## Objective

The rebuild of usput is graded by what the code does, not by what anyone remembers it doing. An architecture page names usput's parts and the laws between them; enola, a deterministic architecture graph, measures the code against those laws; and a baseline pinned before the rebuild starts deleting lets each deletion show up as progress, and each new coupling as a regression. The operator asked to "use enola there" and chose to rewrite in place, piece by piece, deleting as the rebuild goes (`sources/conversations/2026-09-30--usput--platform-direction.md`).

## Background

**What enola is.** Enola (Go, Apache-2.0, https://github.com/enola-labs/enola) snapshots a repository into facts: modules, symbols, routes, storage and the calls and imports between them. A snapshot writes a receipt; a baseline freezes one snapshot so that a later change can be checked against it; `check` reports findings introduced or resolved. Declared constraints are rules over parts of the code (who may call whom, what must stay empty), and a check reports each breach as new or old against the baseline. It reads code and never runs it. The operator runs it from their own machine, where its conventions are written down in their private brain; nothing from there is cited here, since usput is public.

**What tabula adds.** The `tabula` tool that runs this brain has two verbs for it. `tabula architecture <page>` compiles a page of `kind: architecture` into enola constraints and a Mermaid graph, and with `--write` writes them into a repository `brain.config.yml` lists as active, which is `usput.ba` (`brain.config.yml`). Laws on that page are one sentence each, from six written forms: "A never calls B.", "A never reaches B, even indirectly.", "A only calls B and C.", "Only B and C call A.", "A has at most N members, growing by at most M." and "A stays empty.", with calls, imports, depends on, inherits from or includes as the verb. No strength word means ratchet (new breaches fail, old ones are kept), ", as a warning." is advisory and ", without exception." is strict, and every law needs a `because:`. `tabula distance <page>` then says how far the page stands from the code in four buckets: broken (standing breaches), absent (planned parts or arrows with no code), divergent (code no part admits) and not asked (no engine, no facts, or too little resolved to measure); `--write` keeps a dated file under `wiki/_state/distance/` and `--against` compares with an earlier one.

**Where things run.** Enola is not installed in usput's CI: the workflow runs rubocop, erb_lint, the test suite and undercover only (`.github/workflows/ci.yml`), and there is no `.enola/` directory in the repository. Every enola step is therefore run by the operator or an agent on a machine with enola installed, and when it is absent the step says "not asked" rather than passing. That is the rule tabula already follows, and it stays the rule here.

**The parts today, from the code.**

- **Traveller web**: public controllers and views (explore, places, experiences, plans, walking, moments, reviews, travel profile, sessions) in `app/controllers/` outside `curator/`, per `config/routes.rb`.
- **Curator and admin**: `app/controllers/curator/**` with its views, and the proposal models `ContentChange` and its contributions, photo suggestions and curator applications. In the rebuild this part is removed and admin work moves to Avo ([admin through Avo](../decisions/admin-through-avo.md)).
- **Platform DSL**: `lib/platform/**`, the Parslet DSL, its executors, CLI and MCP server.
- **AI services**: `app/services/ai/**` and `app/prompts/**`.
- **Mine Checker**: `app/services/mine_checker/**`, the public check and the minesweeper game.
- **Models**: `app/models/**`.

Two facts from a grep on 2026-09-30 show what the laws would see. No controller names an `Ai::` class today, so "traveller web never calls AI" already holds. `ContentChange` is referenced outside the curator area by `User`, by three Platform DSL executors (curator, table query, infrastructure) and by its own models (`app/models/user.rb`, `lib/platform/dsl/executors/*.rb`), so a law confining it starts with old breaches that the removal should close one by one.

## Affected personas

- The operator and agents doing the rebuild: a measured answer to "did this slice move us closer or add coupling".
- Reviewers of the rebuild branch: a distance report per merge instead of a reading of the whole diff.
- Travellers: none directly.

## Scope

Slices, each a small pull request (the brain slices are pages; the code slices carry their tests):

1. **Architecture page.** A `kind: architecture` page under `wiki/architecture/` naming the six parts above by glob, with Avo's resources as the admin part's future home. `tabula validate` passes; `tabula architecture` compiles it without `--write`.
2. **Laws**, each with its because and its deciding page:
   - "traveller-web never calls ai." Generation runs in jobs and admin actions, never inside a traveller's request.
   - "mine-checker never calls ai, without exception." Safety answers come from mapped data alone ([mine data from EUFOR maps](../decisions/mine-data-from-eufor-maps.md)).
   - "Only curator calls content-change." Nothing outside the curator area touches proposals while they still exist; the old breaches are the removal's to-do list.
   - "curator stays empty." Added when the removal starts, as a ratchet dated that day, so the part can only shrink.
   - "traveller-web never calls platform-dsl." The DSL is a tool for agents and admins.
3. **Baseline before the removal.** On `main`, before the rebuild branch deletes anything: an enola snapshot of usput, the compiled constraints written into the repository, the baseline pinned, and `tabula distance --write` kept as the starting file.
4. **Grade each deletion.** Each rebuild merge that removes a piece runs `tabula distance --against` the starting file; closed breaches and the shrinking curator part are recorded on the rebuild's page, and any new breach is fixed before the merge.
5. **Avo and the new parts.** When Avo resources and the RubyLLM seam land, the page gains their parts and the law "Only admin and jobs call ai." replaces the first one.
6. **CI, later and optional.** If enola is ever installed in CI, `check` runs as a report that never fails the build, and says "not asked" when it cannot compare.

## No-gos

- No enola step that fails CI or blocks a merge; findings are read by a person.
- No single-repository shortcut that overwrites a shared fact store: usput's facts live in its own `.enola/`, uncommitted.
- No law without a because and a deciding page.
- No claim on a brain page from a graph finding that has not been confirmed in the code.

## Rabbit holes

- **Resolution.** A law over calls Enola cannot resolve (dynamic `send`, `constantize`, Parslet rules) reads as "checked over nothing". The Platform DSL uses both (`lib/platform/dsl/executors/table_query.rb`), so some laws may measure little there.
- **Views.** ERB views call helpers and models; how much of that enola's Ruby extraction sees is (unknown, needs source).
- **Engine versions.** A baseline taken with one enola version may not compare with a snapshot from another; the remedy is to re-pin, and a failed comparison is not a pass.
- **Branch length.** The rebuild lives on a long branch that merges at launch; the baseline belongs to `main`, and the branch's snapshots are compared against it, not against each other.

## Appetite

Small: slices 1 to 3 are a day of brain work plus one enola run; slice 4 rides on every rebuild merge; 5 and 6 come later. Calendar time is (unknown, needs source).

## Decision needed

- **The law set**: which of the five laws above to declare, and how strict each is.
- **Whether the rebuild's own page links a distance file per merge**, or only at milestones.
- **Whether enola ever runs in CI** as a non-blocking report, which means installing it in the workflow.
