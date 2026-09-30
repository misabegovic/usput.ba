---
title: Paid audio tours
kind: initiative
status: proposed
updated: 2026-09-30
repos:
- usput.ba
confidence: medium
depends_on:
- decisions/audio-tours-by-subscription.md
- initiatives/secure-sessions.md
- initiatives/avo-admin-and-roles.md
- initiatives/rubyllm-2-upgrade.md
sources:
- sources/conversations/2026-09-30--usput--paid-audio-tours.md
- sources/conversations/2026-09-30--usput--platform-direction.md
- app/models/audio_tour.rb
- app/services/ai/audio_tour_generator.rb
enola_intent:
  page:
    type: initiative
    status: proposed
    scope:
    - usput.ba
    origin:
    - other
    - repo
    relations:
    - rel: depends-on
      to: wiki/decisions/audio-tours-by-subscription.md
    - rel: depends-on
      to: wiki/initiatives/secure-sessions.md
    - rel: depends-on
      to: wiki/initiatives/avo-admin-and-roles.md
    - rel: depends-on
      to: wiki/initiatives/rubyllm-2-upgrade.md
---
# Paid audio tours

## Objective

A traveller standing at a place can hear its story, and usput earns money
doing it. Audio tours become the paid part of the product, sold as a weekly,
monthly or yearly subscription, while everything else stays free
([decision](../decisions/audio-tours-by-subscription.md)).

## Background

Audio tours exist in today's app: an `AudioTour` belongs to a place, carries
a generated script and an audio file, and is produced by
`Ai::AudioTourGenerator` with ElevenLabs speech (`app/models/audio_tour.rb`,
`app/services/ai/audio_tour_generator.rb`). They are free, and nothing
generates them from the admin; they are made by scripts and tasks. The
rebuild keeps audio tours in version 1 and generates them from Avo.

The operator chose a subscription over paying per tour: EUR 3 a week, EUR 6 a
month, EUR 39 a year, every plan renewing, no trial, the first stop of every
tour free. The seller is the operator's sole proprietorship in Vienna, Austria,
registered for VAT, selling through its existing Stripe account in euros.

## Affected personas

- **Travellers** who want to listen: they subscribe, listen, and cancel from
  their account.
- **Visitors who never pay**: they lose nothing they have today except full
  audio tours, and can still hear every tour's first stop.
- **Admins**: they see who is subscribed and handle refunds, through Avo and
  Stripe's dashboard.

## Scope

1. **Plans and checkout.** Three Stripe prices, a pricing page, Stripe's
   hosted checkout for a signed-in traveller, and a return page. Test mode
   only until the company exists.
2. **Subscription state from webhooks.** Stripe's webhooks are the record of
   who is subscribed; usput keeps a small subscription row per user, updated
   only by verified webhook events, and never trusts the browser's return
   from checkout on its own.
3. **Gate the audio.** A tour's first stop plays for anyone. Every other
   stop plays through a short-lived signed link issued only to an active
   subscriber. The audio files are private in storage.
4. **Manage and cancel.** Stripe's customer portal from the account page:
   change plan, update the card, cancel in one step. The next charge date is
   shown on the account page and in every receipt.
5. **Emails.** Welcome, receipt with the next charge date, a reminder before
   a yearly renewal, payment failed, and cancelled, through the mail sender
   chosen for accounts.
6. **Avo.** A read-only subscription view per user and a link to the
   customer in Stripe.
7. **Taxes and terms.** Stripe Tax for VAT on EU consumers, terms of sale,
   the right of withdrawal for digital content handled at checkout, and the
   privacy policy naming Stripe.
8. **Measure.** Conversion from preview to subscription, churn per plan, and
   which tours are listened to most, so tour production follows what people
   play.

## No-gos

- No free trial and no promotional codes in version 1.
- No per-tour purchases or city passes.
- No payment details stored in usput: cards live only at Stripe.
- No paywall on anything but audio tours.

## Rabbit holes

- **The weekly plan renews.** A tourist can be charged a second week after
  going home. The checkout and emails must say it plainly, or chargebacks
  and complaints follow. Worth watching in the first month.
- **Offline listening.** Downloaded audio escapes the signed-link gate. Keep
  offline out of version 1 or accept the leak.
- **Keys stay out of the repository.** The repository is public; Stripe's
  secret and webhook keys live only in the app's credentials.
- **Enough tours to be worth paying for.** A subscription sells a catalogue.
  If only a few places have tours at launch, few will pay.

## Appetite

About two weeks of build once sessions, email and Avo exist, plus the
company and Stripe account setup, which is outside the code (unknown, needs
source for how long that takes).

## Decision needed

- **The seller** is settled (2026-09-30): a sole proprietorship in Vienna,
  registered for VAT, with a Stripe account. Development uses its test-mode
  keys; live keys are a launch step. Registering for the One-Stop Shop for
  EU consumers is for its tax adviser.
- **How many tours at launch** make the subscription worth offering, and
  which places get them first.
- **Refund policy**: whether a weekly subscriber who forgot to cancel gets a
  refund on request.
- **Whether the first free stop is enough of a preview**, or a free full tour
  at one showcase place (for example Stari most) sells it better.
