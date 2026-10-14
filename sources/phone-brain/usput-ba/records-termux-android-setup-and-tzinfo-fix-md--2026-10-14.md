---
captured: 2026-10-14
source: "/home/muhamed/projects/phone-brain/wiki/usput.ba/records/termux-android-setup-and-tzinfo-fix.md"
digest: fnv1a:bed0e405904df7eeaf8437be8d0e9f65
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

# Record — usput.ba runs and tests green on Termux/Android

## What shipped

**usput.ba PR #159** — `fix: bundle tzinfo-data for platforms without system zoneinfo`: https://github.com/misabegovic/usput.ba/pull/159 (merged 2026-08-02, squash commit `4ffdeaf`). Minimal diff: Gemfile +3, Gemfile.lock +2 (spec added manually to avoid platform churn; darwin/linux entries untouched). CI `test` check green (3m21s) on the PR.

## Environment bring-up (Termux on Android)

Full Rails 8 stack provisioned on-device (2026-08-02):

- `pkg install ruby postgresql` — Ruby 3.4.1 (Gemfile targets 3.3, works), PostgreSQL 18 with data in `$PREFIX/var/lib/postgresql/data`, trust auth, user `postgres`.
- `bundle config set --local without ci` — `undercover`→`rugged` (libgit2) cannot build on Android; Gemfile already marks it CI-only.
- Nokogiri: `bundle config set build.nokogiri "--use-system-libraries --with-cflags=-Wno-default-const-init-field-unsafe"` — Termux ruby headers emit `-Wdefault-const-init-field-unsafe`, and mkmf's `-Werror` flag probes then fail every check.
- tzinfo: Android has no zoneinfo directory (bionic single-file tzdata is unreadable by TZInfo) → PR #159.
- Tailwind: `tailwindcss-linux-arm64` symlink at repo root → `node_modules/.bin/tailwindcss`; `npm i --no-save lightningcss@1.30.2` (1.30.1 has no `lightningcss-android-arm64` build); `@tailwindcss/oxide` install script approved via Termux npm wrapper.
- PostgreSQL running; `bin/rails db:prepare` (dev + test) succeeded, seeds loaded (`curator`/`curator123`, `user`/`user123`).

## Verification

- Full suite on-device: **2393 runs, 5617 assertions, 0 failures, 0 errors, 1 skip** (~152s).
- Dev server on `127.0.0.1:3000`: `/`, `/explore`, `/mine-check`, `/imprint`, `/up` all 200.
- System tests not run (no browser driver on device).

## Follow-ups

- [ ] Dev server was left running on the phone (PID from `pgrep -f "rails server"`); stop when done.
- [ ] Termux-only local artifacts in the usput.ba working tree: `vendor/bundle/`, `tailwindcss-linux-arm64` symlink, `.bundle/config`. Do not commit.
- [ ] If CI ever needs Android-like coverage, the nokogiri cflags + `without ci` notes above are the recipe.

## Related

- Inbox insight: `usput-ba-rails-8-runs-and-tests-green-on-termux`
- Repo snapshot: `sources/github/2026-08-01--misabegovic-usput.ba.md`
