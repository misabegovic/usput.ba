---
title: A proper usput CLI and MCP server
kind: initiative
status: living
updated: 2026-10-14
repos:
- usput.ba
confidence: low
depends_on:
- architecture/platform-dsl.md
- initiatives/bring-your-own-agent.md
sources:
- sources/conversations/2026-10-14--usput--map-cli-merging.md
- lib/platform/cli.rb
- bin/platform
- app/policies/admin_policy.rb
- https://ruby.sdk.modelcontextprotocol.io
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
# A proper usput CLI and MCP server

## What

One command line, `bin/usput`, and one MCP server that speak usput's own
vocabulary rather than a query language, run under the admin's roles and
policies, and are safe to point at production. The operator asked for "a
proper CLI and MCP for usput" on 2026-10-14
([source](../../sources/conversations/2026-10-14--usput--map-cli-merging.md)),
and later that day to "do all" of the open work, which started it
([source](../../sources/conversations/2026-10-14--usput--do-all.md)). How it
is built, and the four choices the agent made for the operator, are in the
[decision](../decisions/usput-commands.md).

## How

- **Commands** (`app/commands/usput/`): each one declares its parameters and
  whether it reads or decides, asks the actor's policy, and returns plain
  data. 18 so far: `places list|show|archive|restore`, `experiences list|show`,
  `plans list|show`, `search`, `moments queue|approve|reject`,
  `reviews queue|approve|reject|judge`, `history`, `doctor`. Decisions go
  through `Decisions` (`app/services/decisions.rb`), which the admin's
  actions now share, so each records its Rails Event Store event once.
- **The CLI**, `bin/usput`, prints a table or, with `--json`, JSON; `--as
  EMAIL` names the account it acts as; bare values fill the required
  parameters in order. Its log goes to stderr, so stdout carries only the
  answer.
- **The MCP server** runs on the official `mcp` gem. `bin/usput mcp` serves
  every command over stdio (`.mcp.json` points agents in this repository at
  it); `POST /mcp` serves the reading ones over HTTP to an admin's personal
  access token (`bin/usput tokens issue|list|revoke`, kept as a SHA-256
  digest). The brain's index, state and features pages are resources.
- **Enola** holds two laws: commands never wait on the AI pipeline, and
  never depend on the Platform DSL (`enola/constraints/usput.rb`).

## Why

The old server (`lib/platform/mcp_server.rb`, removed) had no login,
exposed the whole DSL including file reading and mutations, and three of its
five tools were broken while its tests stubbed the DSL. Agents and the
operator needed the same verbs the admin offers, under the same rules, from a
terminal and from an agent session; and the
[bring your own agent](bring-your-own-agent.md) idea needs a server with
authentication first.

## Now

- Built on 2026-10-14 and tried by hand in development: the CLI against the
  seeded database, the stdio server driven by the gem's own client (18 tools,
  calls and resources), and HTTP against a running server (401 without a
  token, 12 reading tools for an admin's token, the call logged and the
  token's last use kept, then revoked).
- Tests: `test/commands/usput/`, `test/lib/usput/cli_test.rb`,
  `test/integration/mcp_http_test.rb`, `test/models/api_token_test.rb`.
- The Platform DSL and `bin/platform` stay for ad hoc queries.

## Perceived

- `reviews judge` sends a review's text to TypeSafe as a moderation call
  does, and records nothing; it is offered over HTTP to admins as a read.
- Tokens are issued from a shell, not from the admin; whoever has a shell on
  the server can already act as anyone.

## Target

- **Generation and audio** as commands that enqueue a job and return its id
  (`generate description`, `generate translations`, `audio estimate|synthesize`).
- **Tokens in the admin**: list and revoke in Avo, issue from the account page.
- **Curators over HTTP**, and deciding tools over HTTP, once the call log has
  been watched in use; each a change to the decision.
- **Retire the DSL** verb by verb as the commands cover what it is used for.
