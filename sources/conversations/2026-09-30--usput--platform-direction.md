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
