---
title: Bring your own agent
kind: idea
status: suggested
updated: 2026-10-14
repos:
- usput.ba
confidence: low
sources:
- sources/phone-brain/2026-08-02-2026-08-02-usput-ba-bring-your-own-agent-md--2026-10-14.md
- sources/conversations/2026-10-14--usput--event-store-compile-one-repo.md
- lib/platform/mcp_server.rb
---
# Bring your own agent

From the operator's internal note "Bring your own agent to Usput.ba",
published on muhamed.at and captured in the phone brain on 2026-08-02;
brought here on 2026-10-14.

## What

Usput exposed through an MCP server, so a traveller's own AI agent and the
agents of the people who serve travellers can talk to usput's Platform agent
directly. The agents ask, plan and negotiate; the humans approve the final
proposal. On the supply side the note names hotels, guesthouses and
apartments; restaurants, cafés and bars; guides and activity operators;
transfers and rentals; agencies and concierges; and individuals renting a
room, teaching a cooking class or guiding a hike. The Platform agent becomes
a matchmaker between demand-side and supply-side agents.

## Why interesting

- Planning in plain language across constraints a search form handles badly
  ("4 days in October, family with a toddler, wheelchair accessible"; "quiet
  mountain towns with good coffee").
- Trips that cross services (usput's places with flights, weather, calendar
  and lodging) in one conversation.
- Custom deals negotiated agent to agent before a person sees the offer
  ("private Una rafting for 8 people on July 14th").
- Providers answer fewer repeat questions.

## Maturity

An idea, not shaped. The pieces in the code today are far from it: the MCP
server in `lib/platform/mcp_server.rb` is for development only, refuses to
run in production, and exposes DSL queries rather than a travel agent's
vocabulary; three of its tools are broken. Usput has no booking, pricing or
provider accounts. Shaping would start with which one conversation is worth
serving first.
