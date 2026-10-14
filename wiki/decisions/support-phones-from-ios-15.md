---
title: Support phones from iOS 15 and Android of about 2019
kind: decision
status: accepted
updated: 2026-10-14
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md
- sources/phone-brain/usput-ba/records-mobile-browser-compatibility-md--2026-10-14.md
- https://tailwindcss.com/docs/compatibility
- https://tailwindcss.com/blog/tailwindcss-v4-1
- config/importmap.rb
- Gemfile.lock
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
---
# Support phones from iOS 15 and Android of about 2019

## Context

On 2026-08-02 the operator deferred wider browser support
([decision](defer-wider-mobile-browser-support.md)). On 2026-10-14 they
asked that the application work on all devices. Two floors stand in the
way ([initiative](../initiatives/wider-mobile-browser-support.md)):

- **JavaScript.** Native import maps without a shim need Safari 16.4,
  Chrome 89 and Firefox 108. The iPhone 6s, 7 and first SE stop at iOS 15.8,
  whose Safari is 15.6, so the whole interactive layer is dead there today.
- **CSS.** Tailwind 4 is built for Safari 16.4, Chrome 111 and Firefox 128.
  Since 4.1 it falls back for OKLCH colours, avoids `@property` on older
  browsers and gives semi-transparent colours an RGBA fallback, so pages
  render acceptably from Safari 15.4 with some differences; anything older
  needs Tailwind 3.4 (tailwindcss.com compatibility page and 4.1 release
  notes, read 2026-10-14). usput builds with Tailwind 4.1.18; 4.3.3 is
  current.

The agent offered three floors: iOS 15 and Android of about 2019, back to
iOS 12 (esbuild transpiling and a Tailwind 3.4 downgrade), or every browser
including KaiOS and Opera Mini (a server-side fallback for every interactive
feature).

## Decision

The floor is **iOS 15 (Safari 15.4 and later) and Android phones of about
2019 whose browser still updates**: Chrome and Android WebView 99, Samsung
Internet 18, Firefox 115. It is reached without a build step:

- `es-module-shims` loads the import map where the browser cannot.
- Tailwind moves to the current 4.x release for its fallbacks.
- `localStorage` is reached through one guarded helper with an in-memory
  fallback, so private browsing cannot break a page.
- A browser below the floor, or one where JavaScript does not run, sees a
  notice and keeps the server-rendered pages.
- The floor is written in `README.md` and checked on a short device list.

**The numbers come from the code, checked on 2026-10-14.** The first
estimate was Chrome 80. Turbo 8's shipped build uses private methods (82
times) and logical assignment, which need Chrome 85 and Safari 15; usput's
controllers use private methods too. Then every rule in the Tailwind build
sits inside a cascade layer (`@layer theme`, `base`, `components`,
`utilities`), and a browser without layers drops each block whole, which
leaves the page unstyled below Chrome 99, Firefox 97 and Safari 15.4. Getting
under that would need a CSS build step, which this decision rules out, so the
floor is Chrome 99. A phone from 2019 meets it as long as its browser
updates; a WebView frozen below 99 gets the notice.

## Alternatives

- **Back to iOS 12, about 2017.** esbuild through `jsbundling-rails` with a
  browserslist target, and Tailwind 3.4 with every view's classes checked.
  Adds a Node build to development, Docker and CI. Not chosen.
- **Every browser, any phone.** KaiOS and Opera Mini run little or no
  JavaScript, so the map, the deck, check-ins and uploads would each need a
  server-side path. Not chosen.
- **Keep deferring.** The operator reversed that on 2026-10-14.

## Consequences

- The no-build setup (importmap, the standalone Tailwind CLI) stays.
- iOS 15.0 to 15.3 lack cascade layers, which Tailwind's output uses; those
  phones can update to 15.8 and are treated as below the floor.
- Every new controller or dependency is held to the floor; a library that
  needs more raises the floor in this page, by decision, not by accident.
  `test/javascript_floor_test.rb` fails on the newer features that are easy
  to reach for, and on any `localStorage` call outside the safe helper.
- `es-module-shims` runs rewritten modules from `blob:` URLs, so the content
  security policy allows `blob:` scripts.
- Herb lint and the system tests do not check the floor; the device list
  does.
