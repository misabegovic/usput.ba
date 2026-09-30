---
title: Secure sessions for the rebuilt app
kind: initiative
status: living
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/admin-through-avo.md
- decisions/accounts-through-devise.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- sources/conversations/2026-09-30--usput--devise-and-google.md
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
enola_intent:
  page:
    type: initiative
    status: living
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/decisions/admin-through-avo.md
    - rel: depends-on
      to: wiki/decisions/accounts-through-devise.md
---
# Secure sessions for the rebuilt app

## Objective

The rebuilt usput signs people in by email through Devise, with sessions the app can end: on sign-out, on a password change or reset, on a block, and from a "sign out of all other devices" button. Sign-in cannot be brute-forced, a new account confirms its email, a forgotten password is reset by email, a traveller can sign in with Google, and a guest who explored without an account keeps their walk when they sign in ([decision](../decisions/accounts-through-devise.md)).

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

**The first shape, and the change of course.** #171 built slices 1 and 2 on the shape of the Rails 8.1.3.1 authentication generator: a `Session` row per browser, `Current`, `authenticate_by` on the username, and `rate_limit` counted in Solid Cache. The same day the operator chose Devise instead and settled its details: email-only sign-in, confirmation with a three-day grace, no session rows, mail through Postmark, a single "sign out of all other devices" button instead of a devices list, and Google as the one social sign-in, linked to an existing account when Google reports the email verified (`sources/conversations/2026-09-30--usput--devise-and-google.md`).

## Affected personas

- **Guests.** Explore, walk and check in without an account; the walk must survive signing up or signing in.
- **Travellers (`basic`).** Sign in by email or Google, confirm their email, reset a forgotten password, and sign out everywhere else when they want to.
- **Curators.** Reach Avo with a curator's rights; a block or a demotion ends their access at once.
- **Admins.** Change roles and block users, and know that the change takes effect on every device.

## Scope

What the rebuilt app has:

- Devise on `User` (database authenticatable, registerable, recoverable, validatable, confirmable), signing in by email, with the username kept as a display name.
- Confirmation with a three-day grace, and notices when an email or password changes.
- One way to end sessions: a per-user session token folded into what Devise checks on each request. A password change, a reset, a block and the "sign out of all other devices" button rotate it.
- A block that holds everywhere: a blocked user is signed out on their next request.
- Rate limits through Rails `rate_limit` on sign-in, registration, reset and confirmation requests, counted in Solid Cache.
- Mail through Postmark in production, opened in the browser in development, sent from background jobs, in Bosnian and English.
- The guest door: the walk and profile replayed at sign-in and registration, keeping the #166 rules (once per account, capped, uuids only, malformed input dropped, never repeated elsewhere).
- Google sign-in through OmniAuth, linked by verified email.
- The three roles (`basic`, `curator`, `admin`) on `User`, read by the public site and by the Avo gate ([Avo admin and roles](avo-admin-and-roles.md)).

Slices, each a small pull request with its tests:

1. **Done 2026-09-30 (#171), replaced by slice 3.** Server-side session rows, sign-in and sign-out with a session reset.
2. **Done 2026-09-30 (#171).** Email required at registration; `rate_limit` on both doors with a shared cache store.
3. Devise: email sign-in and registration with the guest door kept, confirmation with grace, password reset and change, the account page, blocks, the session token and its button, Postmark. Replaces slice 1's tables.
4. **Done 2026-09-30.** Google sign-in.
5. **Done 2026-09-30.** Rack::Attack kept only for what `rate_limit` does not cover (exploit probes, the mine check, route lookups), with every throttle pointed at a path that exists. A test per remaining throttle path.

## No-gos

- No compatibility with today's `_usput_session` cookie or accounts; the rebuild starts with an empty database.
- No two-factor sign-in and no provider other than Google in version 1.
- No devices list; the one button covers it.
- No guest account rows: a guest stays device-held until they sign in.
- No second replay path: the walk is replayed at the door and nowhere else.

## Rabbit holes

- **Turbo and redirects.** `require_login` answers Turbo stream requests with a 303, because Turbo only follows a redirect out of a write with one (`app/controllers/concerns/authenticatable.rb`). Devise's own redirects need the same treatment where Turbo submits forms.
- **The replay payload is untrusted.** It arrives as form fields from device storage; the importer's defensive parsing is part of the design, not an implementation detail.
- **Mail that never arrives.** Reset and confirmation are only as good as delivery. The sending domain must be verified in Postmark before launch, and a failed send is retried by the job, not lost.
- **Linking by email.** Linking a Google sign-in to an existing account is only safe when Google says the email is verified; anything else would let a stranger take over an account.

## Appetite

Small to medium: slice 3 is the large one, the rest are a controller and a model each. A calendar estimate is (unknown, needs source).

## Decision needed

**Decided on 2026-09-30** ([platform answers](../../sources/conversations/2026-09-30--usput--platform-direction.md), [account answers](../../sources/conversations/2026-09-30--usput--devise-and-google.md)): email is required, sign-in is by email through Devise, confirmation has a three-day grace, mail goes through Postmark, sessions live in the cookie and end through a rotating token, Google links by verified email. Production is deployed by hand.

Still open:

- **A server-side guest identity.** A signed guest token cookie would let a guest's review be shown to its author ([Jev review flagging](jev-review-flagging.md)). Adopt it, or require sign-in to review (the operator chose sign-in to review for version 1).
- **Who can be blocked, and where.** Any user can be blocked in the model; the admin control comes with Avo.
- **Sending address.** Which address on usput.ba mail comes from (unknown, needs source); the code reads it from the environment.

## Build notes

Slices 1 and 2 landed together on 2026-09-30.

- **Email is required at registration, not yet in the database.** The model
  validates presence in a `registration` validation context, and format and
  case-insensitive uniqueness whenever an email is present. Two hundred lines
  of the old test suite create users without one; the `NOT NULL` constraint
  lands when those tests are rewritten with the rest of the rebuild.
- **Rate limits count in Solid Cache**, kept in the primary database so no new
  database is needed on Railway. `rate_limit` is handed `RateLimitStore`, which
  forwards to `Rails.cache` at request time, because `rate_limit` otherwise
  keeps the store it saw when the class loaded and a test could never turn it
  on. The cost: Roundhouse models `rate_limit` without a `store:` option, so
  both calls show as survey gaps (recorded on
  [Roundhouse](roundhouse-analysis-and-compile.md)).
- **The session cookie lasts two weeks from sign-in**, fixed rather than
  sliding; `last_seen_at` is written at most once an hour. Sliding sessions
  stay an open question below.
- **`reset_session` runs at sign-in and sign-out**, carrying only the
  return-to path and the locale across.

Slice 3, the move to Devise, landed on 2026-09-30.

- **The account token is folded into Devise's salt.** Devise keeps the user id
  and `authenticatable_salt` in the session and compares the salt on every
  request. `User#authenticatable_salt` appends a `session_token` (Rails
  `has_secure_token`) to the part of the password hash Devise uses, so a new
  password, a reset, `block!` and the "sign out of all other devices" button
  all end every other session, with no session table.
- **The login lives two weeks from sign-in**, as before, because the Rails
  cookie store's `expire_after` already does that; Devise's remember-me module
  is not used.
- **A blocked user** fails `active_for_authentication?` with its own message
  (`devise.failure.blocked`). Blocking sets `blocked_at` and rotates the token;
  the admin control comes with Avo. The old curator spam block is unchanged.
- **Paranoid mode is on**: reset and confirmation requests answer the same
  whether or not the email has an account. Registration still says an email is
  taken, which is how uniqueness shows.
- **Account deletion is not offered yet.** Devise routes it, but
  `Users::RegistrationsController#destroy` answers not found until the app
  decides what happens to a deleted user's reviews, moments and curator
  history. Several tables reference users without a rule for it.
- **Rate limits refuse by sending the visitor back** to the form they came
  from, or to sign-in, because Devise's POST paths (`/account`, `/password`,
  `/confirmation`) have no page of their own to return to.
- **Roundhouse** reports 20 more errors than after #171. Nearly all are Devise's
  mail templates reading `@resource` and `@token`, which Roundhouse cannot type
  without modelling Devise's mailer. The rest is one survey gap for
  `devise_for` in the routes. The check stays a report, per
  [Avo now, compile later](../decisions/avo-now-compile-later.md).
- **The schema was edited by hand** alongside the two migrations, because the
  database was unreachable from the build container; CI loads it.

Slice 4, Google sign-in, landed on 2026-09-30.

- **Identities, not columns on users.** One row per outside account keeps
  room for another provider and lets a traveller keep a password beside Google.
- **Linking follows the decision's rules**
  ([amendment](../decisions/accounts-through-devise.md)): linked id first, then
  a verified email, never an unverified one, never a second Google account.
- **The guest walk rides the cache.** OmniAuth's `before_request_phase` hook
  stores the device's payload in `Rails.cache` for fifteen minutes under a
  token kept in the session (`GuestPayloadStash`); the callback takes it once
  and replays it with the same `SyncsLocalData` rules as the other doors.
- **A Google-only traveller has a random password** and sets a real one
  through the reset link; the account page says so.
- **The button is a plain form post with Turbo off**, because the next stop is
  Google's page, and OmniAuth 2 accepts only a POST with a valid CSRF token
  (`omniauth-rails_csrf_protection`).

Slice 5, Rack::Attack, landed on 2026-09-30.

- **Three throttles pointed at nothing and were removed**: `/api/`,
  `/admin` and `/admin/ai/status`, none of which the app routes. Avo's own
  path gets a throttle when it is mounted, if it needs one.
- **The search throttle matched any path containing `/search` or `/cities`**;
  it now names the one route that is a search, `/plans/search_cities`.
  Explore search falls under the general limit.
- **Every throttle is held to a routed path by a test**
  (`test/integration/rack_attack_test.rb`), which also fails if a throttle is
  added without being listed there, and checks the 429, the localhost
  safelist and the exploit blocklist end to end.

