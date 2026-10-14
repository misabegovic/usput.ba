---
title: Decisions are domain events in Rails Event Store
kind: decision
status: accepted
updated: 2026-10-14
repos:
- usput.ba
confidence: medium
sources:
- sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md
- Gemfile
- config/initializers/event_store.rb
- app/services/decision_log.rb
- app/events/moment_approved.rb
- app/avo/actions/approve_moment.rb
- app/avo/actions/change_role.rb
- config/routes.rb
- db/migrate/20261014125519_create_event_store_events.rb
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - other
    - repo
---
# Decisions are domain events in Rails Event Store

## Context

Who decided what about a record had no single place. `CuratorActivity` logs
some actions with IP and user agent, much of its vocabulary is for features
that are gone (proposals, photo suggestions), and edits in the admin write
nothing to it. The Avo initiative planned a small `AdminEvent` table for the
admin trail (slice 7), and Jev's three bands for reviews need a history per
review: submitted, judged, approved, rejected, overturned.

Asked on 2026-10-14 whether Rails Event Store had a use, the agent answered
that it had a narrow one and recommended a plain table first. The operator
answered: "I just want to use the Rails event store for my project"
([source](../../sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md)).

## Decision

- `rails_event_store` 3.2 keeps domain events in `event_store_events` and
  `event_store_events_in_streams` (jsonb data), through
  `RailsEventStore::JSONClient`.
- An event is a past-tense class in `app/events/`. The first seven are the
  decisions taken in the admin: `MomentApproved`, `MomentRejected`,
  `PlaceArchived`, `PlaceRestored`, `UserBlocked`, `UserUnblocked`,
  `UserRoleChanged` (with `from` and `to`).
- Each decision goes into its record's own stream, `Moment$<uuid>`, through
  one door, `DecisionLog.publish(event, record, by:)`, which names records
  and actors by uuid, never by database id. The change and its event are
  written in one transaction.
- Rails Event Store's browser is mounted at `/event-store`, for admins only;
  anyone else finds no route.
- The admin trail planned as `AdminEvent` is these streams; no table of its
  own is built.

## Alternatives

- **A plain `moderation_decisions` or `AdminEvent` table.** Less to learn,
  enough while each decision has one reader. The agent's recommendation; the
  operator chose Rails Event Store.
- **Keep `CuratorActivity`.** It stays for now beside the events (it feeds
  the spam limits), but it records no actor for most admin work.
- **Event-source the records.** Places, plans and check-ins are ordinary
  rows that nothing rebuilds from history; events record decisions, they do
  not replace the tables.

## Consequences

- A record's history reads in order from its stream (`DecisionLog.history`).
- Jev's review moderation publishes its own events into each review's
  stream, and Langfuse scores can be read from them later.
- Places archived through the Platform DSL publish nothing yet: the DSL has
  no actor, and it is the agents' tool, not the admin.
- Handlers can subscribe to these events later (a rating recount, a search
  sync), when a second reader of the same event exists.
