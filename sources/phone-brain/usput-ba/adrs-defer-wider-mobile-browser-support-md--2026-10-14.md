---
captured: 2026-10-14
source: "/home/muhamed/projects/phone-brain/wiki/usput.ba/adrs/defer-wider-mobile-browser-support.md"
digest: fnv1a:52252465879365e94a12074ced331344
agent_directed: 0
kind: snapshot
---
---
kind: decision
status: accepted
confidence: low
---

# ADR — Defer wider mobile browser support (do nothing for now)

## Context

The compatibility investigation (record: `wiki/usput.ba/records/mobile-browser-compatibility.md`) established two hard delivery floors: import maps without `es-module-shims` (JS dead below Safari 16.4 / Chrome 89 / Firefox 108) and Tailwind v4 output (visual degradation below Safari 16.4 / Chrome 111 / Firefox 128). The PRD `wiki/usput.ba/prds/wider-mobile-browser-support.md` frames the affected segment (iPhone 6s/7/SE-1 on iOS 15, Huawei/HMS frozen WebViews, older Android) as real for a Balkan tourism product.

The app's saving grace: Rails server-renders every page, so sub-floor devices get readable content — they lose the interactive layer (filters, maps, audio-tour controls, uploads, plan builder).

## Decision

**Do nothing for now.** Keep the current delivery stack (importmap, no shim, Tailwind v4) and accept the ~2023+ browser floor. No code changes. This decision is explicitly time-boxed by the revisit signals below, not a permanent "won't fix."

Chosen by the project owner on 2026-08-02 from four alternatives.

## Alternatives considered

1. **es-module-shims only** — smallest JS fix; leaves the CSS floor untouched. Rejected: half-measure that still ships a degraded experience to exactly the segment we'd be trying to save.
2. **jsbundling-rails (esbuild) + browserslist + Tailwind v3** — full transpiled pipeline, one coherent floor. Rejected (for now): node build added to dev/Docker/Kamal/CI, loses Rails 8 no-build simplicity, largest diff for a solo-maintainer project.
3. **Hybrid: es-module-shims + Tailwind v3 downgrade** — both floors fixed, stays no-build. Rejected (for now): two migrations, and moving back to Tailwind v4 later means a third. Deferred, not discarded — this is the leading candidate if the decision is revisited.
4. **Do nothing** — chosen. Zero cost; relies on server-rendered degradation.

## Consequences

- **Negative:** sub-floor phones get a read-only experience with no explanation; users may not understand why the app feels broken. The 78 unguarded `localStorage` call sites remain a latent crash risk in private-browsing modes even on supported browsers.
- **Positive:** zero pipeline churn; Tailwind v4 and importmap keep their ergonomics; no CI/Docker complexity added during a period of active feature development.
- **Neutral/cheap follow-ups still allowed** (not blocked by this ADR, individually shippable without the full bet): a `<noscript>`/broken-JS notice, the localStorage safe-helper, and a documented supported-browser floor in README/PLATFORM.md.

### Revisit signals

Reopen this decision when any of these become true:

- Analytics or user reports show a meaningful share (>5%?) of traffic from sub-floor browsers.
- A launch/marketing push targets audiences likely to carry older devices (e.g., rural BiH domestic tourism campaigns).
- Feature work starts depending on the broken-JS segment converting (audio tours, plan builder).
- Tailwind v3→v4 gap widens enough that a later downgrade becomes materially more expensive than doing it soon.

## Related

- PRD: `wiki/usput.ba/prds/wider-mobile-browser-support.md`
- Record (investigation): `wiki/usput.ba/records/mobile-browser-compatibility.md`
- Record (environment): `wiki/usput.ba/records/termux-android-setup-and-tzinfo-fix.md`
- Repo snapshot: `sources/github/2026-08-01--misabegovic-usput.ba.md`
