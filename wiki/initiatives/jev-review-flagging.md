---
title: Jev review flagging
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/jev-flags-reviews.md
- decisions/admin-through-avo.md
- initiatives/avo-admin-and-roles.md
- initiatives/secure-sessions.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- app/models/review.rb
- app/models/concerns/reviewable.rb
- app/models/moment.rb
- app/controllers/reviews_controller.rb
- app/controllers/new_design_controller.rb
- app/controllers/locations_controller.rb
- app/controllers/experiences_controller.rb
- app/controllers/plans_controller.rb
- app/controllers/curator/reviews_controller.rb
- app/views/reviews/_form.html.erb
- app/views/reviews/_review_card.html.erb
- app/views/pages/privacy.html.erb
- app/services/browse_adapter.rb
- app/services/mine_checker/config.rb
- app/jobs/application_job.rb
- config/environments/production.rb
- db/schema.rb
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
      to: wiki/decisions/jev-flags-reviews.md
    - rel: depends-on
      to: wiki/decisions/admin-through-avo.md
    - rel: depends-on
      to: wiki/initiatives/avo-admin-and-roles.md
    - rel: depends-on
      to: wiki/initiatives/secure-sessions.md
---
# Jev review flagging

## Objective

In the rebuilt usput a review is live the moment it is submitted. A background job asks Jev, TypeSafe's hosted decision model, whether the review reads as negative or unsafe; if it does, the review is hidden from everyone but its author until an admin or curator clears or removes it in Avo. Ratings and counts come from visible reviews only. When there is no key or the call fails, nothing is hidden and nothing breaks. This implements [Jev flags reviews](../decisions/jev-flags-reviews.md).

## Background

The operator's words: use Jev "to scan for comments and determine if a comment is positive or not", hide the ones that need a human admin, and "the author should see their comments though". They chose "Jev only flags" and the hosted TypeSafe API, will provide the key later, and chose a rebuild in place that starts with an empty database (`sources/conversations/2026-09-30--usput--platform-direction.md`). The pre-moderation plan is superseded by the decision; this page replaces [review approval system](review-approval-system.md).

**Reviews today.** `Review` is polymorphic over places, experiences and plans, with a rating from 1 to 5, a comment up to 1,000 characters and a free-text `author_name`; `user_id` is optional and there is no status column (`app/models/review.rb`, `db/schema.rb`). `ReviewsController#create` needs no sign-in, permits `author_name` (and an `author_email` the table does not have), and never sets `user_id` even for a signed-in user (`app/controllers/reviews_controller.rb`). A review therefore has no author identity at all: nobody can be shown "their own". The card shows `author_name` or "Anonimno" (`app/views/reviews/_review_card.html.erb`).

**Ratings today.** `reviews_count` is a counter cache over every review, and `average_rating` is recomputed from every review after each save or destroy (`app/models/review.rb`). `Reviewable` sorts on both (`popular`, `top_rated`, `trending`), the home page shows recent reviews rated 3 or more and ranks trending places by their latest review (`app/controllers/new_design_controller.rb`), the place, experience and plan pages list the ten newest, and Browse rows copy `average_rating` (`app/services/browse_adapter.rb`). Every one of these reads all reviews.

**The estate's judge seam.** The operator's estate brain already asks Jev through one seam, recorded in claude-brain's `wiki/brain/adrs/typed-judgments-through-one-seam.md`: every call goes through one function, a missing key or a failure is a named skip that never raises, a judgment is a candidate and never a verdict, what leaves the machine is decided in the same place, and a use is measured before it is wired. That ADR also records that the service is in the United States with no fixed retention period. This page applies the same rules inside usput.

**Moments are a second kind of user comment.** A moment carries a `note` of up to 1,000 characters and is shown to others only when public and approved by a curator (`app/models/moment.rb`). It is already pre-moderated by a human.

## Affected personas

- **Travellers and guests who review.** Submit as today; a flagged review stays visible to them, marked as waiting.
- **Readers.** See fewer abusive or hostile reviews, and ratings that move only on visible reviews.
- **Admins and curators.** Work a flagged-reviews queue in Avo.

## Scope

What the rebuilt app has:

- **A state on reviews:** `live`, `flagged`, `cleared` and `removed`, plus when it was judged, Jev's answer (the probability) and the reason a judgment was skipped. `cleared` means a human kept it; `removed` hides it for good.
- **One seam.** A single service is the only code that talks to TypeSafe. It reads the key from Rails credentials (the pattern `MineChecker::Config` uses, `app/services/mine_checker/config.rb`), returns an answer or a named skip (no key, timeout, error), and never raises. Nothing else imports a client.
- **A job, never inline.** Submitting enqueues a Solid Queue job (the production adapter, `config/environments/production.rb`); the request returns at once. The job asks the seam and flags the review if the answer crosses the threshold. A skip leaves the review live and records why.
- **What is sent.** Only the comment text and the rating. No author name, user, IP address or place name. A review with no comment is not sent.
- **A visible scope** used everywhere reviews are read: `live` and `cleared` for everyone, plus the reader's own `flagged` reviews. Home, trending, detail pages, the review list and explore all use it.
- **Ratings from visible reviews only.** `average_rating` and `reviews_count` are recomputed from `live` and `cleared` reviews on submit, flag, clear and remove; no counter cache over all rows. The author's own flagged review never moves the public number.
- **Author identity.** A review belongs to a user or, for a guest, to a guest token (see Decision needed), so "the author sees their own" can be answered.
- **An Avo queue:** a `Review` resource filtered to `flagged`, with `Clear` and `Remove` actions under the role rules of [Avo admin and roles](avo-admin-and-roles.md).
- **A privacy line.** The rebuilt privacy page lists reviews among voluntary data today but names no processor (`app/views/pages/privacy.html.erb`). It gains one: "Review text and rating are sent to TypeSafe, an automated moderation service in the United States, to decide whether a review waits for a human before it is shown to others." The wording needs the operator's legal check.

Slices, in order on the rebuild branch, each with its tests:

1. `Review` with state, author identity and the visible scope. Model tests: each state against a stranger, the author and a guest with the right and wrong token.
2. Ratings from visible reviews. Model tests that flagging, clearing and removing move `average_rating` and `reviews_count`, and that a flagged review does not.
3. The seam, with no key. Unit tests for every skip, with the HTTP call stubbed; a test that it never raises.
4. The job and the threshold. Job tests: a negative answer flags, a positive one leaves it live, a skip records the reason; a controller test that submit enqueues and returns without calling out.
5. Every read path on the visible scope. Controller tests for home, trending, the detail pages and the review list showing no stranger's flagged review.
6. The Avo queue with `Clear` and `Remove`. Action tests including the rating recount.
7. The privacy line in `bs` and `en`, and a measurement: a labelled set of sample reviews run through the seam to set the threshold before the key goes live.

## No-gos

- No pre-moderation: nothing waits unless Jev flags it.
- Jev never deletes or edits a review; only a person removes one.
- No author name, account, IP address or location sent to TypeSafe.
- No synchronous call on submit, and no error shown to a reviewer because of Jev.
- No notifications to authors in version 1.

## Rabbit holes

- **Negative is not abusive.** The operator asked for "positive or not". Hiding every negative review until a human looks lifts ratings in the meantime and can read as censorship. Two questions (unsafe or abusive; negative) with separate thresholds keep the choice visible.
- **Language.** Most reviews will be in Bosnian, Croatian or Serbian. How Jev reads them is (unknown, needs source) and is what slice 7 measures.
- **Retries.** A failed call leaves the review live; retrying later could hide a review hours after readers saw it. Retry briefly or not at all.
- **Caching.** A page showing the author their flagged review must not be served from a shared cache to others.
- **Langfuse.** The AI pipeline logs to Langfuse from day one; whether the judge's calls are traced there too is open.

## Appetite

Medium: seven slices, the seam and the job being the smallest. The measurement in slice 7 needs a labelled set that does not exist yet, which is (unknown, needs source) in size.

## Decision needed

**Decided on 2026-09-30** ([answers](../../sources/conversations/2026-09-30--usput--platform-direction.md)): Reviews require signing in. Jev flags reviews it reads as negative or unsafe. Moment notes are read by Jev too, but public moments keep their approval step because Jev cannot see photos; Jev's reading is shown in the moment queue. The questions below that these answers settle are closed; the rest stay open.

- **Reviews and sign-in.** Anonymous reviews have no author today. Options: require sign-in to review (simplest, and a step up from the guest-friendly walk of #166); a signed guest token cookie that ties a guest's review to their browser (keeps guests reviewing, lost when the cookie is cleared); or both, with the token merged into the account at sign-in ([secure sessions](secure-sessions.md)).
- **What counts as a flag.** Unsafe only, negative only, or either, and the thresholds.
- **Moment notes.** In scope (Jev pre-screens notes to sort the curator's moment queue, the queue stays human), or out of scope for version 1 (moments stay human-approved only).
- **Remove.** A soft `removed` state (proposed, keeps a record) or a hard delete.
