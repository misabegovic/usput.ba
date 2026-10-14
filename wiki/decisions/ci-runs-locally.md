---
title: CI runs on the operator's machine, with Enola's laws and Obie's gates
kind: decision
status: accepted
updated: 2026-10-14
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-10-14--usput--local-ci-enola-obie.md
- config/ci.rb
- bin/enola-gate
- bin/qualm-gate
- enola/constraints/usput.rb
- enola/constraints/recipes.yaml
- config/brakeman.ignore
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
# CI runs on the operator's machine, with Enola's laws and Obie's gates

## Context

Until 2026-10-14 every pull request ran `.github/workflows/ci.yml` on GitHub
Actions: rubocop, Herb lint, the unit suite with coverage, the 69 browser
tests and an advisory `undercover`. A separate `bin/ci` ran a local subset
plus the security audits the workflow never ran. The operator has no Actions
minutes to spare and asked for all CI to run locally; asked in the same
breath to use Enola in CI with constraints written for usput, and to try the
gems Obie Fernandez publishes for CI
([source](../../sources/conversations/2026-10-14--usput--local-ci-enola-obie.md)).
`main` requires one approving review and no status checks, so nothing
depended on the hosted run.

## Decision

- **`bin/ci` is the only CI** (`config/ci.rb`, Rails 8.1's
  `ActiveSupport::ContinuousIntegration`). It runs, in order: setup, rubocop,
  Herb lint, bundler-audit, importmap audit, Brakeman, the Enola gate,
  `exhale dry`, `qualm`, `tabula validate`, the unit suite with coverage,
  the browser tests and a seed replant. When every step passes,
  `gh signoff` marks the pushed commit green on GitHub. The workflow file is
  removed and the workflow disabled.
- **Enola's laws gate the architecture.** `enola-rb` 0.5.5 drives Enola
  0.4.19; `enola/constraints/` holds the four Rails laws its installer
  writes, the `ruby-conventions` recipe, and usput's own laws in
  `usput.rb`: only `Ai::OpenaiQueue` opens a chat with a model; the
  Platform DSL may not add a second door; the app never depends on the
  Platform DSL (strict); controllers never wait on a model; every Avo
  resource controller passes the policy gate (strict); services never read
  `params`; jobs and policies are named for what they are. Each law carries
  its reason; carve-outs are signed with an owner, reason and date. The
  `layered` recipe the installer bound is left out: usput's controllers use
  models directly, so it described an architecture usput does not follow.
- **The baseline is main as the branch left it.** `bin/enola-gate` grades
  against the snapshot pinned in `.enola/` at the merge base with
  `origin/main`, pins it there itself when run on that commit, and otherwise
  stops with the commands to pin it. Strict laws fail on any breach; the
  rest fail only on a breach the baseline did not carry.
- **Obie's gates.** `exhale dry --introduced-only` fails a branch that adds
  duplicated code; the 183 duplications already on main are left for later.
  `qualm` asks Jev whether a reviewer would push back on each changed file;
  each run is a paid call and the gem cannot join the bundle (it ships no
  build for every platform the lockfile resolves, Android among them), so
  `bin/qualm-gate` runs it where it is installed and an OpenRouter key is
  set, and otherwise says "not asked".
- **Security gates pass from the start.** Eighteen gems with advisories
  were updated conservatively and Brakeman moved to 8.1; its nine SQL
  warnings were read one by one, found to bind every value, and recorded in
  `config/brakeman.ignore` with the reason for each.

## Alternatives

- **Keep GitHub Actions.** Costs minutes the operator does not have.
- **A self-hosted Actions runner.** Keeps the workflow file, but still
  needs a machine kept online for it; `bin/ci` with `gh signoff` needs none.
- **Enola as a report only**, as the Enola initiative first proposed. The
  operator asked for its constraints in CI; findings other than declared
  laws stay reports.

## Consequences

- A pull request is green when its author ran `bin/ci` on the pushed commit;
  the signoff status says so. Nobody else's machine verifies it.
- `undercover` no longer runs: it was advisory, needs `libgit2`, and does not
  build on Termux.
- The Enola baseline is per machine (`.enola/` is ignored); a stale one stops
  the gate rather than grading against the wrong main.
- Breaking a law means amending `enola/constraints/` in the same pull
  request, with its reason, like amending a decision page.
