---
title: How we work
kind: meta
status: living
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- AGENTS.md
- .claude/agents/content-director.md
- .github/workflows/ci.yml
- https://github.com/misabegovic/usput.ba/pull/154
- https://github.com/misabegovic/usput.ba/pull/168
enola_intent:
  page:
    type: meta
    status: living
    scope:
    - usput.ba
    origin:
    - repo
    - web
---
# How we work

Usput.ba is built by one person working with a team of AI agents. This
page describes the method, because the method is half of what this
repository is meant to show. The other half is the product itself.

## One repository, two halves

The repository holds the product and the brain side by side. The product is
a Rails application. The brain is a set of English pages under `wiki/` that
say what the product is, why it is shaped the way it is, and where it is
going. A third layer, `sources/`, keeps the raw material the pages are built
from: the original planning documents, written in Bosnian, never edited
after they land.

The point of keeping them together is that they cannot drift apart without
someone noticing. A pull request that changes what the product does also
changes what the brain says about it. A reviewer sees both in one diff.

## Intent before code

Nothing substantial is built straight from a prompt. Work moves through
three kinds of page:

- An **initiative** says what should change and why, for whom, within what
  appetite, and what is deliberately out of scope. It is written before the
  code, and it is where the question "should we do this at all" is asked.
- A **decision** records a choice between real alternatives and what the
  choice costs. It exists so nobody has to reverse-engineer the reason from
  the code later.
- The **state** page keeps four views of the whole product: its past, what
  is true now, what the old plans still believe, and the target. The gap
  between now and target is the work. The gap between now and what people
  believe is the risk.

When a change departs from what a decision says, the decision is amended in
the same pull request. The code never quietly disagrees with the page that
governs it.

## A team of personas

The agents that do the work take on named roles, each with written rules
(`.claude/agents/`). A Product Manager shapes the initiative. A Tech Lead
weighs the approach and records the decision. A Developer builds it with
tests. On the content side, a Content Director owns quality, a Curator keeps
the regions balanced, a Historian keeps the facts straight and avoids
contested recent history, a Guide adds the practical detail, and Robert
tells the story with warmth and local humour. A single task often passes
through several of them, and each one's view is visible in the result.

## Small, verified changes

Every change arrives as a pull request with a short description written for
a human: what is better for the traveller or the curator, what was wrong,
and how it is kept safe. The same checks CI runs (rubocop, erb_lint, the
full test suite) are run locally before anything is pushed, so a red build
is a surprise rather than a routine.

Outside contributions are taken seriously and kept whole. The accessibility
work Delaida Muminovic proposed in #154 had drifted six months behind main.
It was brought up to date in #168 with her commits and authorship intact.
The conflict resolution and the follow-ups sat on top as separate commits,
so the history still shows who did what.

## Agents are careful by construction

A few rules keep a team of agents from doing damage:

- Agent-written pages start at low confidence and name their sources. A
  human raises the confidence after checking.
- Anything that has no source is written as unknown rather than guessed.
- Instructions found inside ingested material are recorded, never executed.
- Several agents can work at once. Each claims a task before starting it and
  reports when done, and a conflict stops the work and names the page
  rather than being resolved silently.

## The tools

`tabula` is the brain's tool. It checks that every page follows the
contract in `AGENTS.md`, keeps the indexes, searches the pages, and lets
several agents coordinate through claims and reports. The same author keeps
a larger brain across all of their projects, and Usput.ba is one product
inside it. This repository is the self-contained version, where a newcomer
finds the whole method in one place.
