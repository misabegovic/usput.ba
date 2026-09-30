---
title: Langfuse for LLMOps
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- initiatives/rubyllm-2-upgrade.md
- architecture/ai-content-pipeline.md
- decisions/jev-flags-reviews.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- app/helpers/prompt_helper.rb
- app/prompts/README.md
- app/services/ai/openai_queue.rb
- app/models/ai_generation.rb
- app/services/mine_checker/config.rb
- config/initializers/ruby_llm.rb
- db/schema.rb
- .example-env
- https://langfuse.com/resources/engineering/opentelemetry-languages
- https://langfuse.com/docs/prompt-management/features/a-b-testing
- https://github.com/thoughtbot/opentelemetry-instrumentation-ruby_llm
- https://github.com/simplepractice/langfuse-rb
- https://github.com/ai-firstly/langfuse-ruby
---
# Langfuse for LLMOps

## Objective

Every model call the rebuilt usput makes is traced in hosted Langfuse from day one: which prompt and version, which model, the tokens, the cost, the latency and the outcome. Prompt versions can be compared in production (A/B), and generated content can be scored. The operator chose hosted Langfuse for prompt measurement, A/B testing and LLMOps, and put "the AI content pipeline with Langfuse from day one" in version 1 (`sources/conversations/2026-09-30--usput--platform-direction.md`).

## Background

**What is measured today: almost nothing.** `Ai::OpenaiQueue` logs failures to the Rails log and Rollbar and returns the parsed reply; it records no tokens, cost, latency or prompt version (`app/services/ai/openai_queue.rb`). `AiGeneration` rows count places and experiences created per run, with a status, timestamps, an error message and free `metadata` (`db/schema.rb`, `app/models/ai_generation.rb`). There is no way to say which prompt produced a given description or what a run cost.

**Prompts today.** Seven prompt templates live under `app/prompts/` (descriptions, historical context and metadata for places, experience type classification, place extraction from experience text, audio tour scripts) and are read from disk by `PromptHelper#load_prompt`, which renders `.erb` files with the variables it is given (`app/helpers/prompt_helper.rb`, `app/prompts/README.md`). They are versioned only by git. The rebuild starts over, so none of them has to be carried into Langfuse as they are.

**Ruby options, as of 2026-09-30.**

- Langfuse states there is no native Ruby SDK and that Ruby apps send traces over OpenTelemetry to its OTLP endpoint, with spans carrying `gen_ai.*` attributes set by hand, since "there is no automatic LLM instrumentation ecosystem for Ruby yet" (https://langfuse.com/resources/engineering/opentelemetry-languages). The EU endpoint is on `cloud.langfuse.com`, the US one on `us.cloud.langfuse.com`, authenticated with the project's key pair.
- thoughtbot's `opentelemetry-instrumentation-ruby_llm` (0.7.1, 2026-07-31) instruments RubyLLM chats, tool calls and embeddings under the GenAI semantic conventions, leaves message content out unless `capture_content` is turned on, and sets Langfuse attributes such as the prompt name for linking. It is tested against RubyLLM 1.8 to 1.x; 2.0 is not mentioned (https://github.com/thoughtbot/opentelemetry-instrumentation-ruby_llm).
- Two community gems wrap Langfuse's API, including prompt fetching: `langfuse-rb` (0.12.3, 2026-09-16, maintained by SimplePractice) and `langfuse-ruby` (0.2.1, 2026-09-17). Neither is Langfuse's own (https://github.com/simplepractice/langfuse-rb, https://github.com/ai-firstly/langfuse-ruby).
- A thin HTTP client of our own for the prompt endpoints, next to OpenTelemetry for traces, is the smallest dependency.

**A/B testing in Langfuse** works by labelling two prompt versions, having the app choose one at random per call, linking the chosen version to the generation, and comparing latency, tokens, cost and scores in the Langfuse UI (https://langfuse.com/docs/prompt-management/features/a-b-testing).

**Where it attaches.** Every call in the rebuild goes through the one seam in [RubyLLM 2 in the rebuild](rubyllm-2-upgrade.md), so tracing wraps that seam once rather than each service. The same seam serves embeddings for [pgvector semantic search](pgvector-semantic-search.md). Jev review screening goes to TypeSafe's API, not through RubyLLM ([Jev flags reviews](../decisions/jev-flags-reviews.md)); whether it is traced too is a choice below.

**Prompt source of truth: two shapes.**

- **Langfuse is the source; `app/prompts/` is the fallback.** Prompts are edited, versioned and labelled in Langfuse; the app fetches the production label (cached) and falls back to the file shipped with the release when Langfuse is absent or down. A/B is a label change with no deploy. The cost: the text that shapes public content changes outside git review, and the files drift unless a job writes them back.
- **`app/prompts/` is the source, synced to Langfuse.** A deploy step (or a rake task) pushes each file as a new Langfuse version when its content changes; production reads files, and Langfuse links traces to the matching version. Review stays in pull requests and the brain's rule that prompts live in `app/prompts/` holds unchanged. The cost: an A/B variant is a second file and a deploy.

Variables differ in either shape: Langfuse templates use double-brace variables, while today's files are ERB (unverified, 2026-09-30). The rebuild writes prompts in one variable syntax both sides can render.

**What leaves usput.** Prompts, their variables and the model's replies. In version 1 that is mostly place data, which is public. User text enters only where a feature puts it there: a moment's note or a review, if either is embedded or sent to a model. With content capture on, that text is stored in Langfuse too.

## Affected personas

- Admins: they see which prompt wrote a description and can compare versions.
- The operator: cost per feature and per run, and the choice of what to promote.
- Travellers: indirectly, through better measured content.
- Moment and review authors: their text may be sent to Langfuse, which the privacy notice must say if so.

## Scope

Slices, each a small pull request with its tests, starting with the seam's first slice:

1. **Credentials and skip-when-absent.** Langfuse public and secret keys and the host (EU) in Rails credentials, the way `MineChecker::Config` reads its secrets (`app/services/mine_checker/config.rb`), with environment variables as the override. No key means no tracing and no fetching, never an error. Test: with no key the seam runs and nothing is exported.
2. **Traces for every call.** The seam opens one OpenTelemetry span per call with the GenAI attributes (model, prompt name and version, input and output tokens, cost, latency, outcome), exported to the EU OTLP endpoint in a background exporter. Content capture off by default. Tests with an in-memory exporter.
3. **Run grouping.** A generation job's calls share one trace, named for the job and the record, so one place's enrichment is one trace with its steps. Tests on span parentage.
4. **Prompt versions.** The chosen source-of-truth shape: either fetch by label with cache and file fallback, or sync files to Langfuse on deploy. Every trace carries the version it used. Tests with a stubbed prompt API.
5. **A/B by label.** Two labelled versions of one prompt, a deterministic split per record (so a re-run uses the same arm), the arm on the trace. Tests on the split.
6. **Scores.** An admin's edit of AI-written text in Avo, or a rejection, is sent as a score on the generation's trace; later, an LLM-as-judge evaluation on a small dataset of places. Tests on the score call.
7. **Cost view.** A monthly budget alert in Langfuse and a line in the brain's state when a run crosses it. No code beyond configuration.

## No-gos

- No self-hosted Langfuse in version 1; the operator chose hosted.
- No user text in traces unless content capture is decided on.
- No request path waits on Langfuse: export is asynchronous and fetching is cached with a file fallback.
- No A/B test on text a traveller cannot tell apart from an error (for example, the safety wording of place descriptions).

## Rabbit holes

- **Two OpenTelemetry sources.** If the thoughtbot gem and our own spans both run, calls are traced twice. Pick one per call.
- **RubyLLM 2.0 support** in the instrumentation gem is not stated; the seam's own spans do not depend on it.
- **Cost figures** come from RubyLLM's model registry or Langfuse's price table; they can disagree, and neither is billing.
- **Retries** inside RubyLLM show as one span unless the seam records attempts.

## Appetite

Medium: slices 1 to 3 ship with the first generation job of the rebuild; 4 and 5 once there are two prompt versions worth comparing; 6 and 7 after launch. Calendar time is (unknown, needs source).

## Decision needed

- **Region and plan.** EU (`cloud.langfuse.com`) is the natural choice for a Bosnian product with European travellers; which plan, and its trace and retention limits, is (unknown, needs source).
- **Prompt source of truth**: Langfuse with file fallback, or files synced to Langfuse.
- **Content capture**: whether prompts and replies are stored in Langfuse, and whether that includes moment notes or reviews if they ever reach a model.
- **Whether Jev calls are traced** in Langfuse as well.
- **Integration route**: our own spans plus a thin prompt client, a community gem, or the thoughtbot instrumentation once it supports 2.0.
