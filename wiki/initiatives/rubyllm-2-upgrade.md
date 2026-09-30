---
title: RubyLLM 2 in the rebuild
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- architecture/ai-content-pipeline.md
- decisions/avo-now-compile-later.md
sources:
- sources/conversations/2026-09-30--usput--platform-direction.md
- Gemfile
- Gemfile.lock
- config/initializers/ruby_llm.rb
- app/services/ai/openai_queue.rb
- app/jobs/openai_request_job.rb
- app/services/ai/bih_context.rb
- app/services/ai/audio_tour_generator.rb
- app/helpers/prompt_helper.rb
- lib/platform/dsl/llm_helper.rb
- lib/platform/dsl/executors/content.rb
- test/services/ai/openai_queue_test.rb
- https://rubyllm.com/upgrading/
- https://rubyllm.com/upgrading-to-1-7/
- https://rubygems.org/gems/ruby_llm/versions/2.0.0
- https://github.com/crmne/ruby_llm
enola_intent:
  page:
    type: initiative
    status: proposed
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/architecture/ai-content-pipeline.md
    - rel: depends-on
      to: wiki/decisions/avo-now-compile-later.md
---
# RubyLLM 2 in the rebuild

## Objective

The rebuilt usput starts on RubyLLM 2.0 and uses it well: one seam for every model call, structured output read as parsed data, token counts and cost on every response, and every prompt a file. There is no upgrade path to write. The operator decided on 2026-09-30 that usput and its content are rebuilt from scratch, in place in the same repository, with an empty database at launch, and that the AI content pipeline is part of version 1 (`sources/conversations/2026-09-30--usput--platform-direction.md`). This page takes the lessons from today's 1.9 code into that rebuild.

## Background

**Versions.** The Gemfile asks for `ruby_llm` with no version constraint and the lock resolves 1.9.1 (`Gemfile`, `Gemfile.lock`). RubyGems lists 2.0.0 as released on 2026-09-18, after four release candidates from 2026-09-08, and 1.16.0 as the last 1.x (2026-06-09). Both require Ruby 3.1.3 or newer; usput runs 3.3.5.

**The deprecation warning is not about usput's code.** The test run prints that the legacy `acts_as` API is deprecated and will be removed in 2.0.0. usput has no `acts_as_chat`, `acts_as_message` or any other `acts_as` call in `app/`, `lib/` or `test/`. The warning comes from the gem's railtie (`lib/ruby_llm/railtie.rb` in the installed 1.9.1 gem): when `config.use_new_acts_as` is false, which is the default, it loads the legacy module into every Active Record class and logs the warning. `config/initializers/ruby_llm.rb` never sets the flag, so the warning fires on every boot although nothing uses what it warns about. RubyLLM 2.0 removes both the legacy API and the flag (https://rubyllm.com/upgrading/).

**How usput calls models today.** Every call is a plain chat with one prompt; there are no tools, no streaming, no persisted conversations and no embeddings.

- `Ai::OpenaiQueue` builds one `RubyLLM.chat` on the default model and calls `ask`, adding `with_schema` when a JSON schema hash is given. It then checks the reply for CDN error pages, retries gateway, timeout and SSL errors on its own backoff on top of RubyLLM's Faraday retries, and maps RubyLLM errors to its own classes (`app/services/ai/openai_queue.rb`). The name says OpenAI, but it calls whatever `LLM_DEFAULT_MODEL` names.
- Structured output is read defensively: when `response.content` is a Hash it is used as is, otherwise a regex pulls JSON out of a fenced block or the first brace pair and "smart quotes" and trailing commas are scrubbed before parsing. A parse failure returns an empty hash.
- `OpenaiRequestJob` runs the same request on the `ai_generation` queue and calls back a class named in a string through `constantize` (`app/jobs/openai_request_job.rb`).
- The Platform DSL has a second, separate path: `Platform::DSL::LLMHelper#generate_with_llm` calls `RubyLLM.chat(model:).ask` directly, without the queue's retries or error mapping (`lib/platform/dsl/llm_helper.rb`), and the content executor builds its prompts inline with heredocs (`lib/platform/dsl/executors/content.rb`).
- `Ai::BihContext` holds a long English cultural-context prompt as a Ruby constant (`app/services/ai/bih_context.rb`), although the rule is that prompts live in `app/prompts/` and are loaded with `PromptHelper#load_prompt` (`app/helpers/prompt_helper.rb`).
- Text to speech does not go through RubyLLM: `Ai::AudioTourGenerator` calls ElevenLabs and OpenAI TTS over Faraday (`app/services/ai/audio_tour_generator.rb`).
- Configuration reads API keys for OpenAI, Anthropic and Gemini from the environment, defaults the model to `gpt-4o-mini`, and allows a 300 second timeout with five retries (`config/initializers/ruby_llm.rb`).
- Nothing records tokens or cost; errors go to the Rails log and Rollbar.

**What 2.0 changes that matters for this code** (https://rubyllm.com/upgrading/):

- Structured output is read from `response.parsed`; `content` now returns the JSON string. Today's `content.is_a?(Hash)` branch would stop matching and fall through to the regex path.
- Token counts move to `response.tokens.input` and `.output`, and a chat reports `chat.cost`.
- OpenAI calls default to the Responses API; `config.openai_protocol = :chat_completions` keeps the old wire format.
- Schema classes subclass `Schematist::Schema` instead of `RubyLLM::Schema`.
- Errors are built as `Error.new("msg", response: response)`, so the tests that raise `RubyLLM::Error.new(mock_response)` (`test/services/ai/openai_queue_test.rb`) no longer describe the library.
- `with_params` becomes `provider_options`, `with_tool` becomes `with_tools`, and temperature is sent as given.

## Affected personas

- Admins: they start generation from Avo in the rebuild ([admin through Avo](../decisions/admin-through-avo.md)) and see its results and failures.
- Travellers: they read what the pipeline writes about places and plans.
- Developers and agents: one seam to call, test and trace instead of two paths.

## Scope

The rebuild writes the AI layer new, on 2.0, on its long-lived branch. Lessons carried over: keep a single wrapper (today's instinct was right), but make it the only door; trust the library's retries instead of stacking a second set; read parsed output instead of scraping JSON; keep every prompt a file. Slices, each a small pull request with its tests:

1. **Gem and initializer.** `ruby_llm` pinned to `~> 2.0`; the initializer sets keys, the default model, the timeout and the OpenAI protocol choice, and nothing about `acts_as`. Test: the app boots with no deprecation warning, and a missing key leaves the app booting.
2. **One seam.** A single service (its name is the code's call) that every model call goes through: a prompt name, variables, an optional schema, and a result carrying parsed data, token counts, cost, model and latency. It maps RubyLLM errors to a small set of its own. Tests stub `RubyLLM.chat` and cover success, a schema reply, a rate limit and a provider error built the 2.0 way.
3. **Schemas as classes.** Each structured reply (descriptions per locale, metadata, experience types, places found in a text) gets a schema class read through `parsed`. No regex JSON extraction. Tests per schema with recorded replies.
4. **Prompts only from files.** Every prompt, the cultural context included, is a file under `app/prompts/` loaded through `PromptHelper`; no heredoc prompts in services, jobs or `lib/`. A test fails when a service defines one. How prompts also live in Langfuse is decided in [Langfuse for LLMOps](langfuse-llmops.md).
5. **Generation jobs.** One job per generation kind on Solid Queue, taking record ids rather than a class name in a string, retrying only what the seam marks as transient. Tests with the queue adapter.
6. **Embeddings through the seam.** `RubyLLM.embed` behind the same door, returning the vector, its model and dimension, for [pgvector semantic search](pgvector-semantic-search.md). Tests stub the call.
7. **Tracing hook.** The seam emits one event per call (prompt name and version, model, tokens, cost, latency, outcome) that Langfuse consumes; with no Langfuse key it is a no-op. Built together with the Langfuse initiative.

## No-gos

- No second path to a model: the Platform DSL, jobs and Avo actions all call the seam.
- No `acts_as_chat` persistence in version 1. Traces live in Langfuse; nothing in v1 is a conversation.
- No port of the 1.9 services line by line; they are the reference for what the pipeline does, not the code to keep.
- No prompts in Ruby strings.

## Rabbit holes

- **Responses API versus Chat Completions.** The default changes for OpenAI in 2.0; structured output and token fields may differ between the two (unverified, 2026-09-30). Pick one in slice 1 and test against it.
- **Tracing support for 2.0.** The OpenTelemetry instrumentation gem for RubyLLM is tested against 1.x (see [Langfuse for LLMOps](langfuse-llmops.md)); the seam's own event is the fallback.
- **Long timeouts.** 300 seconds per request and five retries hold a job worker for a long time. Batch smaller instead of waiting longer.
- **Audio.** ElevenLabs is not a RubyLLM provider. Audio tours are not named in version 1 (`sources/conversations/2026-09-30--usput--platform-direction.md`), so they stay out of this page.

## Appetite

Small to medium: slices 1, 2 and 4 are small, slices 3, 5 and 6 are medium, slice 7 is shared with Langfuse. Calendar time is (unknown, needs source).

## Decision needed

- **Default provider and model** for content generation. Today the default is `gpt-4o-mini` with keys for three providers configured; the rebuild can name one provider and one model per task.
- **OpenAI protocol**: the 2.0 default (Responses API) or `chat_completions`.
- **Whether audio tours come back** in the rebuild, and if so after version 1.
