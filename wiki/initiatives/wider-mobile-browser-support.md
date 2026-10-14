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
and Android of about 2019 whose browser updates (Chrome and WebView 99,
Samsung Internet 18, Firefox 115), as decided on 2026-10-14, stated in `README.md`, with a visible notice below it
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

## Build notes

Built on 2026-10-14, on the branch `feat/phones-from-ios-15`:

- `es-module-shims` 2.8.4 is vendored (`vendor/javascript/es-module-shims.js`, MIT) and loaded, async, before the import map in all three layouts; the content security policy allows `blob:` scripts for it.
- Tailwind 4.1.18 to 4.3.3 in the gem, the Dockerfile's standalone CLI and `package.json`; the build carries 139 `@supports` colour fallbacks.
- `app/javascript/services/safe_storage.js` takes all 63 `localStorage` calls in the controllers and services (the 78 counted on 2026-08-02 had shrunk), and the 7 `sessionStorage` calls of the map and the deck filters, which the 2026-08-02 count missed; with storage refused, the map drew no places at all. The three inline theme scripts already had a `try`.
- `app/views/shared/_browser_floor.html.erb`, in every layout: a `<noscript>` notice, and a notice shown when the browser lacks cascade layers or cannot parse Turbo's syntax, styled inline so it shows without the stylesheet, in Bosnian and English.
- Tests: the layouts load the shim before the import map, the notice starts hidden, the policy allows `blob:`; no script uses a feature above the floor or touches `localStorage` directly; in Chrome the probe passes, and when every storage call throws the cookie banner still works and the map still draws its places (that test fails without the guard).
- Not yet done: a pass on real devices at the floor (an iPhone on iOS 15.8, an older Android WebView). Chrome is the only browser the system tests drive.

