---
title: Capturing a moment needs a check-in at the place
kind: decision
status: accepted
updated: 2026-10-08
repos:
- usput.ba
confidence: medium
sources:
- https://github.com/misabegovic/usput.ba/pull/164
- https://github.com/misabegovic/usput.ba/pull/165
- https://github.com/misabegovic/usput.ba/pull/166
- app/models/moment.rb
- app/views/plans/_moment_gallery.html.erb
- app/views/moments/update.turbo_stream.erb
- app/controllers/plans/visits_controller.rb
- config/locales/en.yml
- test/integration/explore_bosnia_test.rb
- test/system/explore_bosnia_test.rb
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - repo
    - web
---
# Capturing a moment needs a check-in at the place

## Context

The product said one thing and the code did another. PR #164 introduced moments with the words "At a place you have reached you can capture a moment", and the [feature inventory](../product/features.md) repeats it. The explore copy reads "Visit it, capture a moment, come back for more" (`explore_bosnia.subtitle` in `config/locales/en.yml`). A check-in already redraws the place's moments gallery (`Plans::VisitsController#create` renders `moments/update`), and a test from #165 carries the comment "capture is earned by being there".

Nothing enforced it. Neither `MomentsController#create` nor `Moment` asked for a check-in, and the upload tile rendered for every signed-in traveller. Three tests asserted the tile without a visit: two from #165 (the explore deck's moments panel) and one from #166 (a place read outside a plan). None of the pull request bodies, issues, commits, wiki pages or planning sources says that capture without a visit was wanted; the tests were the only place it was stated. The question was raised on 2026-10-08 by a concept map of the product, and the operator delegated the call.

## Decision

A moment is captured only at a place the traveller has checked in at, on any of their plans. `Moment` refuses to be created otherwise, with a message telling the traveller to mark the visit first, and the controller's existing failure path returns that message. The upload tile appears only once the place is visited; before that the moments panel still opens and shows other travellers' approved moments. A guest keeps the sign-in tile, because a guest's check-ins live on the device until sign-in replays them. The rule is asked on create only, so a moment outlives its check-in.

## Alternatives

- Amend the inventory to say capture needs no visit. Rejected: every written statement of intent says reached, and the check-in already redraws the gallery as though capture follows it.
- Ask for a check-in on the same plan as the moment. Rejected: a place reached on one trip is reached; the deck already treats a visit on any plan as visited, and the location page uploads to the plan its visit was on or to the explore plan.
- Hide the tile but let the server accept any capture. Rejected: the rule would then hold only for travellers who use the screen.

## Consequences

A moment now means the traveller was there, which is what a public moment shown to others implies. In the explore deck a card's moments panel offers capture after the check-in, not before. Tests that build a moment record a check-in first, and the three tests that asserted the tile without a visit now assert the opposite.

## Status notes

In force from the pull request that adds `Moment#captured_at_a_visited_place` (`app/models/moment.rb`) and the `visited_location?` guard on the upload tile (`app/views/plans/_moment_gallery.html.erb`). The message is `plans.moments.not_visited` in `config/locales/en.yml` and `config/locales/bs.yml`.
