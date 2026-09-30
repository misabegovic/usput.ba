---
title: Roundhouse analysis and compile
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/avo-now-compile-later.md
- decisions/admin-through-avo.md
- initiatives/pgvector-semantic-search.md
sources:
- sources/analysis/2026-09-30--roundhouse-check.md
- sources/conversations/2026-09-30--usput--platform-direction.md
- Gemfile
- Gemfile.lock
- config/routes.rb
- config/application.rb
- config/storage.yml
- config/environments/production.rb
- config/deploy.yml
- db/schema.rb
- app/controllers/application_controller.rb
- app/controllers/plans_controller.rb
- app/models/location.rb
- app/models/browse.rb
- app/models/plan.rb
- app/models/concerns/translatable.rb
- app/jobs/openai_request_job.rb
- app/services/mine_checker/config.rb
- lib/platform/dsl/executors/table_query.rb
- .github/workflows/ci.yml
- https://github.com/rubys/roundhouse
- https://github.com/matz/spinel
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
      to: wiki/decisions/avo-now-compile-later.md
    - rel: depends-on
      to: wiki/decisions/admin-through-avo.md
    - rel: depends-on
      to: wiki/initiatives/pgvector-semantic-search.md
---
# Roundhouse analysis and compile

## Objective

Use Roundhouse now for what it does on an unmodified Rails app, static analysis, and keep compiling usput to one native binary with Spinel as a later goal whose blockers are listed and shrink on purpose. The operator wants to "compile usput and serve the optimized compilation", and chose "Avo and Postgres first": Roundhouse is analysis only until later ([Avo now, compile later](../decisions/avo-now-compile-later.md); `sources/conversations/2026-09-30--usput--platform-direction.md`).

## Background

**Roundhouse** (Sam Ruby, MIT or Apache-2.0, https://github.com/rubys/roundhouse) reads a Rails app without booting it and infers types from Rails' own conventions: which class an association returns, what a column deserializes to, whether a `find_by` can be nil. It offers that analysis three ways, and also transpiles an app to other languages or, through Spinel, compiles it.

- `roundhouse check --continue <app>` prints parse errors, analysis errors (a real finding, or the analyzer wrong), warnings (mostly coverage; `missing_preload` is a static N+1 finding naming the `.includes` that fixes it), notes attributed to Roundhouse's own gaps, a survey of constructs it skipped, and a gem census (framework, stdlib, modeled, infrastructure, unknown). Exit 0 means no parse or analysis errors; with `--continue` the check stays green while coverage grows and turns red only when findings change, which is what makes it a CI gate for an app that is not fully covered.
- `roundhouse mcp <app>` serves the same analysis to a coding agent: `type_at`, `can_be_nil`, `references`, `diagnostics`, `traceroute` (the full static request flow of an action, filters in order, views and partials), `trace_targets`, `related_files`, `gems` and `wont_lower`.
- Its README and WHY page are direct: "Roundhouse is not ready for production use today".

**Spinel** (Matz, https://github.com/matz/spinel) is an ahead-of-time Ruby compiler: whole-program type inference, C output, one native executable with no interpreter. Its limitations page lists what an AOT compiler cannot do: `eval` of strings, `method_missing`, `define_method` with a runtime-computed name, `ObjectSpace`, `TracePoint`. Its first dated release is 2026.09.12. Roundhouse's Spinel lane runs the framework runtime itself, compiled, and passes against Basecamp's Campfire.

**Survey results (2026-09-30).** `roundhouse check --continue` read today's app in 3.9 seconds: 0 parse errors, 243 errors, 2,263 warnings and 55 survey gaps of 7 kinds ([snapshot](../../sources/analysis/2026-09-30--roundhouse-check.md)). Most of the 243 errors are gaps in what Roundhouse models rather than bugs (`Review.average`, has-many-through id readers, an Active Storage variant's `download`), concentrated in the explore view, `NewDesignController` and `ContentChange`. The four `missing_preload` warnings are real N+1 queries: two in the curator photo suggestions screen and two on the experience page reading place photos. The survey gaps sit mostly in the Platform DSL (global variable writes in its tests, backtick shell strings, `defined?` on constants), plus a `virtual` column on `browses`, the `protect_from_forgery` macro in `UserPlansController` and a non-literal `only:` on moments' routes. Of 46 gems, 13 are unknown to it: better_html, erb_lint, faraday, faraday-follow_redirects, flipper, flipper-active_record, geocoder, neighbor, parslet, rollbar, ruby_llm, rubyzip and undercover. For a rebuild the lesson is to keep `check` clean from the first commit rather than to clean up this baseline.

**The rebuild changes the question.** The operator decided on 2026-09-30 to rebuild usput in place, with new content and an empty database. A rebuild can choose, from its first commit, to stay inside what Roundhouse analyzes cleanly, so the analysis gate is cheap to hold. It cannot stay inside what compiles, because two choices already made sit outside it: Postgres (with pgvector) and Avo.

## Affected personas

- Developers and agents: types, nil-safety, N+1 findings and request traces without booting the app.
- The operator: a measured list of what stands between usput and a compiled deployment.
- Travellers: only later, through a faster, cheaper server if compiling ever lands.

## Scope

Phase 1, now: analysis.

1. **Survey.** Run `roundhouse check --continue` on `main` and record the counts, the survey gaps and the unknown gems here. Pending, as above.
2. **Agent access.** A checked-in MCP configuration so agents working on the rebuild can ask `traceroute` and `diagnostics`. Roundhouse must be installed on the machine; without it the server is simply absent.
3. **Report in CI.** A workflow step that installs a pinned Roundhouse release and runs `check --continue`, reporting without failing. CI today runs rubocop, erb_lint, tests and undercover (`.github/workflows/ci.yml`).
4. **Gate in CI.** Once the rebuild's own code checks with zero errors, the step fails on new errors. `missing_preload` findings are fixed as they appear.

Phase 2, later: what blocks compiling usput today, checked against the Roundhouse guide's coverage page and usput's code.

- **Postgres-specific SQL.** Roundhouse's compiled targets and its Spinel lane use SQLite. usput queries JSONB with `@>` on tags, seasons, category keys and plan preferences (`app/models/location.rb`, `app/models/browse.rb`, `app/models/plan.rb`), `->>` on accessibility (`app/models/location.rb`), and the `?|` operator on suitable experiences (`app/controllers/plans_controller.rb`); `browses.searchable` is a stored generated `tsvector` ranked with `ts_rank` (`db/schema.rb`). pgvector adds vector columns and an HNSW index ([pgvector semantic search](pgvector-semantic-search.md)). Postgres is settled for the rebuild, so this is a consequence to carry, not a choice left open.
- **Active Storage on S3.** Production stores files on S3 when `AWS_BUCKET` is set (`config/environments/production.rb`, `config/storage.yml`). The compiled path supports the disk service only, "no cloud services". Image variants through libvips are supported on Spinel.
- **Solid Queue.** Active Job runs on an in-process queue on the compiled path, "no external queue adapter". usput runs Solid Queue with its own database and a job host running `bin/jobs` (`Gemfile`, `config/deploy.yml`).
- **Unmodeled gems.** The census models bcrypt, image_processing, importmap, turbo, stimulus, tailwindcss, jbuilder and propshaft among usput's gems. `ruby_llm`, `faraday`, `aws-sdk-s3`, `flipper`, `parslet`, `neighbor` and `geocoder` are not modeled (`Gemfile`), so calls into them cannot be typed or compiled.
- **Avo is a mounted engine.** Routing supports mounting only Active Storage's engine, "not `mount` of any other engine". Avo is adopted now ([admin through Avo](../decisions/admin-through-avo.md)), so the admin does not compile.
- **Credentials.** Roundhouse does not read `Rails.application.credentials`; Mine Checker reads its secrets from there (`app/services/mine_checker/config.rb`).
- **Metaprogramming.** `Translatable` defines accessors with `define_method` over runtime field and locale names (`app/models/concerns/translatable.rb`); jobs and content changes resolve classes with `constantize` (`app/jobs/openai_request_job.rb`); the Platform DSL dispatches with `send` on computed names and `constantize` (`lib/platform/dsl/executors/table_query.rb`). None of these lower.
- **The Platform DSL.** `lib/platform/**` is a Parslet grammar, a parser and executors that build queries from strings at runtime. It is the least compilable part of the app.
- **CSRF.** On the compiled lanes only a written `protect_from_forgery with: :exception` is enforced; Rails' implicit default is not applied. `ApplicationController` writes no such line (`app/controllers/application_controller.rb`), relying on `load_defaults 8.0` (`config/application.rb`), so a compiled usput would not be protected. The rebuild writes it explicitly.

## No-gos

- No compiled deployment of usput while Roundhouse says it is not production-ready.
- No design choice in the rebuild made only to compile, against a decision already taken (Postgres, pgvector, Avo, S3).
- No Roundhouse step that blocks CI before the rebuild's code checks clean.

## Rabbit holes

- **Moving toolchains.** Roundhouse and Spinel release dated snapshots and move quickly; a pinned pair is the only reproducible one.
- **Gap noise.** On a large app most output is coverage, not findings; read the census and the errors first.
- **Split deployment.** Serving a compiled traveller site beside Avo on CRuby with one database is deferred by the ADR, and only makes sense once the compiled path supports Postgres and S3.

## Appetite

Phase 1 is small: a survey, a config file and a CI step. Phase 2 is not sized; it waits on Roundhouse, not on usput. Calendar time is (unknown, needs source).

## Decision needed

- **Whether the rebuild holds a zero-error `roundhouse check` from its first commit**, with the gate turned on early, or reports only until launch.
- **Which compile blockers the rebuild removes anyway because they are cheap** (the explicit CSRF line, credentials read through one config object, no `define_method` translation accessors, no string-to-class dispatch), and which stay because a decision needs them (Postgres, pgvector, S3, Solid Queue, Avo).
- **The tension, recorded for when compiling comes back**: pgvector needs Postgres while Roundhouse's compiled path documents SQLite, and Avo is an engine Roundhouse does not mount. Compiling usput means either Roundhouse growing Postgres, cloud storage and engine support, or a split deployment.
