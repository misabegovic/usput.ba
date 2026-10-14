---
captured: 2026-10-14
source: "/home/muhamed/projects/phone-brain/wiki/usput.ba/records/mobile-browser-compatibility.md"
digest: fnv1a:71c95a303d8a8078a6bc4885939dfeda
agent_directed: 0
kind: snapshot
---
---
kind: record
status: delivered
confidence: low
sources:
  - sources/github/2026-08-01--misabegovic-usput.ba.md
---

# Record — Mobile browser compatibility investigation (usput.ba)

**Question:** can usput.ba run on all browsers on all phones?
**Short answer:** No. It runs well on *current* browsers, but has a hard JS floor and a CSS floor that exclude older phones. Investigation date: 2026-08-02, against local checkout at commit `4ffdeaf`.

## Hard floor 1 — native import maps (no shim)

The app ships raw ESM via `importmap-rails` 2.2.2 with `javascript_importmap_tags` in all three layouts (`application`, `curator`, `new_design`). No `es-module-shims` is present anywhere (checked gem assets, `config/importmap.rb`, layouts). Native import maps require:

- Chrome/Edge ≥ 89, Safari ≥ 16.4 (iOS 16.4, March 2023), Firefox ≥ 108, Samsung Internet ≥ 21 *(high confidence — well-documented feature gates)*

**Consequence:** below these versions the module graph never executes — Turbo, Stimulus, and every controller (filters, maps via Leaflet, audio-tour controls, photo upload, PWA prompts) are dead. Server-rendered HTML still renders, so pages are readable but the app is effectively static *(high confidence on mechanism; medium on exact UX per page — progressive enhancement was not audited page-by-page)*.

**Real-world exposure:** iPhone 6s/7/SE-1 (stuck on iOS 15.x → Safari 15), Huawei/HMS devices with frozen Chromium WebViews, KaiOS feature phones (Firefox 48-era engine), Opera Mini in extreme data-savings mode (proxy rendering, no client JS at all).

## Hard floor 2 — Tailwind CSS v4 output

The compiled `app/assets/builds/tailwind.css` (v4.1.8) contains `@property` rules (60+ custom properties), `oklch()` colors, `color-mix()`, and `@layer`:

- `@property`: Firefox ≥ 128 (July 2024), Safari ≥ 16.4, Chrome ≥ 85
- Cascade `@layer`: Safari ≥ 15.4, Chrome ≥ 99, Firefox ≥ 97
- `oklch()`: Safari ≥ 15.4, Chrome ≥ 111, Firefox ≥ 113

**Consequence:** Tailwind v4's own baseline is Safari 16.4 / Chrome 111 / Firefox 128. Below that, transforms/shadows/gradients degrade (unregistered custom properties don't animate or compose) and colors may fall back to unset/invalid *(high confidence on feature gates; medium on visible severity — depends which utilities each page uses)*. No `:has()` usage found *(good)*.

## Web APIs used by Stimulus controllers

Observed across 30+ controllers: `localStorage` (78 uses — travel-profile sync), `navigator.geolocation` (5+ — mine-check, explore), `fetch`, `IntersectionObserver`, `AbortController`, `navigator.clipboard`, `matchMedia`, `navigator.onLine` (offline banner). All safe on any browser that clears the import-map floor *(high confidence)*. Caveats:

- Geolocation requires HTTPS and a user permission grant — fine in prod, but worth noting for the Bosnia field-use scenario (rural data + denied permission = mine-check silently unusable unless errors are surfaced; `mine_check_controller` does surface API errors, per test logs).
- `localStorage` can throw in some private-browsing modes; 78 call sites make a single unguarded throw potentially app-breaking *(low-medium confidence — not audited for try/catch coverage)*.

## Things that are fine

- **Audio tours:** plain `<audio>` element playback (`audio_tour_controller`), triggered by user gesture — universal on mobile, satisfies autoplay policies.
- **Maps:** Leaflet 1.9.4, vendored — excellent mobile/touch support, works even on fairly old engines.
- **PWA:** service worker registered behind a `"serviceWorker" in navigator` guard (`application.html.erb`); install prompt handled with iOS-specific UA fallback (`pwa_install_controller`) — degrades gracefully where unsupported.
- **Viewport meta** present; server-side rendering means content is never gated on JS alone.

## Verdict

| Segment | Status |
|---|---|
| iOS 16.4+ Safari, current Chrome/Firefox/Samsung Internet Android | Full support *(high)* |
| iOS 15.x Safari (iPhone 6s/7/SE-1), Firefox < 128 | JS fully dead and/or CSS degraded *(high)* |
| KaiOS, Opera Mini (proxy mode), ancient WebViews | Effectively unsupported *(high)* |

The practical floor is **Safari 16.4 / Chrome 111 / Firefox 128** — i.e., phones from ~2023+ or updated devices. "All browsers on all phones" would require: (1) adding `es-module-shims` + compiling the import map to a shim-compatible build, or moving to a bundler with transpilation; (2) pinning Tailwind to v3 or compiling v4 with fallbacks; (3) auditing localStorage guards.

## Related

- Record: `wiki/usput.ba/records/termux-android-setup-and-tzinfo-fix.md`
- Repo snapshot: `sources/github/2026-08-01--misabegovic-usput.ba.md`
