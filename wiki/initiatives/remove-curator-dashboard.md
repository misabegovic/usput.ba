---
title: What the rebuild leaves out, the curator dashboard
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/admin-through-avo.md
- initiatives/avo-admin-and-roles.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- config/routes.rb
- db/schema.rb
- app/controllers/curator/base_controller.rb
- app/controllers/curator_applications_controller.rb
- app/controllers/concerns/authenticatable.rb
- app/models/content_change.rb
- app/models/content_change_contribution.rb
- app/models/curator_review.rb
- app/models/curator_activity.rb
- app/models/photo_suggestion.rb
- app/models/curator_application.rb
- app/models/user.rb
- app/models/location.rb
- app/helpers/curator_helper.rb
- app/views/layouts/curator.html.erb
- app/views/travel_profiles/page.html.erb
- app/views/new_design/_footer.html.erb
- lib/platform/dsl/executors/curator.rb
- lib/platform/services/spam_detector.rb
- lib/platform/dsl/grammar.rb
- config/initializers/flipper.rb
- Gemfile
enola_intent:
  page:
    type: initiative
    status: proposed
    scope:
    - usput.ba
    origin:
    - other
    - repo
    relations:
    - rel: depends-on
      to: wiki/decisions/admin-through-avo.md
    - rel: depends-on
      to: wiki/initiatives/avo-admin-and-roles.md
---
# What the rebuild leaves out, the curator dashboard

## Objective

Name everything the hand-built curator area consists of, say why the rebuild leaves each part out, and delete it on the rebuild branch as soon as its replacement in Avo exists, so the branch never carries two admins and nothing of the old area survives by accident.

## Background

The operator chose to remove the curator dashboard completely and use Avo instead, then to rebuild usput in place: the Rails skeleton stays, domain, admin and UI are rewritten piece by piece, "deleting as we go", and the rebuilt app starts with an empty database while the current production site runs until launch (`sources/conversations/2026-09-30--usput--platform-direction.md`; [admin through Avo](../decisions/admin-through-avo.md)). There is therefore no data to export and no table to migrate: the old production database keeps its data for as long as the old site runs, and the rebuilt schema simply does not contain these tables.

**Why each part is left out.** The area exists to let curators propose and admins approve. Its central model, `ContentChange`, holds a proposal as JSON for any resource and applies it on approval (`app/models/content_change.rb`); the unmerged #151 RFC argued it does not work in production, and the brain never settled that ([curator dashboard v2](../decisions/curator-dashboard-v2.md)). With Avo and role rules, a curator edits the record directly, so proposals, contributions to proposals, curators reviewing proposals, photo suggestions and curator applications have no job left. What the area does that still matters (archiving places, the moment queue, users and roles) moves to Avo, as mapped in [Avo admin and roles](avo-admin-and-roles.md).

**The inventory**, counted with `wc -l` on 2026-09-30 at commit 019e6fe:

| Group | Files | Lines |
|---|---|---|
| Controllers under `app/controllers/curator/` (dashboard, locations, experiences, plans, audio tours, reviews, moments, proposals, photo suggestions, base, and five under `admin/`) | 15 | 1,284 |
| Public curator application controller `app/controllers/curator_applications_controller.rb` | 1 | 43 |
| Views under `app/views/curator/` | 51 | 4,971 |
| Curator layout `app/views/layouts/curator.html.erb` | 1 | 249 |
| Views under `app/views/curator_applications/` | 3 | 308 |
| Models (below) | 6 | 722 |
| Helper `app/helpers/curator_helper.rb` | 1 | 25 |
| Stimulus controllers used only by the curator views: `curator_filters`, `curator_menu`, `multi_photo_upload` | 3 | 147 |
| Platform DSL: `lib/platform/dsl/executors/curator.rb` and `lib/platform/services/spam_detector.rb` | 2 | 799 |
| Tests (curator controllers, the two curator integration tests, the DSL curator tests, and model tests for `ContentChange`, `CuratorReview` and `PhotoSuggestion`) | 19 | 6,093 |
| Locale blocks `curator:` and `curator_applications:` across all 16 files in `config/locales/` | 16 | 3,005 |
| Routes: the `namespace :curator` block in `config/routes.rb`, plus `become-curator` and `curator_applications` | 1 | 56 |

About 17,700 lines in all. The `dropdown`, `load_more` and `theme` Stimulus controllers are used by the curator views and also by public pages, so they are not in the count.

**Models and tables, and what outside the curator area depends on each** (from `grep` over `app/`, `lib/` and `config/`):

- `ContentChange` (`content_changes`). Outside the area: `CuratorHelper`, `CuratorActivity`, the DSL curator executor and table query, and `User has_many :content_changes`.
- `ContentChangeContribution` (`content_change_contributions`). Only `ContentChange` and `User`.
- `CuratorReview` (`curator_reviews`). Only `ContentChange`, `User` and the DSL curator executor.
- `CuratorActivity` (`curator_activities`). `User#check_spam_activity!` counts it, and `Platform::Services::SpamDetector` and the DSL curator executor read it.
- `PhotoSuggestion` (`photo_suggestions`). `CuratorHelper`, `CuratorActivity`, `Location has_many :photo_suggestions` and `User`.
- `CuratorApplication` (`curator_applications`). The public application pages, `User#pending_curator_application?` and `#can_apply_for_curator?`, the DSL curator executor and table query.

None of the traveller features (moments, plan visits, likes, Browse) depends on any of them. The other ties outside the area are small: `Authenticatable#require_curator` and `#require_admin` (the latter redirects to `curator_root_path`), links from the travel profile page and the footer (`app/views/travel_profiles/page.html.erb`, `app/views/new_design/_footer.html.erb`), `current_user_can_curate?` on the place, experience and plan pages, the spam columns on `users` (`activity_count_today`, `activity_count_reset_at`, `spam_blocked_at`, `spam_blocked_until`, `spam_block_reason`), and curator and spam words in the DSL grammar (29 matching lines in `lib/platform/dsl/grammar.rb`).

**Feature flags.** The only flag the code reads is `:curator_edit_delete`, in curator views only. With it gone, Flipper (`flipper` and `flipper-active_record` in the `Gemfile`, `config/initializers/flipper.rb`, the `flipper_features` and `flipper_gates` tables) has no user.

## Affected personas

- **Curators and admins.** Lose the old dashboard on the rebuild branch; they work in Avo once the matching slice lands.
- **Travellers.** Lose the "become a curator" link and application page.
- **Developers and agents.** Lose the DSL curator commands (`bin/platform`), which read the removed tables.

## Scope

On the rebuild branch, each deletion lands in the same pull request as, or right after, the Avo slice that replaces it, with the test suite green after each:

1. **Proposals and curator reviews.** Delete `ContentChange`, `ContentChangeContribution`, `CuratorReview`, the proposals and content change controllers and views, their tests and locale keys. Lands with Avo's `Location`, `Experience` and `Plan` resources.
2. **Photo suggestions.** Delete `PhotoSuggestion`, both photo suggestion controllers, `multi_photo_upload`, their tests. Lands with photo upload on the Avo `Location` resource.
3. **Curator applications.** Delete `CuratorApplication`, the public and admin controllers and views, the footer and profile links, their locale keys. Lands with role changes in the Avo `User` resource.
4. **Moments and reviews queues.** Delete `Curator::MomentsController` and `Curator::ReviewsController` with views and tests. Lands with the Avo `Moment` and `Review` queues.
5. **The shell.** Delete the dashboard, base controllers, curator layout, `CuratorHelper`, `curator_filters`, `curator_menu`, the `namespace :curator` routes, the remaining `curator:` locale keys, and `require_curator` and `require_admin` from `Authenticatable`. Add a test that no route begins with `/curator`.
6. **Activity trail and spam counter.** Delete `CuratorActivity`, the spam columns and methods on `User`, `SpamDetector` and the DSL curator executor with its grammar rules and tests. Lands with the `AdminEvent` trail if the operator keeps one.
7. **Flipper.** Remove the gems, the initializer and its tables once no flag is read.

## No-gos

- No data export and no data-preserving migration: the rebuilt app starts empty and the old site keeps its own database until launch.
- No compatibility routes or redirects from `/curator` on the rebuild branch.
- No partial keep: nothing of the proposal flow survives as a fallback beside Avo.

## Rabbit holes

- **Migrations.** The branch still carries 66 migrations that create these tables (`db/migrate/`). Dropping them in a new migration works for developers' databases; a fresh baseline schema is cleaner for an app that launches empty (see Decision needed).
- **The DSL is wider than curators.** `lib/platform/dsl/executor.rb` and the grammar route curator commands beside everything else; cutting them must leave the rest of the DSL passing its tests.
- **Deleting too early.** A slice that deletes before its Avo replacement lands leaves the branch without a way to do that job; the order above prevents it.

## Appetite

Small per slice, since each is mostly deletion with a test run; the risk is in the DSL and grammar cut (slice 6). A calendar estimate is (unknown, needs source).

## Decision needed

**Decided on 2026-09-30** ([answers](../../sources/conversations/2026-09-30--usput--platform-direction.md)): Production is deployed by hand, so the removal lands on `main` piece by piece while the old site keeps running from its last deployed version. The questions below that these answers settle are closed; the rest stay open.

- **Migrations on the branch.** Drop the tables in a new migration, or squash all migrations into a baseline for the rebuilt schema.
- **The old production data at launch.** Whether the old database is archived as a snapshot or discarded when the old site goes down.
- **The DSL curator commands.** Remove them with the tables (proposed), or rewrite the useful ones (list users by role, block and unblock) against the new models.
