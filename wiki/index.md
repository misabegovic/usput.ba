---
title: usput
kind: meta
status: living
updated: 2026-09-29
repos:
- usput.ba
sources:
- AGENTS.md
- README.md
enola_intent:
  page:
    type: meta
    status: living
    scope:
    - usput.ba
    origin:
    - repo
---
# usput

Usput.ba helps people discover Bosnia and Herzegovina: places, experiences
and plans across the whole country, written with care and walked on foot
with a phone in hand. This wiki is the product's brain. It says what the
product is, why it is built the way it is, and where it is going, so that a
person or an agent can change the code knowing what they are changing.

The rules for this brain are in [`AGENTS.md`](../AGENTS.md). The original
Bosnian plans the pages are built from are kept, unedited, under
`sources/planning/`.

## Start here

- [How we work](how-we-work.md): the method this repository demonstrates.
- [Product state](state.md): the past, what is true now, what the old plans
  still believe, and the target for the next 90 days.

## Shelves

- [Product](product/index.md): purpose, personas, domain vocabulary, features.
- [Architecture](architecture/index.md): the stack, the Platform DSL, the AI
  content pipeline, Mine Checker, conventions, the frontend.
- [Decisions](decisions/index.md): why the code is shaped the way it is.
- [Initiatives](initiatives/index.md): what is in flight, what is proposed,
  and the open issues.

## What changed recently

- 2026-09-29: this brain was started. Location accessibility, contributed by
  Delaida Muminovic, shipped through #168. The review approval plan (#152)
  was merged as a proposal.
- 2026-09-15: travellers can explore, walk a plan as a deck of cards, check
  in and capture moments, with or without an account (#161 to #167).
