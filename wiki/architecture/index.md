---
title: Architecture
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
sources:
- AGENTS.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - repo
---
# Architecture

How the code is built and why. Each page separates what the code does today
from what older plans describe, because the two have drifted.

- [Architecture overview](overview.md): the stack, the two databases, deploy, CI, and the main parts of the code.
- [Platform DSL](platform-dsl.md): the query language, parser, executors, CLI and MCP server, and the gap to the original vision.
- [AI content pipeline](ai-content-pipeline.md): the AI services, where prompts live, and how their output reaches people.
- [Mine Checker](mine-checker.md): keeping every place away from recorded mine-suspected areas, and the Minolovac game.
- [Conventions](conventions.md): how code, content, translations and commits are written here.
- [Frontend](frontend.md): Stimulus, the maps, the card deck, photos, offline.
