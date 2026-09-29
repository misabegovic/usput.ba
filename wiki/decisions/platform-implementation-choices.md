---
title: Platform implementation choices
kind: decision
status: accepted
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/dsl-first-platform-architecture.md
sources:
- sources/planning/architecture/2025-01-15-implementation-decisions.md
- Gemfile
- lib/platform/dsl/parser.rb
- lib/platform/cli.rb
- test/test_helper.rb
- db/schema.rb
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - repo
    relations:
    - rel: depends-on
      to: wiki/decisions/dsl-first-platform-architecture.md
---
# Platform implementation choices

## Context

Before implementation of the [DSL-first architecture](dsl-first-platform-architecture.md) began, the PM, Tech Lead and Product Owner settled seven technical and product questions in a question and answer session on 2025-01-15. The original record is `sources/planning/architecture/2025-01-15-implementation-decisions.md`.

## Decision

1. Parser: the Parslet gem. It is pure Ruby, easier to debug, needs no separate grammar files, and suits iterative work; the grammar is not complex enough for parser speed to matter.
2. Embeddings: OpenAI `text-embedding-ada-002` for Layer 2 clusters, because it is proven, simple and cheap (about $0.10 per million tokens), with self-hosting possible later.
3. Summary refresh: Layer 1 summaries are generated on demand and cached, since nobody knows in advance which summaries will be useful.
4. Language: the DSL syntax is English; the Platform talks to the admin in Bosnian.
5. Errors: friendly messages by default, technical detail (the query, the error position) on request.
6. Batch failures: partial commit. Successful items are kept, failures are reported, and the Platform offers to retry the failed ones.
7. Tests: unit and integration tests, fake fixtures in CI, an optional production dump for local work.

## Alternatives

- Parser: Treetop (a PEG parser with separate grammar files).
- Embeddings: Voyage AI multilingual, or self-hosted sentence-transformers.
- Summary refresh: hourly, daily, or a hybrid schedule.

## Consequences

Developers got one set of rules for the whole Platform, recorded for later reference.

## Status notes

Checked against the code on 2026-09-29, item by item:

- Parslet: holds. `Gemfile` pins `parslet` (2.0.0 in `Gemfile.lock`) and `lib/platform/dsl/parser.rb` uses it.
- Embeddings and summary refresh: no longer apply. Both served the knowledge layers that [remove-platform-database](remove-platform-database.md) deleted on 2026-02-03; no embedding code remains under `app/` or `lib/`.
- English DSL: holds. Bosnian output holds in part: `lib/platform/cli.rb` prints Bosnian messages, but the conversational layer that would translate results was removed in #147.
- Partial commit: batch mode in `lib/platform/cli.rb` (`execute_batch`) records per-query parse and execution errors and continues, which matches the spirit.
- Tests: `test/test_helper.rb` loads `fixtures :all`, but `test/fixtures/` holds only image files, so tests build their own records (unverified, 2026-09-29).
