---
title: Tooling, models, Langfuse and Jev moderation, from the operator
date: 2026-10-14
via: conversation with the agent
---
# Tooling, models, Langfuse and Jev, 2026-10-14

The operator's words, verbatim, followed by the choices they made when asked.

## Messages

> fix the seeds too. also explore how we can use Jev to review comments and
> approve them for public visibility (author always sees their comment) or
> reject.

> also make sure to use latest RubyLLM and latest Herb. latest Rubocop. I also
> want to upgrade to latest OpenAI models, such as Luna and benefit from costs
> etc. We should also integrate and use Langfuse for this.

> there is also a draft PR open from before. take care of it also

## What the agent found before asking

- Latest releases on 2026-10-14: `ruby_llm` 2.1.1, `rubocop` 1.92.0, `herb`
  and `@herb-tools/linter` 0.11.0 (RubyGems and npm). `herb lint` delegates to
  the Node package.
- OpenAI's pricing page lists `gpt-6-luna` at $0.10 input, $0.01 cached input
  and $0.50 output per million tokens, half that on Batch and Flex
  (https://developers.openai.com/api/docs/pricing, read 2026-10-14).
- RubyLLM 2.1.1 ships a TypeSafe provider, `RubyLLM::Judge`, and
  `RubyLLM::OpenTelemetry`, and its model registry carries `gpt-6-luna`.

## Choices made when asked

- Jev policy: "Three bands". Jev approves clearly fine reviews and rejects
  clear abuse or spam; uncertain ones wait for a curator. Honest negative
  reviews are approved. It starts in observe mode until thresholds are
  measured. The author always sees their own review, and an admin can always
  overturn.
- Herb: "Replace erb_lint". Herb lint in package.json, CI and bin/ci;
  erb_lint and better_html removed.
- Langfuse: "Self-hosted on Railway", as answered on 2026-09-30.
- Landing: "Separate PRs". Seeds, then RuboCop and Herb, then RubyLLM 2.1
  with `gpt-6-luna`, then Langfuse tracing, then Jev review moderation; each
  PR updates the brain and is opened for the operator's review.
