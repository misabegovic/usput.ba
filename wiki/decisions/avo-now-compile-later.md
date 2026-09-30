---
title: Avo now; compiling with Roundhouse and Spinel later
kind: decision
status: accepted
updated: 2026-09-30
repos:
  - usput.ba
confidence: medium
depends_on:
  - decisions/admin-through-avo.md
sources:
  - sources/conversations/2026-09-30--usput--platform-direction.md
  - https://github.com/rubys/roundhouse
  - https://github.com/matz/spinel
  - Gemfile
---
# Avo now; compiling with Roundhouse and Spinel later

## Context

The operator wants to compile usput with Roundhouse, Sam Ruby's Rails
compiler, and Spinel, Matz's ahead-of-time Ruby compiler, and serve the
compiled binary. The operator also wants Avo for the admin.

Roundhouse cannot mount a Rails engine other than Active Storage, and Avo is
an engine. Its own documentation also says it is not ready for production
use, and the compiled path it documents covers SQLite, disk storage and an
in-process job queue, where usput uses Postgres, S3 and Solid Queue.

## Decision

Avo is adopted now. Compiling usput is kept as a goal but not pursued yet.
Until then Roundhouse is used for what it can do today on an unmodified app:
`roundhouse check`, its static analysis of types, nil-safety and N+1
queries, first as a report and then as a CI gate, and its MCP server for
agents.

## Alternatives

- **Split the app**: Avo on CRuby, the traveller site compiled, one database.
  Deferred; it only makes sense once the compiled path supports what the
  traveller site uses.
- **Skip Avo to stay compilable**: a hand-built admin with no engines.
  Rejected; it keeps the maintenance cost the operator wants gone.

## Consequences

- The admin will not compile, so a future compiled deployment serves the
  traveller site and leaves the admin on CRuby, or waits for engine support.
- Each thing that blocks compiling is tracked in
  [Roundhouse analysis and compile](../initiatives/roundhouse-analysis-and-compile.md),
  so the gap shrinks on purpose rather than by accident.
