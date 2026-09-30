---
title: Audio tours are paid by subscription; everything else stays free
kind: decision
status: accepted
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-09-30--usput--paid-audio-tours.md
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
---
# Audio tours are paid by subscription; everything else stays free

## Context

Usput earns nothing today. The operator wants it to make a profit, and audio
tours are the part of the product that costs money to make (script
generation and speech synthesis) and that a traveller uses in the moment,
standing at a place. Everything else, places, plans, walking a plan,
check-ins, moments and reviews, is what brings people to the site in the
first place.

## Decision

Audio tours are sold as a subscription with three plans that all renew until
cancelled: EUR 3 a week, EUR 6 a month and EUR 39 a year. A subscriber can
play every audio tour. Anyone can play the first stop of any tour as a
preview. There is no free trial and there are no codes. Everything that is
not an audio tour stays free.

The seller is a company in Vienna, Austria, which Stripe supports.
Payments go through Stripe: its hosted checkout, its customer portal for
cancelling and changing plans, and its webhooks as the record of who is
subscribed. Prices and payouts are in euros. Until the company's Stripe account is
verified, usput is built and tested against Stripe's test mode.

## Alternatives

- **Pay per tour, or a city pass.** Fits short stays better, since most
  visitors are in the country for days. Not chosen: one subscription is
  simpler to sell and to build, and the weekly plan covers a trip.
- **A merchant of record** such as Paddle or Lemon Squeezy, which would
  handle VAT and could pay out to a seller in Bosnia and Herzegovina. Not
  chosen: the operator will sell through a company abroad.
- **A local gateway** with a company in Bosnia and Herzegovina. Not chosen,
  for the same reason.
- **Keep audio free and sell other extras.** Rejected: audio is the one
  feature with a clear cost and a clear moment of use.

## Consequences

- Every plan renews, including the weekly one, so a traveller on a one-week
  trip is charged again unless they cancel. Checkout and the confirmation
  email must say when the next charge falls, and cancelling must take one
  step from the account page.
- Accounts are required to subscribe, which email on accounts already gives.
- Audio files must not be reachable by URL without an active subscription:
  every play goes through a short-lived signed link issued only to a
  subscriber, except the free first stop.
- An Austrian seller of digital services charges Austrian VAT to Austrian
  consumers and the buyer's country's VAT to consumers elsewhere in the EU,
  reported through the EU's One-Stop Shop; sales to consumers outside the
  EU, Bosnia and Herzegovina included, generally carry no EU VAT (unverified,
  2026-09-30: confirm with the company's tax adviser, including whether the
  small-business exemption applies at the start). Stripe Tax records where
  each buyer is.
- EU consumers have a right of withdrawal for digital content, which the
  checkout must handle (unverified, 2026-09-30: how the waiver on immediate
  access applies needs a source). An Austrian company's website also needs
  a legal notice (Impressum) naming the company. Terms of sale are part of
  the work, not an afterthought.
- Admins see subscriptions in Avo, read from Stripe; Stripe stays the source
  of truth for billing.
- The work is shaped in [paid audio tours](../initiatives/paid-audio-tours.md).
