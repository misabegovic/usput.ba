---
title: Accounts through Devise, signed in by email
kind: decision
status: accepted
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-09-30--usput--devise-and-google.md
- sources/conversations/2026-09-30--usput--platform-direction.md
- https://github.com/misabegovic/usput.ba/pull/171
- https://github.com/heartcombo/devise/blob/main/CHANGELOG.md
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - web
---
# Accounts through Devise, signed in by email

## Context

The rebuild needs accounts that do more than sign in: password reset and
email confirmation through a mail sender, a block that signs a user out
everywhere, a way to sign out every other device, and Google sign-in. #171
started down the path of the Rails 8 authentication generator: a `Session`
row per device, `Current`, `authenticate_by` on the username, and
`rate_limit` counted in Solid Cache.

Devise 5.0 was released on 2026-01-23 with Rails 8 and Ruby 4 support, and
5.0.4 followed on 2026-05-08. It ships password reset, email confirmation,
change-of-email and change-of-password notices, test helpers and OmniAuth
routing, and it is the authentication the admin tool Avo documents first. The
operator asked for an evaluation, heard the recommendation to stay on the
generator, and chose Devise
([answers](../../sources/conversations/2026-09-30--usput--devise-and-google.md)).

## Decision

Accounts use Devise with the database authenticatable, registerable,
recoverable, validatable and confirmable modules, and later omniauthable for
Google.

- **Sign-in is by email only.** The username stays, as a public display name
  chosen at registration.
- **Confirmation has a three-day grace.** A new account signs in at once and
  must confirm its email within three days to keep signing in.
- **The login lives in Devise's signed session cookie**, two weeks from sign-in
  as before. #171's `Session` table and `Current` object are removed.
- **Ending sessions is one mechanism.** Every user carries a random session
  token that is part of the value Devise checks on each request. Rotating it
  signs the user out of every browser. A password change, a password reset, a
  block and the "sign out of all other devices" button all rotate it; the
  button then signs the current browser straight back in.
- **A blocked user is refused on the next request**, anywhere in the app,
  through Devise's `active_for_authentication?`.
- **Mail goes through Postmark** in production, is opened in the browser in
  development, and is sent from background jobs.
- **Rate limits stay Rails `rate_limit`**, counted in Solid Cache as #171 set
  up, on sign-in, registration, password reset and confirmation requests.
  Devise's own account locking is not used.

## Alternatives

- **Keep the Rails 8 generator shape from #171.** Every feature above is
  small on top of it, per-device sessions come for free, and all the code sits
  readable in the repository. Rejected by the operator, who preferred a widely
  used library to code the project owns.
- **Devise with a session row per device.** Keeps last-seen data and room for
  a devices list, at the cost of custom Warden hooks on top of Devise. Not
  chosen: the list itself was dropped.
- **Email or username at sign-in.** A documented Devise pattern. Not chosen:
  the rebuild has no old accounts to keep working.

## Consequences

- Devise's routes, controllers and failure handling replace the hand-written
  ones. The app subclasses Devise's session and registration controllers to
  replay a guest's walk at the door (#166's rules unchanged).
- Every user needs an email. The column becomes `NOT NULL`, and a database
  holding old accounts without one cannot migrate; the rebuild starts empty.
- Devise is an engine with Warden middleware, a second one next to Avo that
  Roundhouse cannot compile. [Avo now, compile later](avo-now-compile-later.md)
  already accepts that for Avo.
- Devise security releases have to be followed; 5.0.3 and 5.0.4 were both
  security fixes, one of them in email confirmation.
- The mail sender needs a Postmark server token in the app's credentials and a
  verified sending domain before production sends anything.

## Amendments

**2026-09-30: Google sign-in.** The omniauthable module now carries Google
through OmniAuth, with the direction unchanged. A Google account is linked in
an `identities` table (provider and Google's id), so a traveller can have both
a password and Google. The rules, in order:

- A Google id already linked signs in its account, whatever email Google now
  reports.
- Otherwise a Google email that Google reports verified links to the usput
  account with that email, confirming it, or creates a new confirmed account
  with a username taken from the email. An unverified email links to nothing,
  because anyone can type one.
- An account already linked to one Google account is not linked to a second.
- A blocked account is refused like any other sign-in.

The guest walk crosses the trip to Google in the cache, under a token in the
session, because it can be larger than the session cookie. The button only
shows where the Google credentials exist.

