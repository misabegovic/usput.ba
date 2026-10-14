---
title: Defer wider mobile browser support
kind: decision
status: superseded
updated: 2026-10-14
repos:
- usput.ba
confidence: low
sources:
- sources/phone-brain/usput-ba/adrs-defer-wider-mobile-browser-support-md--2026-10-14.md
- sources/phone-brain/usput-ba/records-mobile-browser-compatibility-md--2026-10-14.md
- sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md
- config/importmap.rb
- package.json
enola_intent:
  page:
    type: decision
    status: superseded
    scope:
    - usput.ba
    origin:
    - other
    - repo
---
# Defer wider mobile browser support

Recorded first in the operator's phone brain on 2026-08-02 and brought into
this repository on 2026-10-14, when the operator asked that everything about
usput live here. **Superseded the same day**: the operator asked that the
application work on all devices, and chose a floor of iOS 15 and Android from
about 2019 ([support phones from iOS 15](support-phones-from-ios-15.md)).

## Context

An investigation on 2026-08-02, against commit `4ffdeaf`, found two delivery
floors below which usput stops working on a phone:

- **JavaScript.** The app ships native ES modules through `importmap-rails`
  with no `es-module-shims`. Below Safari 16.4, Chrome 89, Firefox 108 and
  Samsung Internet 21 the module graph never runs: Turbo, Stimulus, maps,
  audio tour controls and uploads are dead.
- **CSS.** Tailwind 4's output uses `@property`, `oklch()`, `color-mix()` and
  cascade layers, which need Safari 16.4, Chrome 111 and Firefox 128; below
  that, styling degrades silently.

The phones below the floor are real for a Balkan travel product: iPhone 6s,
7 and the first SE on iOS 15, Huawei phones with frozen WebViews, older
Android. Because every page is rendered on the server, they still get
readable pages; they lose the interactive layer. A second risk was named: 78
`localStorage` calls without a guard can throw in some private-browsing
modes. See [wider mobile browser support](../initiatives/wider-mobile-browser-support.md).

## Decision

Do nothing for now. Keep importmap without a shim and Tailwind 4, and accept
a browser floor of roughly 2023 and later. The operator chose this on
2026-08-02 from four alternatives. It is time-boxed by the revisit signals
below, not a permanent refusal.

Cheap follow-ups stay allowed without reopening the decision: a notice when
JavaScript does not run, a guarded `localStorage` helper, and a stated
supported-browser floor in `README.md`.

## Alternatives

1. **`es-module-shims` only.** The smallest JavaScript fix; leaves the CSS
   floor where it is. Rejected as a half-measure.
2. **`jsbundling-rails` with esbuild, a browserslist target and Tailwind 3.**
   One coherent floor, at the cost of a Node build in development, Docker and
   CI, and the largest diff. Rejected for now.
3. **`es-module-shims` plus a Tailwind 3 downgrade.** Both floors fixed and
   still no build step, but two migrations and a third to return to
   Tailwind 4. Deferred, and the leading candidate if this is reopened.
4. **Do nothing.** Chosen.

## Consequences

- A phone below the floor gets a read-only site with no explanation.
- The unguarded `localStorage` calls remain a crash risk in private browsing
  even on supported browsers.
- Pipeline, Docker and CI stay as they are.
- **Revisit when** analytics or reports show a meaningful share of traffic
  from browsers below the floor (the source suggests more than 5%), a
  campaign targets travellers likely to carry older phones (rural domestic
  tourism, for example), feature work depends on those visitors converting
  (audio tours, the plan builder), or the gap between Tailwind 3 and 4 grows
  enough to make a later downgrade much dearer.
- Linting with Herb (2026-10-14) does not change either floor.
