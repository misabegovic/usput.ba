---
title: Location accessibility
kind: initiative
status: living
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- app/models/location.rb
- app/models/browse.rb
- app/models/concerns/browsable.rb
- app/services/browse_adapter.rb
- app/controllers/new_design_controller.rb
- app/controllers/plans_controller.rb
- app/controllers/curator/locations_controller.rb
- app/views/curator/locations/_form.html.erb
- app/views/locations/show.html.erb
- app/views/plans/wizard.html.erb
- app/models/content_change.rb
- db/migrate/20260321151736_add_accessibility_to_locations_and_browses.rb
- db/schema.rb
- https://github.com/misabegovic/usput.ba/pull/154
- https://github.com/misabegovic/usput.ba/pull/168
- https://github.com/misabegovic/usput.ba/issues/15
depends_on:
- state.md
enola_intent:
  page:
    type: initiative
    status: living
    scope:
    - usput.ba
    origin:
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/state.md
---
# Location accessibility

## What

Every place can say how accessible it is for a wheelchair user, and travellers can ask for accessible places only, on explore and in the plan wizard. Delaida Muminovic contributed the work in PR #154 (commits 3f1e63d on 2026-03-21 and 23188b1 on 2026-03-25). It was brought up to date with main on 2026-09-29 (d3be6c5, abf62b0) and merged through #168 as 7955ae9, which GitHub also records as the merge of #154.

A place carries:

- a wheelchair access level: full, partial, none or unknown (`Location::WHEELCHAIR_ACCESS_LEVELS`);
- five features, each true or false: wheelchair parking, accessible toilet, flat terrain, elevator and ramp (`Location::ACCESSIBILITY_FEATURES`);
- free-text notes, for example where the ramp is.

A place counts as wheelchair accessible when its level is full or partial.

## How

- **Storage.** One `accessibility` JSONB column on `locations`, default empty, and a denormalised, indexed `wheelchair_accessible` boolean on `browses` for fast filtering (`db/migrate/20260321151736_add_accessibility_to_locations_and_browses.rb`).
- **Model helpers** in `app/models/location.rb`: `wheelchair_access` (defaults to unknown), `wheelchair_accessible?`, `accessibility_feature?`, `set_accessibility_feature`, `accessibility_notes`, `accessibility_summary`, `accessibility_known?`, and the `wheelchair_accessible` scope over the JSONB.
- **Search.** `BrowseAdapter` writes `wheelchair_accessible` onto a place's Browse row and adds "pristupačno wheelchair accessible" to its searchable text. Since abf62b0 a moment's Browse row takes the flag from its place, because moments read every Browse filter from their place since #167; without it the filter hid every moment (`app/services/browse_adapter.rb`). `Browse.by_accessible` filters on the boolean (`app/models/browse.rb`).
- **Explore.** An "accessible" toggle sets `accessible=true`, and `NewDesignController#explore` applies `by_accessible` (`app/controllers/new_design_controller.rb`). Place cards show a wheelchair badge.
- **Plan wizard.** A "only accessible places" option sends `accessibility_required`, and `PlansController#find_matching_locations` narrows to the `wheelchair_accessible` scope, together with the not-archived filter (`app/controllers/plans_controller.rb`, `app/views/plans/wizard.html.erb`).
- **Place page.** An accessibility card shows the level, the features present and the notes, only when something is known (`app/views/locations/show.html.erb`).
- **Curator form.** A section with the level select, five checkboxes and notes; the controller turns unchecked boxes into explicit false values (`app/views/curator/locations/_form.html.erb`, `app/controllers/curator/locations_controller.rb`). `accessibility` is on `ContentChange`'s safe attribute list, so a curator proposal can carry it (`app/models/content_change.rb`).
- **Locales.** Keys exist in both Bosnian and English; the merge added the ones neither side had.

## Why

A traveller in a wheelchair cannot use a plan that sends them to stairs. Issue #15, "Location proposal: accessibility", opened on 2026-01-07, asks for this information on places. Knowing it per place also lets plan generation avoid places that do not fit.

## Now

- Merged into main through #168 (7955ae9) on 2026-09-29, on top of the September traveller work.
- The data model, filters, place page and curator form work end to end for places whose accessibility is recorded.
- For every place without data, `wheelchair_access` reads unknown, `wheelchair_accessible?` is false, and the accessible filter hides it.

## Perceived

- The toggle reads as "show accessible places"; in practice it means "show places a curator has marked accessible". With little data recorded, turning it on shows few results, which a traveller may read as "few accessible places exist". How many places have data is (unknown, needs source): it depends on the production database.
- A moment is only as accessible as its place's Browse row was when the moment was last saved (see Target).

## Target

- **Re-sync moments when a place changes.** Browse rows sync on each record's own save (`app/models/concerns/browsable.rb`). A place's save updates the place's row, but nothing re-syncs the Browse rows of its moments, so a moment keeps the old `wheelchair_accessible` value until the moment itself is saved. The same holds for the other filters moments read from their place.
- **Fill the data for existing places.** Most places are unknown. Options are a curator pass, traveller reports, or an AI-assisted first guess marked for review; none is chosen.
- **Close or update issue #15** now that #168 is merged, noting what is covered (wheelchair access) and what is not (for example, visual or hearing accessibility, which the model has no fields for).
- **Consider an "unknown" choice** on the filter, so travellers can see places that are not ruled out.
