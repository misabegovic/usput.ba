---
title: Purpose of Usput.ba
kind: reference
status: living
updated: 2026-09-29
repos:
  - usput.ba
confidence: medium
sources:
  - README.md
  - CLAUDE.md
  - .claude/CLAUDE.md
  - sources/planning/VISION.md
  - .claude/agents/curator.md
  - .claude/agents/content-director.md
  - .claude/agents/historian.md
  - .claude/agents/audio-producer.md
  - config/application.rb
  - app/models/content_change.rb
  - app/models/moment.rb
  - docs/mine_checker/README.md
---
# Purpose of Usput.ba

Usput.ba is a tourism platform for Bosnia and Herzegovina (BiH). It helps a traveller discover places, group them into experiences and multi-day plans, walk those plans on the ground, and keep what they saw. Content is drafted with AI help and reviewed by human curators before it is published. This page states what the product is for and the promises it makes. For who uses it, see [personas](personas.md); for the vocabulary, see [domain](domain.md); for what ships today, see [features](features.md).

## What it is

The README describes the product as "Discover Bosnia and Herzegovina. A tourism platform featuring curated locations, experiences, audio tours, and AI-powered content generation" (`README.md`). The project instructions call it a tourist platform for BiH with AI-powered content generation (`CLAUDE.md`).

The core objects are places (`Location`), curated sets of places (`Experience`), multi-day itineraries (`Plan`), narrated audio for places (`AudioTour`), and a proposal system through which curators change content (`ContentChange`) (`README.md`, Core Models table). Since 2026-09-15 a traveller can also check in at a place and capture a photo moment there (see [features](features.md)).

## Who it serves

- **Travellers**, local and foreign, who want to find what to see and do across the whole country, and then walk it. Browsing, the plan wizard and the explore deck need no account (see [personas](personas.md)).
- **Curators**, trusted volunteers who propose and moderate content through the curator dashboard at `/curator` (`README.md`, Curator Dashboard section).
- **Admins**, who approve or reject what curators propose (`README.md`: "Curators submit changes as proposals. Admins review and approve/reject.").

## The promises

### All of Bosnia and Herzegovina, in balance

The curator persona treats every region as equally important: "SVE regije su jednako važne" (all regions are equally important), and it promotes every region equally, "from the Una to the Drina" (`.claude/agents/curator.md`, "Tvoj karakter" and "Tvoja pravila"). The content director's team description repeats that the curator makes sure all regions are represented equally (`.claude/agents/content-director.md`, "Tvoj tim").

The product vision uses regional coverage as its worked example: the Platform brain is asked to "improve coverage for Bihać", finds the gaps (rafting, restaurants, lodging) and fills them (`sources/planning/VISION.md`, "Šta Platform RADI").

### Only real places, only in BiH

The content director's second golden rule is never to create content that does not exist in reality in BiH. A location that does not exist, sits in the wrong city, or duplicates another is unacceptable, and every creation passes a DSL validation that checks Geoapify, the BiH boundary and duplicates (`.claude/agents/content-director.md`, "ZLATNO PRAVILO #2" and "UNIVERZALNA VALIDACIJA SADRŽAJA"). Its example of a trap is "Tuzla Thermal Waters", a name that matches a place in Turkey.

### AI drafts, humans decide

AI generates descriptions, historical context, translations and audio scripts (`README.md`, Project Structure, `app/services/ai/`). Human curators do not write directly to the catalogue: create, update and delete go through a `ContentChange` proposal that an admin approves (`app/models/content_change.rb`, `CHANGEABLE_CLASSES` covers Location, Experience, Plan, AudioTour and Review). Records carry an `ai_generated` flag so AI and human content can be told apart (`db/schema.rb`, locations, experiences, plans).

The vision sets the same boundary for the AI brain itself: it does not write code, run migrations or deploy directly, and it does not delete data without confirmation (`sources/planning/VISION.md`, "Šta Platform NE RADI direktno").

Traveller content follows the same rule. A moment (a traveller's photo and note) is private by default, and publishing it sends it to a curator for approval before anyone else can see it (`app/models/moment.rb`, `require_moderation_when_published`).

### Positive, diplomatic messaging

The curator persona is positive and diplomatic, and avoids hard topics: politics, war and ethnic divisions (`.claude/agents/curator.md`, "Tvoj karakter"). It gives rewrites as examples:

- Instead of "a war happened here", write "a city with a rich history and a symbol of renewal".
- Instead of labelling something Serb, Bosniak or Croat, write "a traditional dish of this region".
- Instead of "a divided city", write "a city with two characters, twice as much to see".

It never divides and speaks only of what is "bosanskohercegovačko" (of Bosnia and Herzegovina) (`.claude/agents/curator.md`, "Tvoja pravila"). The historian persona covers history "from the Illyrians to today" but avoids controversial modern history from 1990 on (`.claude/agents/historian.md`, description).

### Safety over completeness

A place is not published near a recorded mine-suspected area. Every coordinate change is checked against the BiH mine-suspected areas, and a match within the buffer blocks the save. The checker never says "safe" (`docs/mine_checker/README.md`, "Tvrda pravila"). See [features](features.md#mine-checker-and-minolovac).

### Bosnian first, then many languages

Content is written in Bosnian in the ijekavian variant, with "historija" and not "istorija" (`CLAUDE.md`, rule 4). The content director requires every location to have a Bosnian description and an English translation before work moves on (`.claude/agents/content-director.md`, quality checklist). The interface ships in 16 locales: en, bs, hr, de, es, fr, it, pt, nl, pl, cs, sk, sl, sr, tr and ar (`config/application.rb`). The default interface locale is English (`config/application.rb`, `default_locale = :en`), while the default audio tour locale is Bosnian (`db/schema.rb`, `audio_tours.locale` default `"bs"`).

## The longer ambition

The vision document describes "Platform", an autonomous AI brain meant to replace the admin dashboard with a conversational interface. It has three levels of awareness: content, code and infrastructure (`sources/planning/VISION.md`, "Vizija", "Tri nivoa svijesti"). The DSL and CLI part of this exists as `bin/platform` (`CLAUDE.md`). How much of the rest is live is covered in [architecture/platform-dsl.md](../architecture/platform-dsl.md) and [state.md](../state.md).
