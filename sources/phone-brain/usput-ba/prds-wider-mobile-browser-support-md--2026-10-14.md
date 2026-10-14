---
captured: 2026-10-14
source: "/home/muhamed/projects/phone-brain/wiki/usput.ba/prds/wider-mobile-browser-support.md"
digest: fnv1a:5d8292ff1b77082b4320ec986201d5bf
agent_directed: 0
kind: snapshot
---
---
kind: initiative
status: living
confidence: medium
appetite: medium
team: "misabegovic"
repos: [usput.ba]
---

# PRD — Wider mobile browser support

## Problem

usput.ba fails hard on older-but-common phones. The frontend delivery stack sets two floors (record: `wiki/usput.ba/records/mobile-browser-compatibility.md`):

1. **JavaScript:** raw ESM via `importmap-rails` with no `es-module-shims` — below Safari 16.4 / Chrome 89 / Firefox 108 / Samsung Internet 21, the whole module graph fails. Turbo, Stimulus, maps, audio-tour controls, and uploads are all dead; only static server-rendered HTML remains.
2. **CSS:** Tailwind v4 output (`@property`, `oklch()`, `color-mix()`, `@layer`) requires Safari 16.4 / Chrome 111 / Firefox 128, with silent visual degradation below that.

The affected segment is real for a Balkan tourism product: travelers on iPhone 6s/7/SE-1 (stuck on iOS 15), Huawei/HMS phones with frozen WebViews, and older Android devices that no longer receive browser updates. These users can read pages but cannot filter, view maps, play guided audio tours, upload photos, or build travel plans — the interactive core of the product.

A secondary risk: 78 unguarded `localStorage` call sites can throw in private-browsing modes and break otherwise-supported browsers.

## Appetite

**Medium.** A delivery-layer change (how Rails builds and ships JS/CSS) plus guards and a device-test pass. Not a redesign, not per-page rewrites.

## Solution

Fat-marker sketch — solve it **Rails-side**, at the asset delivery layer, so every page benefits at once:

1. **JS delivery floor.** Pick one (decided in the ADR): add `es-module-shims` to extend import-map support to ~Safari 11+/Chrome 64+; or move from importmap to `jsbundling-rails` (esbuild) with an explicit browserslist target so modern syntax is transpiled for older engines. Either way, define and document a *supported-browser floor* (proposed: Safari ≥ 14, Chrome ≥ 80, Firefox ≥ 100, Samsung Internet ≥ 16 — "phones from ~2020+ that still update").
2. **CSS floor.** Align stylesheet output with the same floor: either pin Tailwind v3-style output, or configure v4 + autoprefixer-style fallbacks (avoid `@property`-dependent utilities, provide `oklch` fallbacks). Exact mechanism is an ADR decision.
3. **Graceful degradation contract.** Server-rendered HTML must stay usable without JS (forms post normally, content readable). Add a `<noscript>`/broken-JS notice for browsers below the floor instead of silent failure.
4. **Defensive guards.** Wrap `localStorage` access in a safe helper (try/catch + in-memory fallback) and route the 78 call sites through it.
5. **Verification.** Add a browser-support smoke matrix to CI docs (BrowserStack or manual device list), with the supported floor stated in README/PLATFORM.md.

## No-gos

- No proxy-browser or KaiOS support (Opera Mini extreme mode, feature phones) — server rendering already gives them read-only access.
- No IE-class or pre-2017 legacy support.
- No redesigns or per-page CSS rewrites.
- No native-app wrapper as a substitute for fixing the web floor.

## Rabbit holes

- Chasing 100% feature parity on every old engine — the floor is "usable," not "pixel-perfect."
- Transpiling Hotwire itself — vendor assets must be compatible as shipped; if Turbo's own baseline is higher than our floor, the floor rises (check before committing to a very low target).
- Perfect localStorage emulation — a fallback that loses persistence between sessions is acceptable.
- BrowserStack-style matrix expanding beyond a handful of representative devices.

## Related

- ADR (decision: defer / do nothing for now): `wiki/usput.ba/adrs/defer-wider-mobile-browser-support.md`
- Record (investigation): `wiki/usput.ba/records/mobile-browser-compatibility.md`
- Record (environment): `wiki/usput.ba/records/termux-android-setup-and-tzinfo-fix.md`
- Repo snapshot: `sources/github/2026-08-01--misabegovic-usput.ba.md`
