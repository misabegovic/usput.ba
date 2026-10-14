---
title: Jev sorts reviews into three bands; a curator decides the unsure ones
kind: decision
status: accepted
updated: 2026-10-14
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-10-14--usput--tooling-models-langfuse-jev.md
- sources/conversations/2026-09-30--usput--platform-direction.md
- app/services/review_moderation.rb
- app/prompts/review_judge/abusive.md
- app/prompts/review_judge/spam.md
- config/review_moderation.yml
- app/models/review.rb
- app/controllers/reviews_controller.rb
- app/avo/resources/review.rb
- app/views/pages/privacy.html.erb
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - repo
---
# Jev sorts reviews into three bands; a curator decides the unsure ones

## Context

On 2026-09-30 the operator chose "Jev only flags": reviews went live at once
and Jev hid the ones it read as negative or unsafe until an admin looked
([superseded decision](jev-flags-reviews.md)). On 2026-10-14 they asked
instead for Jev to approve reviews for public visibility or reject them, the
author always seeing their own, and chose three bands
([source](../../sources/conversations/2026-10-14--usput--tooling-models-langfuse-jev.md)).
The operator's estate ADR on typed judgments holds that a judgment is a
candidate, never a verdict; here it decides the clear cases and a person the
rest. Until this change reviews were anonymous and unmoderated, with a free
author name.

## Decision

- **Reviews require signing in** (decided 2026-09-30), so every review has an
  author who can always see it. The name shown is the account's.
- **Three bands.** `ReviewModeration` asks Jev two yes/no questions, whether
  the review is abusive and whether it is spam, worded in
  `app/prompts/review_judge/`. Both below `approve_below`: approved, public.
  Either above `reject_above`: rejected, hidden from everyone but the author.
  Anything between: held, for a curator. Negativity is never asked: an
  honest bad review is approved.
- **Observe first.** `config/review_moderation.yml` starts in `observe` mode:
  reviews are public on submit as before, and Jev's band is recorded on the
  review and in its event stream, so the thresholds (0.35 and 0.85, from
  TypeSafe's guardrails cookbook) can be measured on real Bosnian reviews.
  `enforce` makes a submitted review wait as pending until Jev answers.
- **Never raises, never loses.** No key, a timeout or an error is a named
  skip that holds the review for a curator; a review with no comment is
  approved without asking. The call runs in a job, never in the request.
- **What leaves usput:** the comment and the rating, nothing else. The
  privacy page says so in Bosnian and English. Jev is asked as `jev-latest`,
  and the version that answered is kept with each reading.
- **Ratings count approved reviews only**, recomputed on every change.
- **Curators decide in the admin**: a reviews queue that opens on held
  reviews, with Approve and Reject; nobody edits a traveller's words, only an
  admin deletes. Every step is an event in the review's stream:
  `ReviewSubmitted`, `ReviewJudged`, then `ReviewApproved`, `ReviewHeld` or
  `ReviewRejected` with who decided, Jev or a curator, and whether a curator
  overturned Jev.
- **One door to Jev**, held by a strict Enola law: nothing else calls
  `RubyLLM.judge`.

## Alternatives

- **Jev only flags** (2026-09-30). More open, but a flagged review was public
  until Jev answered and Jev never approved anything.
- **Jev approves, people reject.** Jev publishes the clear ones and everything
  else waits; keeps the judge-seam ADR intact. Not chosen.
- **Jev decides fully**, two outcomes and no queue. Most exposed to Jev's
  unmeasured quality in Bosnian, Croatian and Serbian. Not chosen.

## Consequences

- Moving to `enforce` is a configuration change once the thresholds are set
  from observe-mode readings labelled by a person; it needs the TypeSafe key.
- In enforce mode a review is invisible to others for the seconds Jev takes,
  and for as long as a curator takes when held.
- Guests no longer review; the form asks them to sign in.
- The privacy wording needs the operator's legal check.
