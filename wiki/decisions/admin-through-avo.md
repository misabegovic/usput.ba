---
title: Admin work moves to Avo; the curator area is removed
kind: decision
status: accepted
updated: 2026-09-30
repos:
  - usput.ba
confidence: medium
supersedes: decisions/curator-dashboard-v2.md
sources:
  - sources/conversations/2026-09-30--usput--platform-direction.md
  - app/controllers/concerns/authenticatable.rb
  - app/models/user.rb
  - config/routes.rb
---
# Admin work moves to Avo; the curator area is removed

## Context

Usput has a hand-built curator area: eleven controllers under
`app/controllers/curator/`, a proposals flow (`ContentChange`), photo
suggestions, curator applications, a moderation queue for moments and an
admin section. It grew over months and was the subject of a large redesign
(#151) that was never merged. Users already carry one of three roles,
`basic`, `curator` and `admin` (`app/models/user.rb`).

The operator wants the whole area gone and replaced by an off-the-shelf
admin, keeping a curator role.

## Decision

The curator area is removed completely: its controllers, views, routes,
the proposals flow, photo suggestions and curator applications. Admin and
curator work happens in Avo, Community edition (free). The three roles on
`User` stay. Who may reach Avo, and what a curator may do there compared
with an admin, is enforced by usput's own code, since the Community edition
has no built-in authorization (unverified, 2026-09-30).

## Alternatives

- **Shrink the curator area to a small moderation desk.** Less new
  dependency, but keeps hand-built admin code to maintain.
- **Keep curators and fix `ContentChange` in place.** The path #151 and its
  salvage plan explored; rejected as the most code for the least gain.
- **Avo Pro** for built-in authorization and dashboards. Not chosen now; the
  role rules are few enough to enforce in the app.

## Consequences

- Avo is a mounted Rails engine, which Roundhouse cannot compile. See
  [Avo now, compile later](avo-now-compile-later.md).
- Curators lose the proposal flow: a curator edits directly within what their
  role allows, or not at all. Which one is decided in
  [Avo admin and roles](../initiatives/avo-admin-and-roles.md).
- Tables that only the curator area uses can be dropped, after any data worth
  keeping is exported. See
  [remove the curator dashboard](../initiatives/remove-curator-dashboard.md).
- The redesign in [curator dashboard v2](curator-dashboard-v2.md), the
  [per-resource suggestion models](per-resource-suggestion-models.md), the
  [origin tracking](ai-suggestions-carry-origin.md) that depended on them, and
  the [salvage plan](../initiatives/curator-dashboard-v2-salvage.md) are
  superseded.
