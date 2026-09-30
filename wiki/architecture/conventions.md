---
title: Conventions
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- CLAUDE.md
- .claude/CLAUDE.md
- AGENTS.md
- .rubocop.yml
- .erb-lint.yml
- .github/workflows/ci.yml
- config/application.rb
- config/initializers/i18n.rb
- config/locales/en.yml
- config/locales/bs.yml
- app/views/shared/_cookie_consent.html.erb
- app/helpers/prompt_helper.rb
- app/services/ai/bih_context.rb
- app/assets/stylesheets/application.tailwind.css
- app/assets/tailwind/application.css
- package.json
- Gemfile
- sources/planning/DEVELOPER_ONBOARDING.md
- sources/planning/TAILWIND_GUIDE.md
- sources/planning/LEARNINGS.md
- sources/planning/VISION.md
- https://github.com/misabegovic/usput.ba/pull/167
depends_on:
- architecture/overview.md
- architecture/ai-content-pipeline.md
- architecture/frontend.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/architecture/overview.md
    - rel: depends-on
      to: wiki/architecture/ai-content-pipeline.md
    - rel: depends-on
      to: wiki/architecture/frontend.md
---
# Conventions

How code is written in this repository. The rules come from `CLAUDE.md`,
`.claude/CLAUDE.md` and `AGENTS.md`, the lint configuration, the planning
documents under `sources/planning/`, and what the git history shows. Where
the written rule and the code disagree, both are named.

## Rules that bind every change

1. **Tests are mandatory.** "No code without tests" appears in `CLAUDE.md`,
   `.claude/CLAUDE.md`, `AGENTS.md` and
   `sources/planning/DEVELOPER_ONBOARDING.md`, which adds that the Tech Lead
   does not approve a pull request without them. The framework is Minitest,
   pinned to 5.x because 6.0 breaks Rails 8.1 (`Gemfile`), with Capybara and
   Selenium for system tests and fixtures rather than factories. Tests live
   under `test/` in `models`, `controllers`, `services`, `lib/platform`,
   `integration`, `system`, `jobs` and `helpers`. The style from
   `.claude/CLAUDE.md` is `test "describes what it tests" do` with setup,
   action and assertion in that order.
2. **Follow the patterns already in the code.** Stated in `CLAUDE.md` and
   `AGENTS.md`. `DEVELOPER_ONBOARDING.md` adds single-responsibility
   service objects over "god objects", and asks newcomers to take
   architecture questions to the Tech Lead with the options they
   considered.
3. **Ask when unsure.** "Better to ask than to get it wrong"
   (`CLAUDE.md`, `.claude/CLAUDE.md`).
4. **AI prompts live in `app/prompts/`.** Never inline in a service. Static
   prompts are `.md`, prompts with variables are `.md.erb`, and services load
   them with `PromptHelper#load_prompt(path, **vars)`
   (`.claude/CLAUDE.md`, `app/helpers/prompt_helper.rb`). The Platform DSL's
   generation executor still builds prompts inline; see
   [AI content pipeline](ai-content-pipeline.md).
5. **Bosnian content uses ijekavica**: "historija", not "istorija";
   "rijeka", not "reka" (`CLAUDE.md`, `AGENTS.md`). The same rule is
   written into every AI prompt through `Ai::BihContext`, and
   `sources/planning/VISION.md` wants generated Bosnian text checked for
   ekavica before it is saved. `sources/planning/TAILWIND_GUIDE.md` is
   itself written partly in ekavica ("korišćenje", "Lepši", "Primeri").
6. **Atomic commits.** Small, focused commits and small pull requests
   (`.claude/CLAUDE.md`, `DEVELOPER_ONBOARDING.md`).

## Lint and style

- **Ruby.** `.rubocop.yml` inherits `rubocop-rails-omakase`, targets Ruby
  3.3, enables new cops, and excludes `db/schema.rb`, migrations, `vendor`,
  `node_modules`, `bin`, `tmp` and `log`. CI runs
  `bundle exec rubocop --parallel`.
- **ERB.** `.erb-lint.yml` enables the default linters plus space around
  ERB tags, trailing whitespace, HTML5 void tags without a slash, ERB
  safety through `better_html`, right trim with `-%>`, a final newline,
  no instance variables in partials, no JavaScript tag helper, and `<%#`
  comments. Hard-coded string detection is off "until an i18n audit". CI
  runs `bundle exec erb_lint --lint-all`.
  `DEVELOPER_ONBOARDING.md` still mentions `herb lint`; the configured tool
  is erb_lint.
- **Coverage.** CI runs the suite with `COVERAGE=true` and then
  `undercover` against the base branch on pull requests. Undercover is
  advisory for now (`continue-on-error: true`,
  `.github/workflows/ci.yml`).
- **Ruby files** start with `# frozen_string_literal: true` in most of
  `lib/platform/` and `app/services/ai/`, but not everywhere (for example
  `app/services/ai.rb` and `app/services/mine_checker/*.rb` do not).

## Commit and pull request style

`.claude/CLAUDE.md` and `DEVELOPER_ONBOARDING.md` prescribe a
`[Area] Imperative title` subject with a bullet body, for example
`[Platform] Add search_content tool`, and branch names such as
`feature/...`, `fix/...`, `refactor/...`. The history does not follow the
bracket prefix: only two subjects in the log carry one (#124 and #152).
Since #161 (2026-09-15) subjects are plain sentences about the outcome for a
traveller, with the pull request number: "Walk a plan as a stack of cards,
check in, and capture the moment (#164)". Bodies of #161 to #167 are bullet
lists that explain behaviour and its reason in plain words, may add an
"Honest note" or "Note for review", and end with the test totals and
"Rubocop and erb_lint clean", as in "Tests: 2643 runs, 6419 assertions, 0
failures, 0 errors."

## Internationalization

`config/application.rb` makes 16 locales available (`en bs hr de es fr it
pt nl pl cs sk sl sr tr ar`), sets the default locale to `en`, and turns
fallbacks on. `config/initializers/i18n.rb` sets script-aware fallback
chains: Bosnian falls back to Croatian then English, Croatian to Bosnian
then English, and Serbian (Cyrillic) straight to English so Latin text never
replaces Cyrillic.

User-facing text goes through `t()` (`DEVELOPER_ONBOARDING.md` PR checklist:
"no hard-coded strings, use I18n"). New keys belong in both
`config/locales/bs.yml` and `config/locales/en.yml`; commits such as #167
("four missing translations added") fix keys that were missing. The views
also pass `default:` strings to `t()` 477 times. Because the default locale
is English, a `default:` in Bosnian is shown to every locale whose chain
misses the key; `app/views/shared/_cookie_consent.html.erb` has such
Bosnian defaults. The rule that defaults must not be Bosnian and that every
key must exist in bs and en is the working practice this page records
(unverified, 2026-09-29: no single written source states it).
`en.yml` has 1,805 lines against 1,574 in `bs.yml`.

## JavaScript and CSS

- **Stimulus only.** `DEVELOPER_ONBOARDING.md` forbids inline `<script>`
  handlers and jQuery; behaviour lives in Stimulus controllers under
  `app/javascript/controllers/`, with shared browser logic in
  `app/javascript/services/`. See [Frontend](frontend.md).
- **Tailwind.** `sources/planning/TAILWIND_GUIDE.md` asks that every view
  use Tailwind classes, mobile first, with a dark variant considered each
  time, and describes custom `primary` and `accent` palettes, component
  classes such as `.btn-primary` and `.card`, and the forms, typography and
  aspect-ratio plugins. The palette is real: the `@theme` block of
  `app/assets/stylesheets/application.tailwind.css` defines
  `--color-primary-*` and `--color-accent*`. Parts of the guide are stale:
  it names `tailwind.config.js`, which does not exist in Tailwind 4, and
  `npm run build:css` writes `app/assets/builds/tailwind.css`, while
  development watches through `app/assets/tailwind/application.css`, a file
  that only re-exports the real stylesheet (`package.json`,
  `app/assets/tailwind/application.css`).

## Content patterns from past maintenance

`sources/planning/LEARNINGS.md` (2026-02-02) keeps patterns from deleted
maintenance scripts: upsert a `Translation` with `find_or_initialize_by` on
type, id, locale and `field_name`; add experience types through
`LocationExperienceType`; append a location to an experience at the next
`position`; a good description is 150 to 300 characters, specific and free
of clichés; tag sets per category; and a sensitive-content table
(respectful for war memorials, neutral for religious sites, no AI
generation for genocide memorials).

## Onboarding pointers

`DEVELOPER_ONBOARDING.md` starts a developer with `bin/setup`, `bin/dev`
and `bin/rails test`, lists the quality tools, and warns that every merge to
`main` goes to production with no instant rollback. It also points to
`.claude/planning/`, which is now `sources/planning/`, and lists pgvector and
a `lib/platform/brain.rb` and `tools/` tree that no longer exist; see
[Architecture overview](overview.md) and [Platform DSL](platform-dsl.md).
