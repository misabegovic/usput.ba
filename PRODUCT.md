# Product

<!-- impeccable:product-schema 1 -->

<!-- Derived from the brain (wiki/product/purpose.md, personas.md, domain.md,
features.md) on 2026-10-14. The wiki is the authority: when they disagree,
fix this file from the wiki, never the other way. Facts marked (inferred)
were drawn from the repository by an agent and wait for the operator's
confirmation; the operator was not interviewed for this file. -->

## Platform

web

## Users

- **Travellers in Bosnia and Herzegovina, local and foreign**, on a phone,
  often outdoors and on the move: finding what to see and do near them or in
  a city, putting places into a plan, walking it, checking in within 100 m
  of a place, and keeping photo moments of what they saw. Browsing, the plan
  wizard and the Explore Bosnia deck need no account.
- **Curators**, trusted volunteers who edit places, experiences, plans and
  audio tours and decide moments and reviews in the admin (Avo, out of scope
  for the redesign).
- **Admins**, who change roles, block accounts and delete content.

## Product Purpose

Help a traveller discover the whole of Bosnia and Herzegovina, not only its
best-known landmarks, plan it, walk it on the ground and keep what they
saw. Success (inferred): travellers who leave with a plan they actually walk,
check in along it, and come back for the next region.

## Positioning

A guide to all of Bosnia and Herzegovina in balance, from the Una to the
Drina, built only from real places that are checked against the country's
boundary and against recorded mine-suspected areas before they are
published, drafted with AI and decided by people.

## Operating Context

- Phones first, from iOS 15.4 and Android browsers that still update
  (Chrome and WebView 99, Samsung Internet 18, Firefox 115), with a notice
  below that floor and server-rendered pages without JavaScript.
- Outdoors, with patchy mobile data: an offline banner, a travel profile kept
  on the device, check-ins replayed when a guest signs in.
- Sixteen interface languages; content written in Bosnian (ijekavica) with
  English translations, audio tours in several languages.

## Capabilities and Constraints

- Explore search with filters for type, season, budget, duration, rating,
  city, tag, origin, audio and wheelchair access; the Explore Bosnia deck of
  places, nearest first; place, experience and plan pages; the plan wizard;
  walking a plan with check-ins; moments with likes; a travel profile;
  reviews sorted by Jev and decided by curators; the mine check at
  `/mine-check` and the Minolovac game.
- Rails 8 with Hotwire and Tailwind 4, an import map with `es-module-shims`;
  no build step for JavaScript.
- Every interface string in Bosnian and English at least.
- Undecided: who supplies photography and video of people; whether the
  redesign starts before or inside the rebuild.

## Brand Commitments

- The name Usput.ba ("usput": along the way).
- Voice: warm, positive and diplomatic; everything is presented as of Bosnia
  and Herzegovina, never as one community's. Nothing on contested history
  from 1990 on. Bosnian in ijekavica ("historija", not "istorija").
- A map of the country shows municipalities and regions, never entity lines.

## Evidence on Hand

- BiH landscape photographs in `app/assets/images/hero_backgrounds/` and
  curators' photos of places.
- Travellers' reviews and public moments, few so far (counts are in the
  production database, unknown here).
- A marketer's advice on the home page
  (`sources/advice/2026-02-13-emir-glogic-mkt-analiza-usput--2026-10-14.md`).
- No licensed photographs or video of people, no testimonials beyond real
  reviews, no press. Future work must not invent any.

## Product Principles

1. The whole country, in balance: no region, city or community stands for
   "BiH".
2. Real places only, and safety over completeness.
3. People decide: AI drafts, curators and travellers' own words carry the
   proof.
4. Made for a phone in a hand, outdoors, on a weak signal.
5. Lead with the experience a traveller will have, not with superlatives.

## Accessibility & Inclusion

- Wheelchair access is recorded per place and filterable; an outing passes
  only when every place on it does.
- Arabic is one of the sixteen locales, so layouts must hold right to left
  (inferred: no right-to-left audit is recorded).
- The device floor above, and pages that work without JavaScript.
