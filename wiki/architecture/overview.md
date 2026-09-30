---
title: Architecture overview
kind: reference
status: living
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
sources:
- Gemfile
- .ruby-version
- Dockerfile
- Procfile.dev
- config/deploy.yml
- config/database.yml
- config/queue.yml
- config/routes.rb
- config/importmap.rb
- config/storage.yml
- config/environments/production.rb
- config/environments/development.rb
- config/initializers/ruby_llm.rb
- config/initializers/flipper.rb
- config/initializers/rack_attack.rb
- config/ci.rb
- .github/workflows/ci.yml
- README.md
- CLAUDE.md
- sources/planning/DEVELOPER_ONBOARDING.md
- sources/planning/decisions/2026-02-03-remove-platform-database.md
depends_on:
- architecture/platform-dsl.md
- architecture/ai-content-pipeline.md
- architecture/mine-checker.md
- architecture/frontend.md
- architecture/conventions.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - other
    - repo
    relations:
    - rel: depends-on
      to: wiki/architecture/platform-dsl.md
    - rel: depends-on
      to: wiki/architecture/ai-content-pipeline.md
    - rel: depends-on
      to: wiki/architecture/mine-checker.md
    - rel: depends-on
      to: wiki/architecture/frontend.md
    - rel: depends-on
      to: wiki/architecture/conventions.md
---
# Architecture overview

Usput.ba is one Rails 8.1 monolith. It serves the public travel product
(explore, plans, walks, moments), the curator dashboard, the public mine
check, and a command line "Platform" that agents use to query and change
content. There is no separate API service and no JavaScript build step:
the browser gets Hotwire, Stimulus controllers and vendored libraries
through importmap. This page names the parts and how they depend on each
other. The deeper pages are [Platform DSL](platform-dsl.md),
[AI content pipeline](ai-content-pipeline.md),
[Mine Checker](mine-checker.md), [Frontend](frontend.md) and
[Conventions](conventions.md).

## Stack

| Layer | What is used | Where it is declared |
|-------|--------------|----------------------|
| Language | Ruby 3.3 (`.ruby-version` says 3.3.5, the Dockerfile builds 3.3.6) | `.ruby-version`, `Dockerfile` |
| Framework | Rails 8.1.3.1, pinned for a security release (#158) | `Gemfile` |
| Database | PostgreSQL through `pg`; full text search on a stored `tsvector` column of `browses` | `Gemfile`, `db/schema.rb` |
| Background jobs | Solid Queue on its own database; Solid Cache and Solid Cable are bundled | `Gemfile`, `config/queue.yml` |
| Web server | Puma behind Thruster | `Gemfile`, `Dockerfile` |
| Frontend | Turbo, Stimulus, importmap, vendored Leaflet 1.9.4 and markercluster 1.5.3 | `config/importmap.rb` |
| CSS | Tailwind CSS 4 through `tailwindcss-rails` and the standalone CLI | `Gemfile`, `Dockerfile`, `package.json` |
| LLM | RubyLLM, default model `gpt-4o-mini` unless `LLM_DEFAULT_MODEL` is set | `config/initializers/ruby_llm.rb` |
| Text to speech | ElevenLabs by default, OpenAI TTS as an alternative | `app/services/ai/audio_tour_generator.rb` |
| Files | Active Storage, S3 in production when `AWS_BUCKET` is set, disk otherwise | `config/storage.yml`, `config/environments/production.rb` |
| Images | `image_processing` over libvips (`libvips42` in the image, `libvips` in CI) | `Gemfile`, `Dockerfile`, `.github/workflows/ci.yml` |
| Feature flags | Flipper with the Active Record adapter, no web UI | `config/initializers/flipper.rb` |
| Errors | Rollbar | `Gemfile`, `app/jobs/application_job.rb` |
| Abuse control | rack-attack throttles and blocklists | `config/initializers/rack_attack.rb` |
| Geo | `geocoder`, Geoapify over Faraday, OpenRouteService for routes | `Gemfile`, `app/services/geoapify_service.rb`, `app/services/maps/route_fetcher.rb` |
| DSL | Thor for the CLI, Parslet for the grammar | `Gemfile`, `lib/platform/` |

The `neighbor` gem (pgvector) is still in the `Gemfile`, but `db/schema.rb`
enables no vector extension and has no vector column. The pgvector tables
lived in a third "platform" database that was removed on 2026-02-03
(`sources/planning/decisions/2026-02-03-remove-platform-database.md`).
`CLAUDE.md` and `sources/planning/DEVELOPER_ONBOARDING.md` still list
pgvector as part of the stack; that is stale.

## Databases

`config/database.yml` defines two databases per environment: `primary`
(application data, `klosaer_*`) and `queue` (Solid Queue, migrations in
`db/queue_migrate`). In development, setting `PROD_DATABASE_URL` points the
primary connection at production; `bin/platform-prod` uses exactly this to
run the Platform CLI against live data.

The job adapter is `inline` in development unless
`ACTIVE_JOB_QUEUE_ADAPTER` says otherwise, and `solid_queue` in production
(`config/environments/development.rb`, `config/environments/production.rb`).
`config/queue.yml` gives the `ai_generation` queue a single thread so LLM
calls respect the provider's token rate, and runs every other queue on a
shared pool. Its `default` block (used by development and test) still
schedules three recurring jobs, `Platform::StatisticsJob`,
`Platform::SummaryGenerationJob` and `Platform::ClusterGenerationJob`,
whose classes were deleted with the platform database. The production
block has no recurring section.

The cache store is `memory_store` in development and production, so
cached values (for example routes in `MapRoutesController`) live per
process.

## Deploy

The `Dockerfile` is the Rails 8 production template: a slim Ruby base with
jemalloc and libvips, a build stage that installs gems without the
`development`, `test` and `ci` groups, downloads the standalone Tailwind CLI
4.1.8 and precompiles assets, and a runtime stage that runs as user 1000
and starts `./bin/thrust ./bin/rails server` on port 80.
`bin/docker-entrypoint` runs `db:prepare` before the server starts.

`config/deploy.yml` is a Kamal file with a web role and a `job` role running
`bin/jobs`. Its server address (`192.168.0.1`) and registry
(`localhost:5555`) look like template placeholders, so the real production
host is not recorded in the repository (unknown, needs source).
`sources/planning/DEVELOPER_ONBOARDING.md` describes production as two
instances (web and workers) and two databases, deployed automatically on
every merge to `main` with no instant rollback. The CI workflow has no
deploy step, so that automation lives outside this repository (unknown,
needs source).

`Procfile.dev` runs two processes for `bin/dev`: `web` (Rails on port 3000)
and `css` (`tailwindcss:watch`).

## Continuous integration

`.github/workflows/ci.yml` runs on pull requests to `main` and on pushes to
`main`. One job starts a `postgres:15` service, installs `cmake`,
`libgit2-dev` and `libvips`, sets up Ruby from `.ruby-version` with the `ci`
gem group, creates `klosaer_test` and `klosaer_queue_test`, loads the
schema, then runs in order:

1. `bundle exec rubocop --parallel`
2. `bundle exec erb_lint --lint-all`
3. `bin/rails test` with `COVERAGE=true` (SimpleCov with an LCOV formatter)
4. `bundle exec undercover --compare origin/<base>` on pull requests only,
   with `continue-on-error: true` and a note to remove that once older
   coverage gaps are fixed.

`bin/ci` with `config/ci.rb` is a separate local pipeline: setup, rubocop,
bundler-audit, importmap audit, Brakeman, unit tests, system tests and a
seed replant. Brakeman, bundler-audit and system tests run only there, not
in GitHub Actions.

## The main parts and how they depend on each other

The request side has three audiences, all in `app/controllers/`:

- **Public travel product.** There is no `new_design/` controller folder
  (both `CLAUDE.md` and `README.md` say there is); there is one
  `NewDesignController` for the home page and `/explore`, plus
  `ExploreBosniaController` (the nearest-first deck),
  `PlansController` and `Plans::VisitsController` (the wizard and the walk),
  `MomentsController` and `Moments::LikesController`,
  `LocationsController`, `ExperiencesController`, `ReviewsController`,
  `TravelProfilesController`, `UserPlansController`,
  `MapRoutesController`, `UsersController` (avatars), the Devise
  controllers under `Users::` (sign-in, registration and the account page,
  password reset, confirmation, signing out other devices),
  `CuratorApplicationsController` and `PagesController`. Views for the new
  public design live in `app/views/new_design/`. Shared behaviour sits in
  concerns: `Authenticatable`, `Localizable`, `RecordsVisits` (the one
  check-in distance rule), `ServesMomentPhotos` and `SyncsLocalData`.
- **Curator dashboard** (`/curator`, `app/controllers/curator/`). Every
  controller inherits `Curator::BaseController`, which requires login,
  a curator role and a spam-block check, and renders the `curator` layout.
  `Curator::Admin::BaseController` adds an admin requirement for photo
  suggestion approval, users, curator applications and content change
  approval. Curators change content through `ContentChange` proposals that
  admins approve (`app/models/content_change.rb`). Edit and delete actions
  hide behind the `curator_edit_delete` Flipper flag (#149).
- **Mine safety.** `MineCheckPublicController` (`/mine-check`) and
  `MinesweeperController` (`/minesweeper`) read the static mine engine; see
  [Mine Checker](mine-checker.md).

Services in `app/services/` hold the logic the controllers call:

- `ai/` holds the LLM services (location enrichment, experience type
  classification, experience location sync, audio tours) and
  `Ai::OpenaiQueue`, the one wrapper around RubyLLM. See
  [AI content pipeline](ai-content-pipeline.md).
- `mine_checker/` holds the point and route checks.
- `maps/` holds `RouteFetcher` (OpenRouteService behind
  `MapRoutesController`) and `IpPosition` (city-level position from the IP
  for a deck without GPS). The browser side of position and routing lives in
  `app/javascript/services/position_service.js` and `route_service.js`
  (#162); see [Frontend](frontend.md).
- `geo/bih_boundary_validator.rb` tests coordinates against a BiH border
  polygon; `GeoapifyService` finds and describes places.
- `LocationCreator` and `LocationUpdater` wrap location writes that touch
  experience types; `BrowseAdapter` flattens locations, experiences, plans
  and moments into the `Browse` search table; `GuestVisitsImporter` replays
  a guest's device check-ins on sign-in (#166); `CameraPhoto` converts HEIC
  uploads to JPEG (#167); `VisitorIp` reads the real client address behind
  Cloudflare.

Models in `app/models/` centre on `Location`, `Experience` and `Plan` with
join models (`ExperienceLocation`, `PlanExperience`, `PlanLocation`),
translations in a polymorphic `Translation` table, `AudioTour`, `Review`,
`Moment`, `Like`, `PlanVisit`, `PhotoSuggestion`, `ContentChange`,
`CuratorApplication`, `CuratorActivity`, `Browse`, `AiGeneration`,
`MineCheckAudit`, `Setting` and `User`. `Location` validates every
coordinate change against the mine checker (`must_pass_mine_check`).

`lib/platform/` is the Platform DSL: a Parslet grammar, a parser, an
executor that dispatches to domain executors, a Thor CLI (`bin/platform`)
and a stdio MCP server (`bin/platform-mcp`). It reads and writes the same
models and calls the same AI services as the web app; it has no storage of
its own since 2026-02-03. See [Platform DSL](platform-dsl.md).

The dependency direction is therefore: controllers and the Platform DSL
both sit on top of services and models; services call external APIs
(LLM providers, ElevenLabs, Geoapify, OpenRouteService, ip-api.com);
`Location` depends on the mine checker at validation time; nothing in
`app/` depends on `lib/platform/`.

## Now and Perceived

- **Now:** two databases, one monolith, Hotwire frontend, CI with rubocop,
  erb_lint, tests and advisory undercover.
- **Perceived:** `CLAUDE.md`, `README.md` and
  `sources/planning/DEVELOPER_ONBOARDING.md` still describe pgvector, a
  `new_design/` controller namespace, and planning files under
  `.claude/planning/`, which no longer exists (the documents now live in
  `sources/planning/`). `config/queue.yml` still names deleted jobs. The Ruby
  version differs between `.ruby-version` and the `Dockerfile`.
