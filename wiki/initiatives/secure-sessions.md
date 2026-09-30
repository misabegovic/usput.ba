---
title: Secure sessions for the rebuilt app
kind: initiative
status: proposed
updated: 2026-09-30
repos:
  - usput.ba
confidence: medium
depends_on:
  - decisions/admin-through-avo.md
sources:
  - sources/conversations/2026-09-30--usput--platform-direction.md
  - app/controllers/concerns/authenticatable.rb
  - app/controllers/concerns/syncs_local_data.rb
  - app/controllers/sessions_controller.rb
  - app/controllers/users_controller.rb
  - app/controllers/curator/base_controller.rb
  - app/controllers/curator/admin/users_controller.rb
  - app/services/guest_visits_importer.rb
  - app/models/user.rb
  - app/views/sessions/new.html.erb
  - config/initializers/session_store.rb
  - config/initializers/rack_attack.rb
  - config/environments/production.rb
  - config/routes.rb
  - db/schema.rb
  - https://github.com/misabegovic/usput.ba/pull/166
  - https://github.com/rails/rails/tree/v8.1.3.1/railties/lib/rails/generators/rails/authentication
---
# Secure sessions for the rebuilt app

## Objective

The rebuilt usput signs people in with a server-side session that the app can end: on sign-out, on a password change, on a role change and on a block. Sign-in cannot be brute-forced, the session is fresh after every sign-in, and a guest who explored without an account keeps their walk when they sign in. The shape is the one Rails 8 generates, adapted to usernames and to guests.

## Background

The operator asked to "work on the user sessions and how they work right now", and later chose to rebuild usput in place on a long-lived branch that starts with an empty database (`sources/conversations/2026-09-30--usput--platform-direction.md`). Nothing below needs to stay compatible with today's cookies or accounts. Today's code is described for what it teaches.

**How sign-in works today.** `Authenticatable` stores `session[:user_id]` in the Rails cookie store (`_usput_session`, `expire_after` two weeks, secure in production, `same_site: :lax`, per `config/initializers/session_store.rb`). `current_user` is `User.find_by(id: session[:user_id])` on every request. `SessionsController#create` finds the user by lower-cased username and calls `authenticate` from `has_secure_password` (`app/controllers/sessions_controller.rb`, `app/models/user.rb`).

What the code shows, checked on 2026-09-30:

- **No session reset.** `log_in` writes `user_id` into whatever session the browser already carries, and `log_out` deletes only that key (`app/controllers/concerns/authenticatable.rb`). Nothing calls `reset_session`. With a signed cookie store the classic fixation attack is weak, because the store rewrites the cookie on sign-in, but the session is never rotated and other keys (`return_to`) survive sign-out.
- **Nothing can revoke a session.** There is no session table (`db/schema.rb`). A copied cookie stays valid until it expires, and signing out on one device does nothing to another.
- **Role changes apply, but nobody can be signed out.** An admin changes `user_type` in `Curator::Admin::UsersController#update`; because `current_user` reloads the row on every request, the new role applies at once. What is missing is a way to end a user's sessions.
- **There is no password change at all.** The routes offer register, login, logout and avatar only, and users have no email column, so there is no reset path either (`config/routes.rb`, `db/schema.rb`).
- **A spam block only holds inside the curator area.** `spam_blocked?` is checked in `Curator::BaseController#check_spam_block` and nowhere in `current_user`, so a blocked curator still posts reviews and moments on the public site (`app/controllers/curator/base_controller.rb`).
- **The login throttles never fire.** `config/initializers/rack_attack.rb` throttles `POST /session` keyed on a `session[email]` parameter, `POST /users`, `/password_resets` and `/admin`. usput signs in at `POST /login` with a username and registers at `POST /register`, so only the general limit of 300 requests per five minutes per IP applies. `SessionsController` has no `rate_limit`.
- **Counters live in one process.** Production uses `:memory_store` for the cache (`config/environments/production.rb`), which is where Rack::Attack and Rails `rate_limit` keep their counts, so each process counts on its own.

**The guest walk replay (#166, commit 55757a2).** A guest explores and checks in with the data held on their device. The sign-in and register forms carry that data as hidden fields (`app/views/sessions/new.html.erb`), and both doors call `SyncsLocalData`: `merge_local_profile` merges favourites, badges and saved plans, and `GuestVisitsImporter` turns the device's visited place uuids into `PlanVisit` rows on the traveller's explore plan (`app/controllers/concerns/syncs_local_data.rb`, `app/services/guest_visits_importer.rb`). Its rules are the lesson to keep: the device list is the one check-in path that cannot re-verify the 100 m gate, so it is spent once (an account that already has visits is skipped), capped at 500 entries, deduplicated by a unique index, and anything malformed is dropped rather than failing the sign-in.

**The target shape.** Rails 8.1.3.1's authentication generator (read from the installed railties gem) creates a `Session` model that belongs to the user and records `ip_address` and `user_agent`; a `Current` object holding the session and delegating `user`; a signed, http-only cookie carrying only the session id; `start_new_session_for` and `terminate_session`; `User.authenticate_by`; `rate_limit to: 10, within: 3.minutes` on sign-in; and a password update that destroys all of the user's sessions. It keys on an email address, where usput keys on a username. Roundhouse models the same shape (unverified, 2026-09-30).

## Affected personas

- **Guests.** Explore, walk and check in without an account; the walk must survive signing up or signing in.
- **Travellers (`basic`).** Sign in, stay signed in across visits, and sign out everywhere when they want to.
- **Curators.** Reach Avo with a curator's rights; a block or a demotion ends their access at once.
- **Admins.** Change roles and block users, and know that the change takes effect on every device.

## Scope

What the rebuilt app has:

- A `Session` record per signed-in browser (user, IP address, user agent, created and last-seen times) and `Current.session` and `Current.user`, replacing the cookie-held user id.
- Sign-in with `User.authenticate_by` on username and password. The Rails session is reset first, the return-to path is carried across the reset, then a new `Session` row and cookie are issued.
- Sign-out destroys the `Session` row and resets the Rails session.
- Revocation in one place: a password change, a role change and a block each destroy the user's other sessions.
- A block that holds everywhere: resuming a session for a blocked user fails on every page, not only in the admin.
- Rate limits on sign-in and registration through Rails `rate_limit`, with a cache store that all processes share.
- A password change for a signed-in user, since there is no email to reset through.
- The guest door: one service that replays a guest's walk and profile at sign-in and registration, keeping the #166 rules (once per account, capped, uuids only, malformed input dropped, never repeated elsewhere).
- The three roles (`basic`, `curator`, `admin`) on `User`, read through `Current.user` by the public site and by the Avo gate ([Avo admin and roles](avo-admin-and-roles.md)).

Slices, in order on the rebuild branch, each a small pull request with its tests:

1. `Session` and `Current`, the authentication concern, sign-in and sign-out with reset. Model tests for `Session`; controller tests for sign-in, a failed sign-in, sign-out and a request after sign-out.
2. Registration through the same door, and `rate_limit` on both doors with a shared cache store. Tests that the eleventh attempt in the window is refused (with a cache store enabled in that test).
3. The guest door: walk and profile replay at both doors. Tests carried over as behaviours from today's `test/controllers/sessions_controller_test.rb` and `test/services/guest_visits_importer_test.rb`: replay once, cap, malformed payloads, second device.
4. Blocks and role changes end sessions; a blocked user cannot resume anywhere. Model tests for the callbacks, a controller test that a blocked user is signed out on the next request.
5. Password change for a signed-in user, ending other sessions. Controller tests for the change and for the other session dying.
6. "Your devices": a user lists their sessions and ends one or all. Controller tests.
7. Rack::Attack kept only for what `rate_limit` does not cover (exploit probes, the mine check, route lookups), with every throttle pointed at a path that exists. A test per remaining throttle path.

## No-gos

- No compatibility with today's `_usput_session` cookie or accounts; the rebuild starts with an empty database.
- No email, password reset by email, OAuth or two-factor sign-in in version 1.
- No guest account rows: a guest stays device-held until they sign in (see Decision needed).
- No second replay path: the walk is replayed at the door and nowhere else.

## Rabbit holes

- **Turbo and redirects.** Today's `require_login` answers Turbo stream requests with a 303, because Turbo only follows a redirect out of a write with one (`app/controllers/concerns/authenticatable.rb`). The new concern needs the same.
- **Last-seen writes.** Touching the session row on every request is a write per page view; update it at most every few minutes.
- **Cache store.** `rate_limit` is only as good as its store. Solid Cache is already in the Gemfile but unused; the choice belongs with the deploy setup.
- **The replay payload is untrusted.** It arrives as form fields from device storage; the importer's defensive parsing is part of the design, not an implementation detail.

## Appetite

Small to medium: seven slices, most of them one controller and one model with tests. A calendar estimate is (unknown, needs source).

## Decision needed

- **Session lifetime.** Two weeks from last use (today's `expire_after`), or the generator's permanent cookie with sessions ended only by sign-out and revocation.
- **Email on accounts.** Without an email there is no self-service reset; a forgotten password needs an admin. Keep username-only for version 1, or add email now.
- **A server-side guest identity.** A signed guest token cookie would let a guest's review be shown to its author ([Jev review flagging](jev-review-flagging.md)). Adopt it here, as part of sessions, or leave guests device-only and require sign-in to review.
- **Who can be blocked.** Today only curators are spam-counted (`User#check_spam_activity!`). Decide whether a block applies to any user and who sets it (admin only, in Avo).
