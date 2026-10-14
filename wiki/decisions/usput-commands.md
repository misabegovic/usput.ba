---
title: One set of usput commands behind the CLI and the MCP server
kind: decision
status: accepted
updated: 2026-10-14
repos:
- usput.ba
confidence: low
sources:
- sources/conversations/2026-10-14--usput--map-cli-merging.md
- sources/conversations/2026-10-14--usput--do-all.md
- app/commands/usput/command.rb
- app/commands/usput/commands.rb
- app/commands/usput/mcp_server.rb
- app/controllers/mcp_controller.rb
- app/models/api_token.rb
- app/services/decisions.rb
- lib/usput/cli.rb
- bin/usput
- .mcp.json
---
# One set of usput commands behind the CLI and the MCP server

## Context

The operator asked on 2026-10-14 for "a proper CLI and MCP for usput", and
later the same day to "do all" of the open work
([source](../../sources/conversations/2026-10-14--usput--do-all.md)). The
[initiative](../initiatives/cli-and-mcp.md) left four questions open: whether
to start now, who may call the HTTP server in production, where it runs, and
whether the Platform DSL retires. The old MCP server (`lib/platform/mcp_server.rb`)
was hand-written, unauthenticated, exposed the whole DSL including file
reading and mutations, and three of its five tools called commands removed
on 2026-02-03.

## Decision

The agent took the four open questions with the defaults below, under the
operator's "do all"; each is the operator's to reverse.

- **Start now**, before the rebuild's domain settles: the commands sit on
  today's models and policies, so they move with them.
- **One command layer.** Each command is a small object under
  `app/commands/usput/commands/` (`Usput::Commands::PlacesList`, `ReviewsApprove`, ...)
  that declares its parameters, says whether it reads or decides, asks the
  actor's policy, and returns plain data. Decisions go through `Decisions`
  (`app/services/decisions.rb`), which the admin's actions use too, so a
  rule and its event in Rails Event Store are written once.
- **The CLI** is `bin/usput`, in English with content in Bosnian: `places`,
  `experiences`, `plans`, `search`, `moments` and `reviews` with their
  queues and decisions, `reviews judge` (Jev's band, recorded nowhere),
  `history` and `doctor`. `--json` for agents, a table for people, `--as`
  names the account it acts as.
- **The MCP server** runs on the official `mcp` gem. Over stdio
  (`bin/usput mcp`, and `.mcp.json` for agents working in this repository)
  it offers every command as a tool, acting as `--as`, or as nobody, which
  reads only what is public.
- **Over HTTP**, inside the Rails app at `POST /mcp` (one deploy, no second
  process): a personal access token per user, issued with
  `bin/usput tokens issue`, kept only as a SHA-256 digest; **admins only**
  in this first release, and **reading tools only**. Each call is logged
  with the user and the method, and the token's last use is kept.
- **The DSL stays** for the operator's ad hoc queries. The old MCP server,
  `bin/platform-mcp` and its tests are removed; nothing called it.

## Alternatives

- **Keep the hand-written server** and fix its three tools. Rejected: it
  would still expose the DSL, file reading and mutations without a login.
- **A separate process for HTTP.** A second deploy for no gain while the
  callers are admins; it can move out later.
- **Curators over HTTP from the start.** Wider than needed before the
  audit trail of HTTP calls has been watched in use.
- **Generation and audio as commands now.** Left for the next step: they
  take minutes and should enqueue a job and return its id.

## Consequences

- A new rule is written once and reached from the admin, the terminal and
  agents alike; the Enola law "commands never wait on the AI pipeline" keeps
  model calls out of them, except Jev's dry run through `ReviewModeration`.
- Tokens are issued from a shell on the server; there is no admin page for
  them yet.
- Opening HTTP to curators, adding deciding tools over HTTP, or retiring the
  DSL are each a change to this page.
