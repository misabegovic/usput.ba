---
title: Domain vocabulary
kind: reference
status: living
updated: 2026-10-08
repos:
- usput.ba
confidence: medium
sources:
- db/schema.rb
- app/models/location.rb
- app/models/experience.rb
- app/models/experience_location.rb
- app/models/experience_category.rb
- app/models/experience_type.rb
- app/models/location_category.rb
- app/models/plan.rb
- app/models/plan_location.rb
- app/models/plan_experience.rb
- app/models/plan_visit.rb
- app/models/moment.rb
- app/models/like.rb
- app/models/review.rb
- app/models/browse.rb
- app/models/concerns/browsable.rb
- app/models/concerns/translatable.rb
- app/models/audio_tour.rb
- app/models/content_change.rb
- app/models/content_change_contribution.rb
- app/models/curator_review.rb
- app/models/curator_activity.rb
- app/models/curator_application.rb
- app/models/user.rb
- app/models/mine_check_audit.rb
- app/controllers/concerns/records_visits.rb
- docs/mine_checker/README.md
- https://github.com/misabegovic/usput.ba/pull/161
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - repo
    - web
---
# Domain vocabulary

This page names the entities of Usput.ba and how they relate. Each entry is grounded in `db/schema.rb` (schema version `2026_09_01_120000`) and the model file. Most public records carry a `uuid` and are addressed by it rather than by id (`Identifiable` concern, included in Location, Experience, Plan, Moment, AudioTour, Review, User and others). For who acts on these, see [personas](personas.md).

## Content catalogue

### Location

A place in BiH: a sight, restaurant, trail, guide or business. It has a name, city, coordinates, descriptions, historical context, contact details, tags, photos and a video URL (`db/schema.rb`, `locations`; `app/models/location.rb`). Name and descriptions are translatable (`Translatable` concern).

- **Categories.** Many-to-many with `LocationCategory` through `LocationCategoryAssignment`, one of which may be `primary`. The categories `guide`, `business` and `artisan` make a location a contact rather than a place (`location.rb`, scopes `places` and `contacts`).
- **Experience types.** Many-to-many with `ExperienceType` through `LocationExperienceType`, mirrored into the `suitable_experiences` JSON cache (`location.rb`).
- **Seasons.** A JSON list of `spring`, `summer`, `fall`, `winter`. An empty list means year-round (`location.rb`, `SEASONS`, `by_season`).
- **Budget.** An enum `low`, `medium`, `high`. The filter is cumulative: medium includes low (`location.rb`, `by_budget`).
- **Accessibility.** A JSON hash with `wheelchair_access` (`full`, `partial`, `none`, `unknown`), five feature flags (`wheelchair_parking`, `wheelchair_toilet`, `flat_terrain`, `elevator`, `ramp`) and free notes. A place counts as wheelchair accessible at `full` or `partial` (`location.rb`, accessibility helpers).
- **Archived.** `archived_at` retires a place from the traveller catalogue while its check-ins and moments survive. It is not a default scope, so curators can still see and restore it. The traveller entry points use `places`, `not_archived` and `Browse.syncable?` (`location.rb`, comment on `archived`). A location cannot be destroyed while travellers hold records on it, except through `destroy_with_traveller_records!` (`location.rb`).
- **Mine check.** Any coordinate change must pass the mine check, which fails closed (`location.rb`, `must_pass_mine_check`).
- **Relations.** Has many `experiences` (through `ExperienceLocation`), `audio_tours`, `moments`, `plan_visits` and polymorphic `reviews`. It also carries `ai_generated`, `needs_ai_regeneration`, `average_rating` and `reviews_count`.

### Experience

A curated, ordered set of locations, such as a tour or activity, with a title, description, estimated duration, seasons, a cover photo, contacts and optional cycling or hiking route data (distance, elevation, `route_geometry`) (`db/schema.rb`, `experiences`; `app/models/experience.rb`).

- **Relations.** Belongs to an optional `ExperienceCategory`. Has many locations through `ExperienceLocation` (ordered by `position`, one location once per experience). Has many plans through `PlanExperience`. Reviewable and translatable.
- **ExperienceCategory** groups experience types and has a `default_duration` in minutes (default 180). **ExperienceType** is a keyed classification linked to categories and to locations (`experience_category.rb`, `experience_type.rb`).

### Plan

A multi-day itinerary for a city, with title, dates, notes, `preferences` and `visibility` (`private_plan` or `public_plan`) (`app/models/plan.rb`). It belongs to an optional user, so a wizard-made plan can exist before anyone owns it. Title and notes are translatable. The preferences a device may set are `budget`, `meat_lover`, `custom_title` and `interests` (`plan.rb`, `DEVICE_PREFERENCE_KEYS`).

- **Plan stops.** Two ordered join tables, both keyed by `day_number` and `position`. `PlanExperience` puts experiences on days. `PlanLocation` puts standalone locations on days, exposed as `location_items`. Moving a `PlanLocation` renumbers the rest of that day (`plan_location.rb`, `move_to_position`, `move_to_day`).
- **Explore Bosnia plan.** A hidden private plan per user, marked `explore_bosnia: true` in preferences, that carries check-ins and moments made outside any itinerary. It is never listed (`plan.rb`, `explore_bosnia_for`).
- **Deletion.** Before a plan is destroyed, every traveller's check-ins and moments on it move to that traveller's Explore Bosnia plan (`plan.rb`, `rehome_traveller_records`; https://github.com/misabegovic/usput.ba/pull/161).

## Traveller records

### CheckIn (`PlanVisit`)

The product word is check-in; the table is `plan_visits`. A row records that a user reached a location on a plan. It is unique per user, plan and location, so the same place on two trips is two rows (`app/models/plan_visit.rb`). The server accepts one within 100 m of the place, except for admins (`app/controllers/concerns/records_visits.rb`, `MAX_VISIT_DISTANCE_KM`). A user's visited places and counts are projected from these rows, not stored (`app/models/user.rb`, `travel_profile_data`).

### Moment

A photo and an optional note (up to 1000 characters) that a user takes at a location on a plan (`app/models/moment.rb`). The photo is required: JPEG, PNG, GIF or WebP, at most 10 MB. A moment is created only where its user has a check-in at the location, on any plan; the check is made on create, so a moment outlives its check-in ([decision](../decisions/capture-needs-a-check-in.md)).

- **Visibility.** `private_moment` (default) or `public_moment`.
- **Moderation.** `pending`, `approved`, `rejected`. Making a moment public resets it to `pending`, so a curator must approve it before others see it. Only public and approved moments are `publicly_visible`, likeable, shareable and indexed in Browse.
- **Likes.** A `Like` is its own record, one per user per moment, kept in `likes_count` by a counter cache (`app/models/like.rb`).
- **Relations.** Belongs to user, plan and location.

### Review

A 1 to 5 star rating with an optional comment (up to 1000 characters) and an optional author name, attached polymorphically to a Location, Experience or Plan (`app/models/review.rb`). The user is optional, so anonymous reviews are allowed. Saving a review recomputes the target's `average_rating`. There is no moderation status in the schema today; a plan for one exists in `sources/planning/REVIEW_APPROVAL_SYSTEM.md` (https://github.com/misabegovic/usput.ba/pull/152).

## Search

### Browse

The denormalised search index. One row per public Location, Experience, Plan or Moment, with title, description, city, coordinates, rating, budget, seasons, category keys, `wheelchair_accessible` and a stored `tsvector` column weighting title over description (`db/schema.rb`, `browses`; `app/models/browse.rb`). Records join it through the `Browsable` concern, which syncs after save and removes after destroy. `Browse.syncable?` decides membership: locations that are not archived, all experiences, public plans, and public approved moments. Scopes cover full-text and fuzzy search, city, rating, budget, category, season, accessibility, origin (AI or human) and nearby.

## Audio and media

### AudioTour

A narrated script and audio file for one location in one language (`app/models/audio_tour.rb`). One tour per location per locale. Supported locales include bs, en, de, hr, sr, fr, it, es, nl, pl, cs, sl, tr and ar. It records the TTS provider, voice, word count and duration.

## Curation

### Proposals (removed)

Until 2026-09-30 curators changed content through a **ContentChange** (a proposed create, update or delete that an admin approved or rejected), with **ContentChangeContribution** rows for later curators and **CuratorReview** comments with a recommendation. All three and their tables were removed; curators now edit directly in the admin.

### CuratorActivity

The audit trail of curator and admin actions: proposals, reviews, logins, moderation of moments, approvals, user changes, and archiving or restoring a location (`app/models/curator_activity.rb`, `ACTIONS`). It stores IP and user agent, and it feeds the spam limits on `User`.

### User

An account with a unique lowercase username, a password, an avatar, a `user_type` of `basic`, `curator` or `admin`, spam-block fields and a `travel_profile_data` JSON blob (`app/models/user.rb`).

## Safety

### Mine Checker

A fail-closed safety layer that checks coordinates against recorded mine-suspected areas in BiH (`docs/mine_checker/README.md`). It never answers "safe". The runtime reads precompiled static artifacts from `db/data/mine_checker/static/`, and the database keeps only **MineCheckAudit**, an internal log of every check with its verdict, `data_as_of` date and match details that are never shown to users (`app/models/mine_check_audit.rb`). The public check answers only in coarse bands: `danger`, `caution`, `no_known`, `out_of_coverage` and `unavailable`. See [architecture/mine-checker.md](../architecture/mine-checker.md).

## Supporting vocabulary

- **Translation** stores one translated field value per record and locale, with a fallback chain (`app/models/translation.rb`, `app/models/concerns/translatable.rb`). **Locale** lists the languages and whether AI supports them.
- **AiGeneration** logs an AI generation run per city and type, with counts of created locations and experiences (`db/schema.rb`, `ai_generations`).
- **Setting** is a key and value store by category (`app/models/setting.rb`).
- An `events` table exists in the schema (a titled event at a location with a start time and duration), but there is no `Event` model in `app/models/` (unverified, 2026-09-29).
