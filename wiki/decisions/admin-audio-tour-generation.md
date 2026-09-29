---
title: Admin-only audio tour generation from the dashboard
kind: decision
status: proposed
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/curator-dashboard-v2.md
sources:
- sources/planning/pr-151/decisions/2026-02-05-audio-tour-generation-integration.md
- https://github.com/misabegovic/usput.ba/pull/151
- app/services/ai/audio_tour_generator.rb
- lib/platform/dsl/executors/content.rb
- lib/tasks/audio_tours.rake
enola_intent:
  page:
    type: decision
    status: proposed
    scope:
    - usput.ba
    origin:
    - other
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/decisions/curator-dashboard-v2.md
---
# Admin-only audio tour generation from the dashboard

## Context

ADR-0005 of PR #151 (2026-02-05) observes that `Ai::AudioTourGenerator` is complete (script writing, text to speech through ElevenLabs with 26 voices, OpenAI or Google Cloud, several languages, batches) but has no button: tours are generated only from the Rails console or `bin/platform`. The location page in the curator dashboard shows no audio status or player. Cost matters: ElevenLabs is about $0.30 per minute, so $1 to $1.50 per 3 to 5 minute tour; OpenAI TTS costs about $0.03 per tour but sounds worse in Bosnian. The original is `sources/planning/pr-151/decisions/2026-02-05-audio-tour-generation-integration.md`.

## Decision

Proposed: an admin-only "generate audio tour" action on the location page that queues a background job wrapping the generator, one language per request. The page shows which languages have a tour, a player and a language picker. Safeguards: an admin check in the controller, a refusal if the same request was made in the last 10 minutes, a confirmation dialog that states the cost, errors logged to `CuratorActivity` and re-raised for retry, and every request and result recorded as a curator activity (three new activity actions).

## Alternatives

- Manual audio tour editing only. Rejected: wastes a generator that already works.
- A batch page with a checkbox list of locations. Rejected for now: one mistaken click could cost a lot.
- Let curators trigger generation. Rejected until budget monitoring exists: cost accountability belongs to admins.

## Consequences

Expected: self-service generation without a console, an audit trail, no blocked UI, cost visibility and duplicate prevention. Limits: no live progress (a page refresh is needed), no voice picker, one language per request. Manual tour editing stays.

## Status notes

Not on main: no job or controller action calls `AudioTourGenerator`. It is reached only from the DSL content executor (`lib/platform/dsl/executors/content.rb`) and a rake task (`lib/tasks/audio_tours.rake`), and `app/jobs/` holds only `application_job.rb` and `openai_request_job.rb`. #151 contains the pieces (`AudioTourGenerateJob`, a `generate_audio_tour` route, the location panel and the activity actions). The salvage report of 2026-09-29 ranks this the first slice to port, about 150 lines, admin-only, and adds one rule the ADR lacks: refuse archived locations (see [archive-places-not-delete](archive-places-not-delete.md)).
