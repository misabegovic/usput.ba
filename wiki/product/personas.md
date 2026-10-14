---
title: Personas
kind: reference
status: living
updated: 2026-10-14
repos:
- usput.ba
confidence: medium
sources:
- config/routes.rb
- app/models/user.rb
- app/controllers/concerns/authenticatable.rb
- app/controllers/concerns/records_visits.rb
- app/controllers/concerns/syncs_local_data.rb
- app/helpers/application_helper.rb
- app/controllers/plans_controller.rb
- app/controllers/plans/visits_controller.rb
- app/controllers/moments_controller.rb
- app/controllers/moments/likes_controller.rb
- app/controllers/reviews_controller.rb
- app/controllers/user_plans_controller.rb
- app/controllers/travel_profiles_controller.rb
- app/controllers/explore_bosnia_controller.rb
- app/controllers/curator/base_controller.rb
- app/controllers/curator/admin/base_controller.rb
- app/controllers/curator/locations_controller.rb
- app/avo/resources/moment.rb
- app/controllers/curator/reviews_controller.rb
- app/models/content_change.rb
- app/models/curator_application.rb
- app/services/guest_visits_importer.rb
- .claude/CLAUDE.md
- .claude/agents/content-director.md
- .claude/agents/curator.md
- .claude/agents/historian.md
- .claude/agents/guide.md
- .claude/agents/robert.md
- .claude/agents/audio-producer.md
- .claude/agents/developer.md
- .claude/agents/tech-lead.md
- .claude/agents/product-manager.md
- https://github.com/misabegovic/usput.ba/pull/166
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - repo
    - web
---
# Personas

Usput.ba has four human roles and a team of nine AI agent roles. The human roles come from one `User` model with a `user_type` of `basic`, `curator` or `admin`, plus the visitor who has no account (`app/models/user.rb`). The agent roles are prompt files under `.claude/agents/` that developers and content operators load into Claude sessions (`.claude/CLAUDE.md`, "Custom Agenti"). This page says what each role can do as of 2026-09-29. For the vocabulary used here, see [domain](domain.md).

## Human roles

### Anonymous visitor

A visitor without an account can use most of the traveller product.

- **Browse and search.** The home page, `/explore` (search across places, experiences, public plans and approved public moments) and the pages of individual locations, experiences and public plans are open to everyone (`config/routes.rb`; `app/controllers/new_design_controller.rb`).
- **Explore Bosnia deck.** `/explore-bosnia` deals places nearest first without a login. A guest has no plan to hang check-ins on, so the deck is dealt without one (`app/controllers/explore_bosnia_controller.rb`, comment in `experience`).
- **Plan wizard.** `/plans/wizard` builds a personalised plan with `POST /plans/generate` without saving it. The plan lives in the browser's localStorage and `/plans/view` renders it client-side (`app/controllers/plans_controller.rb`, `generate` and `view`).
- **Check in on the device.** Since 2026-09-15 a visitor can explore, walk and check in without registering. The walk lives on the device until there is an account (https://github.com/misabegovic/usput.ba/pull/166). The server check-in endpoint itself requires login (`app/controllers/plans/visits_controller.rb`, `before_action :require_login`), so a guest check-in is a device record only.
- **Read moments.** A place's moments can be read without a plan or login (`config/routes.rb`, `resources :moments, only: [ :index ]` under locations; `app/controllers/moments_controller.rb`, `except: :index`).
- **Read reviews.** Approved reviews are public. Writing one needs an account since 2026-10-14; the form asks a guest to sign in ([decision](../decisions/jev-decides-reviews.md)).
- **Maps, routes, audio.** The location map, route lookups (`/route`) and audio tours are public routes (`config/routes.rb`).
- **Mine safety.** The public mine check `/mine-check` and the Minolovac game `/minesweeper` are public (`config/routes.rb`).
- **Travel profile page.** `/profile` renders for everyone, filled from localStorage for guests (`app/controllers/travel_profiles_controller.rb`, `page`).

### Registered traveller (`basic` user)

Registering (`/register`) or signing in (`/login`) turns the device walk into server records. Both doors replay the plans and check-ins held on the device into ordinary rows (`app/controllers/concerns/syncs_local_data.rb`; `app/services/guest_visits_importer.rb`). A signed-in traveller can also:

- **Keep plans.** Create, update, delete and sync plans, share one with the community (make it public) and toggle its visibility (`app/controllers/user_plans_controller.rb`; `config/routes.rb`, `namespace :user`). The hidden Explore Bosnia plan is excluded from these actions (`user_plans_controller.rb`, comment above `set_plan`).
- **Check in.** A check-in is accepted within 100 m of the place (`app/controllers/concerns/records_visits.rb`, `MAX_VISIT_DISTANCE_KM = 0.1`). It is recorded once per traveller, plan and place, and there is no route to undo it (`config/routes.rb`, comment on `resources :visits`).
- **Capture moments.** Create, edit, delete, publish and unpublish moments on a plan (`config/routes.rb`, plan-nested `moments`; `app/controllers/moments_controller.rb`).
- **Like moments.** Liking requires a login (`app/controllers/moments/likes_controller.rb`, `before_action :require_login`).
- **Profile.** Upload or remove an avatar and see a paginated list of own plans and moments (`config/routes.rb`, `profile/*`).
- **Becoming a curator.** There is no application: an admin changes a traveller's role in the admin at `/admin` (`app/avo/actions/change_role.rb`). The public application page was removed on 2026-09-30.

### Curator

A curator works in the admin at `/admin`, which requires login and `can_curate?` (curator or admin) in the route and again inside Avo (`config/routes.rb`, `app/policies/admin_policy.rb`). The old `/curator` dashboard was removed on 2026-10-14 ([removal plan](../initiatives/remove-curator-dashboard.md)).

- **Edit content directly.** Curators create and edit places, experiences, plans and audio tours in the admin; only admins delete. The `ContentChange` proposals were removed on 2026-09-30.
- **Add photos.** Curators upload photos on the place in the admin; a filter lists places with few photos.
- **Archive and restore places.** Archiving is reversible and lands directly (`app/avo/actions/archive_location.rb`).
- **Moderate moments and reviews.** The admin's moments queue approves or rejects moments travellers chose to publish, and the reviews queue decides the reviews Jev held (`app/avo/resources/moment.rb`, `app/avo/resources/review.rb`).
- **Every decision is recorded** as an event in the record's stream in Rails Event Store ([decision](../decisions/rails-event-store.md)). The per-curator action limits and the `curator_edit_delete` flag went with the dashboard.

### Admin

An admin has every curator ability, and the admin's users page with role changes, blocks and unblocks (`app/avo/resources/user.rb`, `app/avo/actions/change_role.rb`, `block_user.rb`, `unblock_user.rb`).

- Delete content and remove reviews (`AdminPolicy#destroy?`).
- Read the event store at `/event-store`.
- Check in from anywhere. The geofence is disabled for admins so a walk can be reviewed from a desk (`app/helpers/application_helper.rb`, `geofence_disabled?`; https://github.com/misabegovic/usput.ba/pull/164).

## Agent roles (the AI team)

The `.claude/agents/` folder defines nine personas. Claude Code's Task tool does not load them as custom agents, so a prompt tells a general-purpose agent to read the persona file first (`.claude/CLAUDE.md`, "Kako koristiti agente u Task tool"). A multi-persona mode tags turns as [TL], [PM], [DEV], [CUR], [HIS], [GUI] and [ROB] (`.claude/CLAUDE.md`, "Multi-Persona Mode").

| Agent | Role | Source |
|-------|------|--------|
| Content Director | Main editor and quality guardian. Never creates new content while existing content is incomplete, never creates a place that does not exist in BiH, validates every item through the DSL, and requires a Bosnian description plus an English translation. Coordinates the curator, historian, guide and Robert. Marked as the main agent. | `.claude/agents/content-director.md`; `.claude/CLAUDE.md` |
| Curator | Content editor for balanced regional coverage and positive, diplomatic tone. Avoids politics, war and ethnic division. Reads the Knowledge Layer summaries first. | `.claude/agents/curator.md` |
| Historian | Historical context, facts and dates from the Illyrians on, avoiding controversial history after 1990. | `.claude/agents/historian.md` |
| Guide (Vodič) | Practical advice: parking, prices, opening hours, route planning, insider tips. | `.claude/agents/guide.md` |
| Robert | A warm, humorous storyteller inspired by Robert Dacešin, using local expressions. | `.claude/agents/robert.md` |
| Audio Producer | Audio tour scripts in Robert's style and speech synthesis, only for premium or special places. | `.claude/agents/audio-producer.md` |
| Developer | Implementation, tests, debugging, following the project's Rails patterns. | `.claude/agents/developer.md` |
| Tech Lead | Architecture decisions, code review, technical guidance (Rails, PostgreSQL, RubyLLM, DSL). | `.claude/agents/tech-lead.md` |
| Product Manager | Feature definition, user stories, acceptance criteria, prioritisation. | `.claude/agents/product-manager.md` |

The content agents (curator, historian, guide, audio producer) start by querying the Knowledge Layer through `bin/platform exec 'summaries ...'` (`.claude/agents/curator.md`, `.claude/agents/historian.md`, `.claude/agents/guide.md`, `.claude/agents/audio-producer.md`). The DSL is described in [architecture/platform-dsl.md](../architecture/platform-dsl.md).
