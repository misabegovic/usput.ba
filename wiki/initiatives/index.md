---
title: Initiatives
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
sources:
- AGENTS.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - repo
---
# Initiatives

Work in flight and work proposed. A proposed initiative is a question still open: whether to do it, and in what shape.

## The rebuild

On 2026-09-30 the operator decided to rebuild usput from scratch, in place, with no backwards compatibility and an empty database, while the old site stays up until launch ([direction](../../sources/conversations/2026-09-30--usput--platform-direction.md)). Version 1 covers places and explore, plans and walking, reviews with Jev, and the AI content pipeline. The pages below are proposed, listed in the order they would be built.

1. [Secure sessions](secure-sessions.md): accounts through Devise by email, confirmation and reset through Postmark, sign-out everywhere, Google sign-in, the guest walk kept.
2. [Avo admin and roles](avo-admin-and-roles.md): every admin and curator task in Avo Community, role rules in our own code.
3. [What the rebuild leaves out: the curator dashboard](remove-curator-dashboard.md): the curator area, proposals, photo suggestions and applications, and why.
4. [RubyLLM 2 in the rebuild](rubyllm-2-upgrade.md): one LLM seam, structured output, prompts only from files, jobs.
5. [Langfuse for LLMOps](langfuse-llmops.md): tracing, prompt management, A/B tests and cost from day one.
6. [Jev review flagging](jev-review-flagging.md): reviews stay live, flagged ones wait for an admin, authors see their own.
7. [Semantic search with pgvector](pgvector-semantic-search.md): one embedding column on the search index, hybrid ranking, similar places.
8. [Enola for usput](enola-for-usput.md): an architecture page, laws, a baseline pinned before the rewrite deletes anything.
9. [Roundhouse: analysis now, compiling later](roundhouse-analysis-and-compile.md): `roundhouse check` clean from the first commit, and the compile blockers named.
10. [Paid audio tours](paid-audio-tours.md): a weekly, monthly or yearly subscription through Stripe; everything else stays free.

## In flight or shipped

- [Location accessibility](location-accessibility.md): shipped 2026-09-29; the gaps that remain.

## Superseded

- [Review approval system](review-approval-system.md): replaced by Jev review flagging (2026-09-30).
- [Curator dashboard v2 salvage](curator-dashboard-v2-salvage.md): replaced by removing the curator area for Avo (2026-09-30).

## Backlog

- [Open issues](open-issues.md): the GitHub issues, grouped, with what recent work already covers.
