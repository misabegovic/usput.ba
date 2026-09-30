---
title: Accounts through Devise, with Postmark and Google, from the operator
date: 2026-09-30
via: conversation with the agent
---
# Accounts through Devise, 2026-09-30

After #171 (server-side sessions, email at registration) merged, the agent
asked which mail sender password reset should use and proposed a "your
devices" list.

> postmark I guess . why do I need a your devices thing?

The agent answered that a password change already signs out other devices
and offered a single "Sign out of all other devices" button instead of a
list. The operator agreed ("ok").

> ok. we should also support social logins like google I guess? are you
> implementing this from scratch or using well known libraries like devise ?

The agent explained that #171 follows the Rails 8 authentication generator,
compared it with Devise 5.0.4, and recommended staying. It asked whether a
Google sign-in with a verified email that matches an existing account should
link to it, and whether Apple should come too.

> yes, google for now. idk, not expensive to rebuild stuff. evaluate if
> devise is better

After the comparison:

> devise is the way to go I guess

Answers, asked one by one:

1. What people type to sign in: "Email only". Usernames stay as public
   display names.
2. Email confirmation: "Confirm, 3-day grace". New accounts work at once and
   must confirm within three days to keep signing in.
3. The sessions table from #171: "Drop it, use Devise's way". The login lives
   in the signed cookie; a "sign out of all other devices" button rotates a
   per-user token that Devise checks on every request.
4. Accounts made before #171, which have no email: "Nothing special". The
   rebuild starts with an empty database, so email becomes required
   everywhere.

Earlier in the same exchange: the mail sender is Postmark, the devices list
is replaced by the single button, Google is the only social sign-in for now,
and a Google sign-in links to an existing account when Google reports the
email as verified.
