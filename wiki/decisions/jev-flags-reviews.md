---
title: Jev flags reviews; flagged reviews wait for an admin
kind: decision
status: accepted
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
supersedes: decisions/post-moderated-reviews.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- app/models/review.rb
- app/controllers/reviews_controller.rb
- sources/planning/REVIEW_APPROVAL_SYSTEM.md
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - repo
    relations:
    - rel: supersedes
      to: wiki/decisions/post-moderated-reviews.md
---
# Jev flags reviews; flagged reviews wait for an admin

## Context

Reviews on places, experiences and plans go live the moment they are
submitted. They are anonymous, carry no status, and every one of them counts
toward a place's average rating (`app/models/review.rb`,
`app/controllers/reviews_controller.rb`). Two designs for moderating them
were on the table and neither was built: the pre-moderation plan merged in
#152, where every review waits for approval, and the post-moderation design
from the unmerged #151, where curators flag and admins decide.

The operator wants a review that needs a human's eye kept off the public
site until an admin has looked, without making every traveller wait, and
without hiding a review from the person who wrote it.

## Decision

A review goes live when it is submitted, as today. Jev, TypeSafe's hosted
decision model, reads each new review and answers whether it is positive or
not. A review it reads as negative or unsafe is flagged: hidden from every
visitor except its author until an admin clears it or removes it. The author
always sees their own review, flagged or not.

Jev is a candidate, not a verdict. It never deletes anything, and an admin's
decision always wins. When the TypeSafe key is missing or the call fails, the
review stays live and unflagged; a failure to judge never blocks a traveller
and never raises. The operator holds the key and adds it to the app's
credentials.

## Alternatives

- **Every review waits for approval** (#152's plan). Safe, but every honest
  review waits hours or days, and the queue grows with traffic.
- **Jev triages, admin decides**: clearly positive reviews publish, all others
  wait. Rejected in favour of flagging only the reviews Jev reads as a
  problem, which keeps the site as open as it is today.
- **Local inference with ruby-laya**: no text leaves the app, but it needs
  model weights on the server. Rejected for now in favour of the hosted API.

## Consequences

- Every review's text is sent to TypeSafe. The privacy policy has to say so.
- Ratings and review counts must be computed from visible reviews only, or a
  hidden review would still move a place's score.
- "The author sees their own" needs an author identity. Reviews are anonymous
  today, so either reviews require sign-in or a guest review is tied to a
  signed browser token. The initiative decides which.
- Admins need a queue of flagged reviews. It lives in the new admin
  ([Avo](admin-through-avo.md)).
- The plan in [review approval system](../initiatives/review-approval-system.md)
  and the design in [post-moderated reviews](post-moderated-reviews.md) are
  superseded. Work is shaped in
  [Jev review flagging](../initiatives/jev-review-flagging.md).
