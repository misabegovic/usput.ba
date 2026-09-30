---
title: pgvector semantic search
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/remove-platform-database.md
- decisions/avo-now-compile-later.md
- initiatives/rubyllm-2-upgrade.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- Gemfile
- Gemfile.lock
- db/schema.rb
- app/models/browse.rb
- app/services/browse_adapter.rb
- app/controllers/new_design_controller.rb
- config/application.rb
- config/database.yml
- config/deploy.yml
- .github/workflows/ci.yml
- sources/planning/decisions/2026-02-03-remove-platform-database.md
- https://github.com/misabegovic/usput.ba/pull/126
- https://github.com/ankane/neighbor
- https://github.com/pgvector/pgvector
enola_intent:
  page:
    type: initiative
    status: proposed
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/decisions/remove-platform-database.md
    - rel: depends-on
      to: wiki/decisions/avo-now-compile-later.md
    - rel: depends-on
      to: wiki/initiatives/rubyllm-2-upgrade.md
---
# pgvector semantic search

## Objective

A traveller finds places, experiences, plans and moments by what they mean, not only by the words they share: "quiet place by the water" finds a lakeside monastery whose description never says "quiet". Every result card offers "similar places". Search works the same whether the traveller types Bosnian or English. The operator put "places and explore (with pgvector search)" in version 1 of the rebuild and settled on "Avo and Postgres first" (`sources/conversations/2026-09-30--usput--platform-direction.md`).

## Background

**Today there is no vector search.** The `neighbor` gem (0.6.0) is in the Gemfile under the comment "Vector similarity search with pgvector" (`Gemfile`, `Gemfile.lock`), but nothing in `app/`, `lib/` or `test/` uses it, and `db/schema.rb` enables only `plpgsql`: no `vector` extension and no vector column. pgvector lived in the separate platform database (PR #126 added it there on 2026-01-16, "PostgreSQL with pgvector extension") and left with it on 2026-02-03, when a usage review found the knowledge layers unused and keyword search sufficient ([remove the platform database](../decisions/remove-platform-database.md)).

**Browse is the search index.** Places, experiences, plans and moments each have one denormalised `browses` row carrying a title, a composed description, city, coordinates, rating, budget, seasons, category keys and accessibility (`db/schema.rb`). `BrowseAdapter` composes the description: for a place its description, historical context, tags, category and city; for a moment its note, its place's name, tags and city, and the author's username (`app/services/browse_adapter.rb`). A stored generated `tsvector` column weights the title A and the description B under the `simple` configuration, with a GIN index. `Browse.smart_search` runs `plainto_tsquery` ranked by `ts_rank`, and falls back to `ILIKE` on title and description when that finds nothing (`app/models/browse.rb`). Explore calls `smart_search` and then applies filters (`app/controllers/new_design_controller.rb`). The app is configured for sixteen locales (`config/application.rb`).

What keyword search cannot do today: match synonyms or paraphrase, cross languages (a Bosnian description does not match an English query), or rank "similar" other than by distance through `Browse.nearby`.

**Production database: pgvector support is (unknown, needs source).** PR #126's message says the primary database was "Railway PostgreSQL" and asked for a separate database "with pgvector extension", which suggests the primary did not have it at the time (unverified, 2026-09-30). `config/deploy.yml` is the Kamal template with placeholder hosts, and `DATABASE_URL` is a secret (`config/deploy.yml`, `config/database.yml`), so where the rebuilt app's database will run is not recorded. CI runs on the `postgres:15` image (`.github/workflows/ci.yml`), which does not ship pgvector; the tests would need an image that does.

**Settled constraint.** Postgres is the rebuild's database, so pgvector is available wherever the host allows the extension. Roundhouse's compiled path documents SQLite ([Avo now, compile later](../decisions/avo-now-compile-later.md)); vector search is one more thing a future compile would have to answer, and is recorded in [Roundhouse analysis and compile](roundhouse-analysis-and-compile.md).

## Affected personas

- Travellers: explore and search find by meaning, in their language, with "similar places".
- Admins: new or edited content becomes findable once it is embedded; they see when embedding failed.
- Moment authors: if moments' notes are embedded, their words go to the embedding provider.

## Scope

The design: one `embedding` vector column on `browses`, not one per model, because Browse is already the single index every search reads and every model already syncs into it. The embedded text is the row's title and composed description. Embeddings come from the one RubyLLM seam ([RubyLLM 2 in the rebuild](rubyllm-2-upgrade.md)), with the model name and a digest of the embedded text stored beside the vector so a changed text or model is re-embedded and an unchanged one is not. An HNSW index with cosine distance serves nearest-neighbour queries (pgvector's HNSW indexes `vector` columns of up to 2,000 dimensions, https://github.com/pgvector/pgvector). Search ranks by combining the full-text rank and the vector rank (reciprocal rank fusion), so exact names still win and meaning fills the rest. The rebuild starts with an empty database, so there is no backfill of old content: every row is embedded when it is written.

Slices, each a small pull request with its tests:

1. **The extension.** A migration enabling `vector`, and CI moved to a Postgres image with pgvector. Test: the schema loads in CI.
2. **The column and index.** `embedding` (dimension fixed by the model decision), `embedding_model` and `embedding_digest` on `browses`, the HNSW index, and `has_neighbors` from the `neighbor` gem (https://github.com/ankane/neighbor). Tests on the model.
3. **Embed on write.** When a Browse row's embedded text changes, a Solid Queue job embeds it through the seam; a missing key or a provider error leaves the row searchable by keyword only and records the failure. Tests with a stubbed embedding.
4. **Hybrid search.** `smart_search` becomes full-text plus vector with rank fusion; with no embedding for the query (no key, provider down) it is exactly the keyword search. The query is embedded once per request. Tests on ranking with fixed vectors.
5. **Similar places.** A "similar" list on each place, experience and plan: nearest neighbours of the row's own vector, same type, excluding itself, optionally within a radius. Tests with fixed vectors.
6. **Cross-language check.** A small fixed set of Bosnian and English queries with the places they should find, run as a test against recorded vectors, so a model change that breaks cross-language search fails.
7. **Moments**, only if the decision below says so: their notes join the embedded text under the same rules as their visibility.

## No-gos

- No vector column per model and no second search table.
- No backfill job for old content; the rebuilt app starts empty.
- No semantic search that replaces full text: exact names and places must keep ranking first.
- No embedding of review text in version 1; reviews are screened by Jev, not searched.

## Rabbit holes

- **Which locale is embedded.** Browse rows hold one description while content exists in many locales. One embedding of the Bosnian or English text may serve both languages if the model is multilingual (unverified, 2026-09-30); one embedding per locale multiplies rows and cost.
- **Dimension.** Larger vectors cost storage and index memory; some embedding models can return fewer dimensions. Fix it once, since changing it re-embeds everything.
- **Cost.** Every write and every search query is an embedding call; the price per token for the chosen model is (unknown, needs source). Cache query embeddings for repeated searches.
- **Filters after the index.** HNSW returns the nearest rows first, then filters (city, season, accessibility) can leave too few; pgvector's iterative scan settings are the knob (unverified, 2026-09-30).
- **Hosting.** If the production Postgres host cannot enable `vector`, the whole initiative waits on a database move.

## Appetite

Medium: slices 1 to 4 are the version 1 search; 5 and 6 follow; 7 depends on the decision. Calendar time is (unknown, needs source).

## Decision needed

- **Embedding model and provider**, which fixes the dimension, the cost and how well Bosnian works.
- **Whether moments' notes are embedded.** They are user text: embedding them sends them to the provider (and to Langfuse, if content capture is on), and they may describe people. Leaving them out keeps moments findable by their place.
- **Where the production Postgres runs**, and confirmation that it allows the `vector` extension.
