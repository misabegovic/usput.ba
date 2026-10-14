---
title: Redesign usput end to end with Impeccable
kind: initiative
status: proposed
updated: 2026-10-14
repos:
- usput.ba
confidence: low
depends_on:
- decisions/support-phones-from-ios-15.md
- architecture/frontend.md
sources:
- sources/conversations/2026-10-14--usput--map-cli-merging.md
- sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md
- sources/advice/2026-02-13-emir-glogic-mkt-analiza-usput--2026-10-14.md
- app/views/new_design/home.html.erb
- app/views/layouts/new_design.html.erb
- app/assets/stylesheets/application.tailwind.css
- config/locales/bs.yml
---
# Redesign usput end to end with Impeccable

The operator asked on 2026-10-14 to think about redesigning the app with
Impeccable, end to end, and in the same breath to take in a marketer's
advice on the site ([source](../../sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md)).
This page shapes that; nothing is built yet.

## Objective

Every traveller surface of usput (home, explore, the Explore Bosnia deck,
place, experience and plan pages, the plan wizard and walk, moments, the
profile, the mine check) redesigned as one coherent visual world, built with
Impeccable's process, working on every phone above the
[device floor](../decisions/support-phones-from-ios-15.md), in Bosnian and
English. The admin stays Avo's.

## Background

**The look today** is a Tailwind 4 theme with `primary` and `accent`
palettes and a gold button utility (`app/assets/stylesheets/application.tailwind.css`),
a `new_design` layout, and a home page of BiH landscapes with sections such
as "Zašto Usput.ba", "Zimska čarolija", "Otkrijte Audio Ture" and "Otkrijte
što drugi vole" (`app/views/new_design/home.html.erb`, `config/locales/bs.yml`).
There is no `DESIGN.md` or `PRODUCT.md`.

**Impeccable's process** (skill 4.4.0) starts from product context in
`PRODUCT.md` (`init`) and the incumbent design captured as `DESIGN.md`
(`document`), reviews it (`critique` for UX, `audit` for accessibility,
performance and responsiveness), chooses a replacement visual world for a
redesign (its new-work path), then builds and refines surface by surface
(`adapt`, `harden`, `clarify`, `polish`). It names a mode per surface:
Persuade for the home page, Operate for the wizard, walk and profile,
Experience for the deck and moments, Read for place pages and the mine
check.

**A map of BiH by municipality.** The operator's Dejtonska Igra card game draws an SVG of the country's 142 municipalities, with cantonal and entity outlines merged from their shared borders and a neighbour list for each, in about 70 KB, from polytiks.ba's `bih.json` in a 1000-unit drawing space; the operator suggested it for usput on 2026-10-14 ([source](../../sources/conversations/2026-10-14--usput--map-cli-merging.md)). It suits what Leaflet does badly: a light, offline-friendly picture of the whole country. Uses it invites: a travel profile that fills the municipalities a traveller has checked in at, a region picker for explore and the plan wizard, and a coverage view showing curators where the catalogue is thin.

**A marketer's advice** (Emir Glogić of The Simple, by email on 2026-02-13,
[source](../../sources/advice/2026-02-13-emir-glogic-mkt-analiza-usput--2026-10-14.md)),
in short:

- The home page should open on people of different kinds, not only
  scenery: "people love people", and visitors picture themselves where they
  see someone else.
- Lead with the experience, not "discover the beauty of BiH"; one line
  should hold experience, beauty, peace and adrenaline, since very
  different groups visit.
- "Why usput" should be told by others, through travellers' reviews, not
  by usput about itself.
- Do not promise hidden places and then show the best-known landmark; an
  image can also sort an audience in a way an international product must
  avoid.
- "Dojmovi naših gostiju" comes late and could be "Dojmovi naših
  istraživača" or similar.
- Seasonal content as categories ("Proljetne avanture", "Ljetne avanture")
  rather than one winter section.
- "Otkrijte šta drugi vole" should be video, and only video.

## Affected personas

- **Travellers and guests**, on every surface they use.
- **Curators**, only where their content shows (photos and copy must fit the
  new world); the admin is out of scope.

## Scope

1. **Context.** `PRODUCT.md` drawn from `wiki/product/` (purpose, personas,
   domain), and `DESIGN.md` from today's code, both cited from the brain.
2. **Review.** `critique` and `audit` of the current surfaces, desktop and
   phone, with the advice above as an input to the home page.
3. **Direction.** One replacement visual world, chosen by the operator from
   a small set of directions.
4. **Build, surface by surface,** home first, each a pull request with
   system tests and screenshots at phone and desktop width, and Bosnian and
   English copy.
5. **Hardening.** `adapt` and `harden` against the device floor, and the
   no-JavaScript notice.

## No-gos

- No redesign of the Avo admin.
- No effect that needs a browser above the device floor without a fallback.
- No copy that breaks the content rules: ijekavica, positive and regionally
  balanced, nothing on contested history from 1990 on.
- No images that put one community or city forward as "BiH".

## Rabbit holes

- **The map's licence.** The game's owner treated polytiks.ba's licence as no obstacle for the game; usput's repository is public, so redistributing that geometry needs polytiks.ba's terms, or the same municipal outlines rebuilt from an open source (geoBoundaries, OpenStreetMap) (unknown, needs source).
- **Coordinates.** The map's 1000-unit space is a drawing, not latitude and longitude; placing usput's places on it needs the projection worked out once.
- **What the map shows.** Usput's rules keep content positive and away from contested modern history: municipalities and regions, never entity lines or anything else from the game's political layers.

- **The rebuild.** The rebuild from scratch (2026-09-30) rewrites the UI
  anyway; redesigning the old views first would be done twice. The redesign
  likely belongs inside the rebuild's UI work.
- **Two sources of product truth.** `PRODUCT.md` and `wiki/product/` can
  drift; one has to be derived from the other.
- **Photography.** "People of different profiles" needs real, licensed
  photos of people in BiH, which usput does not have (unknown, needs
  source).
- **Video.** A video-only section needs video content and hosting decisions.

## Appetite

Large: a visual world and every traveller surface. Unknown in weeks until
the direction is chosen.

## Decision needed

- **Whether to start now** or fold the redesign into the rebuild's UI work.
- **Who supplies photography and video** of people.
- **How far to follow the advice**, point by point, on the home page.
- **Where `PRODUCT.md` and `DESIGN.md` live** and which is derived from
  which.
