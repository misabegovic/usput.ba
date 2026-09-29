---
title: Personas
kind: reference
status: living
updated: 2026-09-29
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
  - app/controllers/curator/moments_controller.rb
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
- **Write reviews.** Reviews of locations, experiences and plans need no login. The form takes a rating, a comment and an `author_name` (`app/controllers/reviews_controller.rb`, no `require_login`; `review_params`).
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
- **Apply to curate.** `/become-curator` explains the role and a `CuratorApplication` needs a motivation of 50 to 2000 characters. Only a basic user without a pending application may apply (`app/models/user.rb`, `can_apply_for_curator?`; `app/models/curator_application.rb`).

### Curator

A curator reaches the `/curator` dashboard. Its base controller requires login and `can_curate?` (curator or admin), and it stops users who are spam-blocked (`app/controllers/curator/base_controller.rb`; `app/controllers/concerns/authenticatable.rb`, `require_curator`).

- **Propose content changes.** Creating, editing or deleting a location, experience, plan, audio tour or review does not write directly. It creates or joins the one pending `ContentChange` for that record (`app/controllers/curator/locations_controller.rb`, `create`, `update`, `destroy`; `app/models/content_change.rb`, `CHANGEABLE_CLASSES`). Several curators can contribute to one proposal (`ContentChangeContribution`).
- **Review proposals.** Curators add a comment and a recommendation to a proposal (`config/routes.rb`, `proposals#add_review`; `CuratorReview` in [domain](domain.md)).
- **Suggest photos.** Up to 10 photos per suggestion, or a URL, for a location (`app/models/photo_suggestion.rb`). A "needs photos" list sorts places by photo count (`curator/locations_controller.rb`, `needs_photos`).
- **Archive and restore places.** Archiving is reversible, so it lands directly instead of through a proposal (`curator/locations_controller.rb`, comment above `archive`).
- **Moderate moments.** The moderation queue lets a curator approve or reject moments that travellers chose to publish (`app/controllers/curator/moments_controller.rb`).
- **Limits.** A curator is blocked for 24 hours after 50 actions in an hour or 200 in a day (`app/models/user.rb`, `MAX_ACTIVITIES_PER_HOUR`, `MAX_ACTIVITIES_PER_DAY`, `SPAM_BLOCK_DURATION`). Edit, delete and new buttons on some list and show pages sit behind the Flipper flag `curator_edit_delete` (`app/views/curator/locations/index.html.erb`; https://github.com/misabegovic/usput.ba/pull/149).

### Admin

An admin has every curator ability plus the `curator/admin` namespace, which requires the admin role (`app/controllers/curator/admin/base_controller.rb`).

- Approve or reject content changes, photo suggestions and curator applications (`config/routes.rb`, `namespace :admin`). Approving an application turns the user into a curator (`app/models/curator_application.rb`, `approve!`).
- List, view and edit users, and lift a spam block (`config/routes.rb`, `admin/users#unblock`; `app/models/user.rb`, `admin_unblock!`).
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
