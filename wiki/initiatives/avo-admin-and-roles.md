---
title: Avo admin and roles
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/admin-through-avo.md
- decisions/avo-now-compile-later.md
- decisions/jev-flags-reviews.md
- decisions/archive-places-not-delete.md
sources:
- sources/conversations/2026-09-30--usput--place-translations-in-avo.md
- sources/conversations/2026-09-30--usput--platform-direction.md
- config/routes.rb
- app/controllers/curator/base_controller.rb
- app/controllers/curator/dashboard_controller.rb
- app/controllers/curator/locations_controller.rb
- app/controllers/curator/experiences_controller.rb
- app/controllers/curator/plans_controller.rb
- app/controllers/curator/audio_tours_controller.rb
- app/controllers/curator/reviews_controller.rb
- app/controllers/curator/moments_controller.rb
- app/controllers/curator/proposals_controller.rb
- app/controllers/curator/photo_suggestions_controller.rb
- app/controllers/curator/admin/base_controller.rb
- app/controllers/curator/admin/users_controller.rb
- app/controllers/curator/admin/content_changes_controller.rb
- app/controllers/curator/admin/photo_suggestions_controller.rb
- app/controllers/curator/admin/curator_applications_controller.rb
- app/controllers/curator_applications_controller.rb
- app/controllers/concerns/authenticatable.rb
- app/models/user.rb
- app/models/curator_activity.rb
- app/models/location.rb
- app/models/moment.rb
- app/views/curator/locations/index.html.erb
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
      to: wiki/decisions/avo-now-compile-later.md
    - rel: depends-on
      to: wiki/decisions/jev-flags-reviews.md
    - rel: depends-on
      to: wiki/decisions/archive-places-not-delete.md
---
# Avo admin and roles

## Objective

The rebuilt usput has one admin, Avo Community edition, where admins and curators create and look after content: places, experiences, plans, moments, reviews and users. Who may open the admin and what each role may do there is decided by usput's own code and covered by tests. Nothing of today's hand-built curator area is carried over.

## Background

The operator chose Avo for the admin, a curator role inside it, the free Community edition with role rules enforced by the app, and a rebuild in place on a long-lived branch that starts with an empty database (`sources/conversations/2026-09-30--usput--platform-direction.md`; [admin through Avo](../decisions/admin-through-avo.md), [Avo now, compile later](../decisions/avo-now-compile-later.md)). Avo is not in the `Gemfile` today. The Community edition has no built-in authorization (unverified, 2026-09-30).

**Roles today.** `User#user_type` is an enum of `basic`, `curator` and `admin`; `can_curate?` is true for curators and admins (`app/models/user.rb`). `Curator::BaseController` requires sign-in, a curator or admin, and no spam block; `Curator::Admin::BaseController` adds `require_admin` (`app/controllers/curator/base_controller.rb`, `app/controllers/curator/admin/base_controller.rb`). Curators never edit content directly: create, update and delete become `ContentChange` proposals for an admin, and the direct buttons are hidden unless the global Flipper flag `:curator_edit_delete` is on (`app/views/curator/locations/index.html.erb`). Only archive and restore of places act directly ([archive places, not delete](../decisions/archive-places-not-delete.md)).

**What the curator area does today, and where each capability goes** (routes from `config/routes.rb`):

| Capability today | Where it lives | In the rebuild |
|---|---|---|
| Dashboard counts, recent items, activity feed | `Curator::DashboardController` | Dropped for version 1; Avo dashboards are a paid feature (unverified, 2026-09-30). Counts come from resource index pages. |
| List, filter and search places; list archived with `?archived=1` | `Curator::LocationsController#index` | Avo `Location` resource with filters for city, category and archived. |
| Create, edit, delete a place as a proposal | `create`, `update`, `destroy` through `ContentChange` | Avo create and edit, direct, within the role rules below. No proposals. |
| Archive and restore a place | `archive`, `restore` | Avo actions `Archive` and `Restore` calling `archive!` and `restore!`. |
| Places needing photos | `needs_photos` | Avo filter "fewer than N photos" on `Location`. |
| Experiences, plans and audio tours as proposals | `ExperiencesController`, `PlansController`, `AudioToursController` | Avo resources `Experience` and `Plan`; `AudioTour` only if audio tours are in version 1 (see Decision needed). |
| Curators review each other's proposals | `ProposalsController#add_review`, `CuratorReview` | Dropped. |
| Admin approves or rejects proposals | `Admin::ContentChangesController` | Dropped: there are no proposals. |
| Curator suggests photos; admin approves | `PhotoSuggestionsController`, `Admin::PhotoSuggestionsController` | Dropped. A curator uploads photos on the `Location` record. |
| Moment queue: approve, reject, view photo | `Curator::MomentsController` | Avo `Moment` resource with a pending filter and `Approve` and `Reject` actions; the photo is served through the resource. |
| Reviews: list, show, delete as a proposal | `Curator::ReviewsController` | Avo `Review` resource with a flagged filter and `Clear` and `Remove` actions ([Jev review flagging](jev-review-flagging.md)). |
| Users: list, filter by role or block, change role, unblock | `Admin::UsersController` | Avo `User` resource, admin only, with `Block` and `Unblock` actions. |
| Apply to become a curator; admin approves | `CuratorApplicationsController`, `Admin::CuratorApplicationsController` | Dropped. An admin sets the role on the user. |

**The activity trail.** `CuratorActivity` records 20 action types with IP address and user agent, and drives two things: the dashboard feed and a spam limit of 50 actions an hour or 200 a day for curators, which blocks the account for 24 hours (`app/models/curator_activity.rb`, `app/models/user.rb`). Most of those action types describe proposals and applications, which the rebuild does not have.

**What the models already enforce.** Avo writes through the models, so the rules on them apply to admin edits too: a place's coordinates must pass the fail-closed mine check on save, and a place with travellers' records refuses to be destroyed (`app/models/location.rb`). A moment becomes visible only when it is public and approved (`app/models/moment.rb`).

## Affected personas

- **Admins.** Do everything in Avo, including roles and blocks.
- **Curators.** Create and edit content directly in Avo within their rules, and work the moment and review queues.
- **Travellers and guests.** Never reach the admin; they see the results through the public site.

## Scope

What the rebuilt app has:

- Avo Community mounted at one path, reachable only by a signed-in curator or admin, checked against Devise's `current_user` from [secure sessions](secure-sessions.md) in a route constraint and again in Avo's base controller, so a missing check in one place does not open the admin.
- Role rules in usput's own code: one policy object per resource answering "may this role see, create, edit, delete, run this action", read by Avo's resource and action hooks, with tests at the policy level.
- Proposed rules: curators create, edit, archive and restore places, experiences and plans, and approve or reject moments and clear or remove flagged reviews; only admins delete anything, manage users and roles, and block or unblock.
- Resources: `Location`, `Experience`, `Plan`, `Moment`, `Review`, `User`, and `PlanVisit` read-only for support. `AudioTour` if in version 1.
- Actions: `Archive` and `Restore` on places; `Approve` and `Reject` on moments; `Clear` and `Remove` on reviews; `Block` and `Unblock` on users.
- An admin trail: one small `AdminEvent` record (who, what action, which record, when), written by the actions above and by role changes. No spam counter: blocking is an admin decision.
- No Flipper flag for curator editing; `:curator_edit_delete` has no successor.

Slices, in order on the rebuild branch, each with its tests:

1. **Done 2026-09-30.** Install Avo, mount it behind the role gate. Request tests: guest, `basic`, blocked user refused; curator and admin admitted.
2. **Done 2026-09-30.** The policy layer and the `User` resource (admin only), with role change and block actions. Policy unit tests per role; a request test that a curator cannot open users.
3. **Done 2026-09-30.** `Location` with filters, the archive and restore actions and photo uploads. Tests that the mine check blocks a bad coordinate through Avo and that a curator cannot delete.
4. `Experience` and `Plan`, including a plan's stops by day. Policy and request tests.
5. `Moment` queue with approve and reject. Tests that an approved public moment becomes visible and a rejected one does not.
6. `Review` queue with clear and remove, once the flag exists ([Jev review flagging](jev-review-flagging.md)). Tests for both actions and for the rating recount.
7. `AdminEvent` written by every action and role change, shown on each record. Model and action tests.

## No-gos

- No proposals, suggestions or curator applications in any form.
- No Avo Pro or Advanced features; nothing that needs a licence key.
- No authorization left to Avo's defaults; every resource has a policy with tests.
- No curator access to users, roles or deletion.

## Rabbit holes

- **Avo is an engine.** Roundhouse cannot compile an app that mounts an engine other than Active Storage ([Avo now, compile later](../decisions/avo-now-compile-later.md)). Keep admin logic in plain models and policies so it can move if the compile path ever needs it.
- **Callbacks versus admin forms.** The mine check and the destroy guard raise validation errors; Avo must show them rather than swallow them.
- **Translations.** Decided on 2026-09-30 ([answers](../../sources/conversations/2026-09-30--usput--place-translations-in-avo.md)): curators edit all 16 languages by hand, and a later AI retranslation asks before overwriting a hand-edited one.

## Appetite

Medium: seven slices, one to two days of work each for someone who knows Avo. A firmer estimate is (unknown, needs source).

## Decision needed

**Decided on 2026-09-30** ([answers](../../sources/conversations/2026-09-30--usput--platform-direction.md)): Curators create and edit places, experiences, plans and audio tours, and clear or remove flagged reviews and moments. Only admins delete, manage users and roles, and change settings. Audio tours are in version 1. The questions below that these answers settle are closed; the rest stay open.

- **Curator rights.** Confirm the proposed split: curators create and edit directly, only admins delete and manage users. The alternative is curators editing only records they created.
- **The activity trail.** Keep a small `AdminEvent` trail written by Avo actions (proposed), or rely on logs and drop it.
- **Audio tours in version 1.** The operator's version 1 list names places, explore, plans, walking, reviews and the AI pipeline, not audio tours.
- **Becoming a curator.** Applications are gone as [the removal plan](remove-curator-dashboard.md) set out; an admin promotes a user with the Change role action. Whether a public page should at least explain how to become a curator is open.

## Build notes

Slice 1 landed on 2026-09-30.

- **Avo 4.2.11 Community**, no licence key. Per-resource authorization (Pundit
  policies) is a paid add-on in Avo 4, as are dashboards and dynamic filters;
  actions, basic filters, custom tools and `authenticate_with` are free
  (docs.avohq.io/4.0 authorization, licensing, authentication and custom-tools
  pages, read 2026-09-30). The policy layer in slice 2 is therefore usput's own.
- **Two gates.** Devise's `authenticate :user, ->(user) { user.can_curate? }`
  wraps `mount_avo` at `/admin`: a guest is sent to sign in and a traveller
  gets a 404, since the route does not exist for them. Avo's
  `authenticate_with` repeats the role check inside, and a test runs that block
  on its own so it cannot silently become a no-op.
- **A blocked curator is signed out at the door**, because Devise's
  `active_for_authentication?` runs in the route constraint.
- **The admin opens on a welcome tool page** (`/admin/welcome`) that states the
  visitor's role, because Avo's home redirects to the first resource and there
  is none until slice 2.

Slice 2 landed on 2026-09-30.

- **The policy layer is plain Ruby.** `AdminPolicy` (`app/policies/`) holds the
  default: curators and admins see, create and edit, only admins delete.
  `AdminPolicy.for(model)` picks a resource's own policy when one exists.
  `UserPolicy` makes users the admin's alone: nobody is created or deleted there
  (people sign up themselves, and account deletion is undecided), and an admin
  never changes the role of, or blocks, their own account, so the last admin
  cannot lock everyone out.
- **Every Avo resource controller includes `AdminResource`** (named `AdminPolicyGate` in slice 2), a
  `before_action` that runs after Avo loads the record and raises Avo's own
  not-authorized error when the policy says no. Avo's authorization service is
  a null object in Community (`Avo::Services::AuthorizationService`, 4.2.11), so
  without the gate every resource would be open to every curator.
- **Actions check twice**: Avo's `authorize` hook refuses the whole action to
  anyone who is not an admin, and each record is checked again in `handle`, so a
  batch that includes the admin's own account changes the others and names the
  one left alone.
- **The sidebar hides users from curators** by overriding the resource's
  `visible_on_sidebar` reader with the policy; the menu editor that would do it
  declaratively is a paid add-on.
- **Records are found by uuid**, the public id every usput URL uses
  (`find_record_method`); Avo's default looks up the database id.
- **Roles change through an action, not the edit form**, so a role change is
  always a deliberate step that the policy can refuse, and later writes an admin
  event.

Slice 3 landed on 2026-09-30.

- **Places in Avo**: search by name or city; filters for city, status (active
  by default, archived, all) and photos (none, fewer than three); Archive and
  Restore actions calling `archive!` and `restore!`; photos uploaded on the
  record; only admins delete, and the model still refuses to delete a place
  travellers hold records for.
- **All 16 languages on the form**, one tab per language, as the operator
  chose. The per-language accessors (`name_de`) now read and write exactly one
  language with no fallback, so an empty German field never shows, and then
  saves, the English text. Writes are staged on the record and saved with it
  (`has_many :translations, autosave: true`), so a place the mine check
  refuses leaves its translations untouched; a blank field removes that
  language; an unchanged value is left alone.
- **Hand edits are marked.** A translation changed in the admin gets
  `human_edited_at`, set because `AdminResource` records the signed-in user as
  `Current.editor` before Avo copies the form onto the record. The AI pipeline's
  own writes are not marked. The retranslate action that asks before
  overwriting marked languages comes with the content pipeline.
- **The mine check shows on the form**: a coordinate inside a suspected area
  comes back as the form with the error, and nothing is saved.

