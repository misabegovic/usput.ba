---
title: AI content pipeline
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- app/services/ai/openai_queue.rb
- app/services/ai/rate_limiter.rb
- app/services/ai/bih_context.rb
- app/services/ai/location_enricher.rb
- app/services/ai/location_enricher/base.rb
- app/services/ai/location_enricher/applicator.rb
- app/services/ai/location_enricher/description_generator.rb
- app/services/ai/location_enricher/historical_generator.rb
- app/services/ai/location_enricher/metadata_generator.rb
- app/services/ai/experience_type_classifier.rb
- app/services/ai/experience_location_syncer.rb
- app/services/ai/audio_tour_generator.rb
- app/services/ai/concerns/error_reporting.rb
- app/helpers/prompt_helper.rb
- app/prompts/README.md
- app/jobs/openai_request_job.rb
- app/models/ai_generation.rb
- app/controllers/curator/audio_tours_controller.rb
- app/views/new_design/explore/_location_card.html.erb
- config/initializers/ruby_llm.rb
- config/queue.yml
- lib/tasks/audio_tours.rake
- lib/tasks/experience_types_cleanup.rake
- lib/platform/dsl/executors/content.rb
- lib/platform/dsl/llm_helper.rb
- sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md
- sources/planning/LEARNINGS.md
- sources/planning/pr-151/README.md
- sources/planning/pr-151/decisions/2026-02-05-ai-vs-human-suggestion-origin.md
depends_on:
- architecture/overview.md
- architecture/platform-dsl.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - other
    - repo
    relations:
    - rel: depends-on
      to: wiki/architecture/overview.md
    - rel: depends-on
      to: wiki/architecture/platform-dsl.md
---
# AI content pipeline

Usput.ba uses LLMs to write location descriptions in many languages,
historical context, tags and practical tips, to classify places by
experience type, to find places named in an experience's text, and to write
audio tour scripts that are then voiced by text to speech. The services live
in `app/services/ai/`, every call goes through one wrapper
(`Ai::OpenaiQueue`), and every prompt is a text file in `app/prompts/`.
Output is written straight to the content tables and marked
`ai_generated`; there is no review queue between the model and the public
site. This page describes that pipeline and where it is headed.

## The services

| Service | What it produces | Prompt files |
|---------|------------------|--------------|
| `Ai::LocationEnricher` | Descriptions per locale, historical context, tags, practical info and suitable experience types for one location, then saves it | `location_enricher/metadata.md.erb`, `descriptions.md.erb`, `historical_context.md.erb` |
| `Ai::LocationEnricher::DescriptionGenerator` | Descriptions for several locales, five locales per request (`LOCALES_PER_BATCH = 5`) | `location_enricher/descriptions.md.erb` |
| `Ai::LocationEnricher::HistoricalGenerator` | Historical context per locale | `location_enricher/historical_context.md.erb` |
| `Ai::LocationEnricher::MetadataGenerator` | Tags, tips, experience type hints | `location_enricher/metadata.md.erb` |
| `Ai::LocationEnricher::Applicator` | Writes translations, experience types (calling `Ai::ExperienceTypeClassifier`), tags and practical info onto the location | none |
| `Ai::ExperienceTypeClassifier` | Experience types for a location, with optional hints and a dry run | `experience_type_classifier/system.md.erb`, `classify.md.erb` |
| `Ai::ExperienceLocationSyncer` | Finds places mentioned in an experience description (minimum confidence 0.6), matches them in the database or creates them through Geoapify and the enricher, and attaches them | `experience_location_syncer/extract_locations.md.erb` |
| `Ai::AudioTourGenerator` | A narration script per locale, then audio through ElevenLabs (`eleven_multilingual_v2` by default) or OpenAI TTS, attached to an `AudioTour` through Active Storage | `audio_tour_generator/script.md.erb` |

`Ai::BihContext::BIH_CULTURAL_CONTEXT` is shared context injected into the
enricher and audio prompts. It sets content guidelines (respect for all
religious and ethnic communities, local terms explained for tourists) and
states, in capitals, that Bosnian (`bs`) text must use ijekavica with a
table of right and wrong forms such as "rijeka" versus "reka"
(`app/services/ai/bih_context.rb`).

`Ai::Concerns::ErrorReporting` gives every service `log_info`, `log_warn`
and `log_error` helpers that also report to Rollbar.

## Prompts live in `app/prompts/`

The rule in `.claude/CLAUDE.md` and `AGENTS.md` is that no AI prompt is
written inline in a service. Prompts are `.md` files, or `.md.erb` when they
take variables, under `app/prompts/<service>/`, and services load them with
`PromptHelper#load_prompt(path, **vars)` (`app/helpers/prompt_helper.rb`).
The helper raises `ArgumentError` when the file is missing, renders `.erb`
files with `ERB#result_with_hash`, and returns other files as they are.
`available_prompts` lists every prompt file. `app/prompts/README.md` maps
the tree.

All four services in `app/services/ai/` follow the rule. The Platform DSL
does not: `Executors::Content` builds description, translation and
experience prompts inline (`build_description_prompt`,
`build_translation_prompt`, `build_experience_prompt` in
`lib/platform/dsl/executors/content.rb`) and calls
`RubyLLM.chat` directly through `LLMHelper`, bypassing `Ai::OpenaiQueue`.
`sources/planning/LEARNINGS.md` also records an inline description prompt
from maintenance scripts that were deleted on 2026-02-02; it is guidance
for wording, not live code.

## One wrapper for every model call

`Ai::OpenaiQueue.request(prompt:, schema:, context:)` is the synchronous
path every service uses. Despite its name it calls whatever model RubyLLM
is configured for: `LLM_DEFAULT_MODEL`, default `gpt-4o-mini`, with OpenAI,
Anthropic and Gemini keys all read from the environment
(`config/initializers/ruby_llm.rb`). With a JSON schema it uses
`with_schema` and parses the result into a symbol-keyed hash, falling back
to extracting JSON from fenced or bare text and repairing smart quotes and
trailing commas.

Retries come in two layers. RubyLLM's Faraday middleware retries 429, 5xx
and network failures up to `LLM_MAX_RETRIES` (default 5) with exponential
backoff from a 5 s base, and requests time out after 300 s. On top of that,
`OpenaiQueue` retries three more cases up to three times each: gateway error
pages from a CDN that arrive as HTML content (5 s base), read and open
timeouts (10 s base), and SSL errors (5 s base). A rate limit that survives
RubyLLM's retries becomes `Ai::OpenaiQueue::RateLimitError`; other failures
become `RequestError`, `TimeoutError` or `SslError`, and all are logged and
sent to Rollbar.

`Ai::OpenaiQueue.enqueue` puts the same request on `OpenaiRequestJob`, which
runs on the `ai_generation` queue, retries `RequestError` five times with
polynomial backoff and `RateLimitError` ten times at 30 s, and can call back
a class's `handle_openai_response`. `config/queue.yml` runs that queue with
one thread in one process to stay under the provider's token rate. No code
in `app/` or `lib/` calls `enqueue` today, so every AI call in practice runs
synchronously in whatever process started it.

`Ai::RateLimiter` is not about LLMs: it paces Geoapify calls to five per
second, and the DSL's external executor uses its `with_delay`.

## How the pipeline is started

There is no web action that starts AI generation. The entry points are:

- `rake audio_tours:generate`, `generate_city`, `generate_missing`,
  `preview` and `status` (`lib/tasks/audio_tours.rake`);
- `rake experience_types:populate_missing` and a classifier smoke test in
  `lib/tasks/experience_types_cleanup.rake`;
- the Platform DSL: `generate description`, `generate translations`,
  `generate experience from locations [...]` (inline prompts) and
  `synthesize audio for ...` (which calls `Ai::AudioTourGenerator`); see
  [Platform DSL](platform-dsl.md).

`Ai::LocationEnricher` has no caller in `app/`, `lib/` or `lib/tasks/`
other than `Ai::ExperienceLocationSyncer`, and the syncer has no caller at
all outside its tests. The enricher carries a `@deprecated` note pointing
to `bin/platform chat`, a command that does not exist. The `AiGeneration`
model (per-city generation runs with status, counts and errors) exists with
its table but nothing writes to it.

## How AI output reaches curators and travellers

Every service writes directly: the enricher saves the location and its
translations, the classifier adds experience types, the syncer attaches or
creates locations and marks them `ai_generated: true`, and the audio
generator saves the `AudioTour` and its file. The DSL's `create` marks new
records `ai_generated: true` as well. `Location`, `Experience`, `Plan` and
`Browse` all carry an `ai_generated` boolean with `ai_generated` and
`human_made` scopes, and explore cards show a small "AI" badge when it is
set (`app/views/new_design/explore/_location_card.html.erb`). Curators see
the result as ordinary content in the admin and edit it there directly.

Curators themselves never trigger generation: in the admin they write or
edit a tour's script and upload its audio file by hand
(`app/avo/resources/audio_tour.rb`). Until 2026-09-30 their audio tour form
filed a `ContentChange` proposal, which could not carry the audio file.

The unmerged planning of pull request #151 names this as the core problem:
AI output is live the moment it is written, with no review or approval, so a
hallucinated history or a wrong classification reaches users directly. It
proposes recording whether a suggestion came from a human or from AI and
routing AI output through review
(`sources/planning/pr-151/decisions/2026-02-05-ai-vs-human-suggestion-origin.md`,
status proposed). None of it is in the code.

## Guidance that is written down but not enforced

`sources/planning/LEARNINGS.md` collects patterns from maintenance scripts:
upsert translations with `find_or_initialize_by`, the ten experience types
(`adventure`, `culture`, `food`, `nature`, `relaxation`, `urban`, `history`,
`religious`, `family`, `romantic`), what a good description looks like (150
to 300 characters, specific details, no clichés), tag sets per category,
and a table of sensitive places. That table says war memorials need a
respectful, factual tone, religious sites a neutral one, and that genocide
memorials must be refused for AI generation and left to human review. No
code implements that refusal (unverified, 2026-09-29: no match for it in
`app/services/ai/` or `app/prompts/`).

## Target: the proposed DSL migration

The 2026-02-04 ADR proposes making the Platform DSL the only interface for
AI work (`sources/planning/decisions/2026-02-04-ai-services-dsl-migration.md`,
status proposed, no approvals recorded). It notes that the four services
already use `PromptHelper` and `OpenaiQueue`, but that the enricher's
deprecation has no migration path and the services are not integrated with
the DSL. Its plan has six stages: DSL executors that wrap the services
(`locations { id: 123 } | enrich`, `| classify_experience_types`,
`| generate_audio`, `experiences { id: 456 } | sync_locations`), moving
rake tasks, jobs and controllers onto those calls, splitting and batching
the enricher inside the executor with response caching, deprecation
warnings, a guide, and removal of the legacy services in Q4 2026. None of
the wrapper executors exist yet.
