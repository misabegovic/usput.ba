---
title: Herb lints the ERB templates; erb_lint is removed
kind: decision
status: accepted
updated: 2026-10-14
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-10-14--usput--tooling-models-langfuse-jev.md
- .herb.yml
- package.json
- .github/workflows/ci.yml
- config/ci.rb
- Gemfile
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - repo
---
# Herb lints the ERB templates; erb_lint is removed

## Context

The templates under `app/` were linted by erb_lint 0.9.0 with better_html for
ERB safety, configured in `.erb_lint.yml` and run in CI as
`bundle exec erb_lint --lint-all`. erb_lint checks ERB tags and whitespace;
it does not parse the HTML around them. The operator asked on 2026-10-14 to
use the latest Herb and chose to replace erb_lint rather than run both
([answers](../../sources/conversations/2026-10-14--usput--tooling-models-langfuse-jev.md)).

Herb 0.11.0 parses HTML and ERB as one document and ships 146 lint rules,
including HTML validity and accessibility. Its linter is the npm package
`@herb-tools/linter`; the `herb` gem's `lint` command delegates to it.

## Decision

- `@herb-tools/linter` is a pinned dev dependency in `package.json`, run as
  `npm run lint:erb`. CI sets up Node 22 and runs it with GitHub annotations;
  `bin/ci` runs it as "Style: ERB".
- `.herb.yml` sets the Action View framework, lints `app/` only (not the
  static pages in `public/`), fails on errors, and turns off five rules, each
  with its reason in the file: two false positives (nested forms through
  `render layout:`, a nested link behind `linked:`), the `href="#"` links a
  Stimulus controller fills in, ERB output in attribute names (`tag.attributes`
  and `checked` toggles), and the collection-render style rule.
- Warnings, info and hints are printed and do not fail the build.
- erb_lint, better_html and their configuration files are removed.

The first run found 47 errors; the ones that were real were fixed in the same
change: the radius options toggle `selected` through control flow, a stray
`<style>` in the body moved to the stylesheet, a place photo gained its alt
text and the video frame its title, and two unused form builders were
dropped.

## Alternatives

- **Run both, then drop erb_lint.** Safer while Herb's rules are tuned, at the
  cost of two linters disagreeing about the same file. Not chosen.
- **Keep erb_lint.** No HTML parsing, no accessibility rules.

## Consequences

- CI needs Node for one step; the Docker image does not, since linting is not
  part of the build.
- A Herb upgrade can add rules. `herb-lint --upgrade` bumps `version:` in
  `.herb.yml` and turns new rules off until they are looked at.
- The five disabled rules are a list to revisit; the collection-render rule in
  particular is a refactor worth doing on its own.
