---
title: Wider mobile browser support
kind: initiative
status: proposed
updated: 2026-10-14
repos:
- usput.ba
confidence: low
depends_on:
- decisions/defer-wider-mobile-browser-support.md
sources:
- sources/phone-brain/usput-ba/prds-wider-mobile-browser-support-md--2026-10-14.md
- sources/phone-brain/usput-ba/records-mobile-browser-compatibility-md--2026-10-14.md
- sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md
- config/importmap.rb
- app/assets/stylesheets/application.tailwind.css
---
# Wider mobile browser support

Shaped in the operator's phone brain on 2026-08-02, deferred the same day,
and brought here on 2026-10-14, when the operator asked that the application
work on all devices. The floor is now decided
([decision](../decisions/support-phones-from-ios-15.md)); the build follows.

## Objective

Usput works, not only reads, on phones from iOS 15 (Safari 15.4 and later)
and Android of about 2019 (Chrome and WebView 80, Samsung Internet 13), as
decided on 2026-10-14, stated in `README.md`, with a visible notice below it
instead of a silently broken page.

## Background

Today's floor is Safari 16.4, Chrome 111 and Firefox 128, set by native
import maps without a shim and by Tailwind 4's CSS (investigation of
2026-08-02, against commit `4ffdeaf`). Pages render on the server, so a
phone below the floor reads content but cannot filter, open the map, play an
audio tour, upload a photo or build a plan. 78 `localStorage` calls have no
guard and can throw in private browsing. The same investigation found
Leaflet, the `<audio>` player, geolocation, the service worker guard and the
viewport meta fine on any browser past the import-map floor.

## Affected personas

- **Travellers on older phones:** iPhone 6s, 7 and the first SE on iOS 15,
  Huawei phones with frozen WebViews, Android phones without browser
  updates.
- **Every traveller in private browsing,** through the unguarded
  `localStorage` calls.

## Scope

Solved at the asset delivery layer, so every page benefits at once:

1. **JavaScript floor:** `es-module-shims`, keeping importmap and no build
   step (decided 2026-10-14).
2. **CSS floor:** Tailwind's current 4.x release for its fallbacks, which
   render from Safari 15.4; no downgrade to 3.
3. **A degradation contract:** server-rendered pages stay usable without
   JavaScript, and a browser below the floor sees a notice.
4. **Guards:** one safe `localStorage` helper with an in-memory fallback,
   and the 78 calls routed through it.
5. **Verification:** a short device list for a smoke pass, and the floor
   written in `README.md`.

## No-gos

- No proxy browsers or KaiOS beyond the read-only pages they already get.
- Nothing older than about 2017.
- No redesign and no per-page CSS rewrites.
- No native wrapper app in place of fixing the web floor.

## Rabbit holes

- Full feature parity on every old engine: the floor is "usable", not
  "pixel-perfect".
- Hotwire's own baseline: if Turbo needs more than the floor, the floor
  rises; check before promising a low one.
- A perfect `localStorage` emulation: losing persistence between sessions is
  acceptable.
- A device matrix that keeps growing.

## Appetite

Medium: a delivery-layer change, guards and one device pass.

## Decision needed

**Decided on 2026-10-14** ([answer](../../sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md)): start now, at the iOS 15 and Android 2019 floor, through `es-module-shims` and Tailwind 4's fallbacks, without a build step ([decision](../decisions/support-phones-from-ios-15.md)). The deferral of 2026-08-02 is superseded.

- **The device list** for the check: which real phones or emulators, and
  whether a hosted device cloud is worth paying for.
