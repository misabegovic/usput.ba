---
title: Platform direction for usput, from the operator
date: 2026-09-30
via: conversation with the agent
---
# Platform direction, 2026-09-30

The operator's words, verbatim, followed by the choices they made when asked.

## First message

> Ok, how's usput looking right now? I want to explore upgrading RubyLLM,
> introducing Roundhouse and Spinel, maybe even removing the contributor
> dashboard completely? Or just finding ways to make it work but keep it
> simple. Also want to use enole there, make sure we use pgvector properly...
> I also want to use Jev to scan for comments and determine if a comment is
> positive or not. Hide comments from production if it needs to be reviewed
> by a human admin first so not all comments get live automatically and
> available to all users (the author should see their comments though).

Choices made when asked:

- Moderation: "Jev only flags". Reviews go live as today; Jev hides the ones
  it reads as negative or unsafe until an admin looks. The author still sees
  their own review.
- Jev runtime: "Hosted TypeSafe API".
- Curator dashboard: "Remove completely".
- Roundhouse and Spinel: the operator sends the links.

## Second message

> https://github.com/rubys/roundhouse , https://github.com/matz/spinel
>
> I'm thinking we should use Avo for the admin dashboard and define roles of
> users and we can have a curator role there also? So you can completely
> remove what's there now and we can just use Avo? Also maybe we need to work
> on the user sessions and how they work right now
>
> Also, I'm thinking to have a hosted Langfuse solution for prompt
> measurements, a/b testing and llmops.
>
> With roundhouse and spinel I want to compile usput and serve the optimized
> compilation.
>
> I have a TypeSafe key, I can provide later

Choices made when asked:

- Avo and compiling: "Avo now, compile later". Adopt Avo; run
  `roundhouse check` as analysis for now.
- Avo licence: "Community (free)". Role rules are enforced by the app.
- First step: "Shape it all in the brain", as one pull request to approve
  before any code.
- Installs: allowed in the agent's container for exploration.

## Third message

> You don't have to think about backwards compatibility. We'll do Usput and
> all of its content from scratch.

Choices made when asked:

- Where: "Same repo, rewrite in place". The Rails skeleton stays; domain,
  admin and UI are rewritten piece by piece, deleting as we go.
- Compile: "No, Avo and Postgres first". `roundhouse check` as analysis only.
- Version 1 scope: places and explore (with pgvector search), plans and
  walking (check-ins, moments), reviews with Jev, and the AI content pipeline
  with Langfuse from day one.
- Content: "New content, old site stays up". The current production app runs
  until the rebuild launches; the rebuilt app starts with an empty database.

## Answers to the open questions, asked one by one

1. Deploys: "No auto-deploy from main". The rewrite lands on main piece by
   piece; production is deployed by hand.
2. Reviews require signing in.
3. Jev flags "Negative or unsafe" reviews.
4. Moment notes: "Yes, same flagging". Follow-up, because Jev reads text and
   not photos: "Keep approval, Jev reads the note". Public moments still wait
   for an admin; Jev's reading of the note is shown in the queue.
5. Email is required on accounts.
6. Content generation: OpenAI. Embeddings: OpenAI text-embedding-3-small.
7. Postgres: Railway Postgres with pgvector.
8. Prompts: files in app/prompts are the master copy, synced to Langfuse.
   Langfuse is self-hosted, on Railway beside usput.
9. Curators create and edit content and clear or remove flagged reviews and
   moments; only admins delete, manage users and roles, and change settings.
   Audio tours are in version 1. `roundhouse check` reports on every pull
   request now and becomes a failing gate later.
