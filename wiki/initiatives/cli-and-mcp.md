---
title: A proper usput CLI and MCP server
kind: initiative
status: proposed
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
- lib/platform/mcp_server.rb
- bin/platform
- bin/platform-mcp
- app/policies/admin_policy.rb
- https://ruby.sdk.modelcontextprotocol.io
---
# A proper usput CLI and MCP server

The operator asked on 2026-10-14 for "a proper CLI and MCP for usput" ([source](../../sources/conversations/2026-10-14--usput--map-cli-merging.md)). This
page shapes what proper means here; nothing is built yet.

## Objective

One command line and one MCP server that speak usput's own vocabulary
(places, experiences, plans, moments, reviews, the moderation queues,
generation and audio tours) rather than a query language, run under the
same roles and policies as the admin, and are safe to point at production.
The MCP server is the first step toward the [bring your own agent](bring-your-own-agent.md)
idea.

## Background

**Today's CLI.** `bin/platform` is a Thor CLI with four commands, `status`,
`version`, `query` and `exec`, all of which run Platform DSL queries
(`lib/platform/cli.rb`); its help is in Bosnian. It refuses production unless
`PLATFORM_CLI_ENABLED=true`, and `bin/platform-prod` points it at the
production database through `PROD_DATABASE_URL`. The DSL reads tables, runs
mutations, generation and audio synthesis, and reads code and logs
([Platform DSL](../architecture/platform-dsl.md)).

**Today's MCP server.** `bin/platform-mcp` is a hand-written stdio server
(`lib/platform/mcp_server.rb`) with five tools and three resources. It refuses
production unless `PLATFORM_MCP_ENABLED=true`, it has no authentication, and
three of its tools are broken: `prepare_fix`, `prepare_feature` and
`platform_prompts` call DSL commands removed on 2026-02-03, and the tests stub
the DSL, so the suite stays green. Its `platform_execute` tool exposes the
whole DSL, file reading and mutations included, to whoever can start it.

**What exists to build on.** The official Ruby SDK, `mcp` 1.7.0, implements
servers and clients over stdio and Streamable HTTP. Obie Fernandez's
`manceps` 1.0.1 is an MCP client with authentication, useful for testing a
server end to end. The admin's policies (`AdminPolicy` and one per resource)
already answer what each role may do, and `DecisionLog` records decisions in
Rails Event Store.

## Affected personas

- **The operator and the agents working on usput**, who run content, audits
  and generation from a terminal or an agent session.
- **Curators**, whose agents could work the moments and reviews queues.
- **Later, travellers' and providers' agents**, through the bring-your-own-agent
  idea, read-only to begin with.

## Scope

1. **One service layer under both.** Each command is a small object
   (`Usput::Commands::ListPlaces`, `ApproveReview`, `GenerateDescription`, ...)
   that takes an actor, asks the actor's policy, does one thing and, when it
   decides something, publishes through `DecisionLog`. The CLI and the MCP
   tools are thin doors onto the same objects, so a rule is written once.
2. **The CLI** (`bin/usput`), in English with Bosnian content: `places`,
   `experiences`, `plans` (list, show, search, archive, restore),
   `moments` and `reviews` (the queues, approve, reject), `generate`
   (description, translations, experience), `audio` (estimate, synthesize),
   `judge` (screen a review with Jev, dry run), `doctor` (keys, queues, mine
   data, Langfuse, Enola baseline). JSON output for agents, tables for people.
3. **The MCP server** on the official `mcp` gem: the same commands as tools
   with typed input schemas, resources for the schema and the brain's pages,
   over stdio for local agents and Streamable HTTP for remote ones.
4. **Authentication for HTTP**: a personal access token per user, created and
   revoked in the admin, carrying that user's role; every call is recorded.
5. **Read-only first.** The first release offers only reading commands over
   HTTP; deciding and generating follow once the audit trail is in place.
6. **The DSL stays** for the operator's ad hoc queries until the commands
   cover what it is used for; the broken MCP tools are removed at once.

## No-gos

- No command that bypasses a policy, and no second set of role rules.
- No file reading, code search or log reading over HTTP.
- No production access through `PROD_DATABASE_URL` from a laptop as the way
  remote agents work; remote agents go through the HTTP server and tokens.
- No prompts in Ruby strings: generation commands use `app/prompts/`.

## Rabbit holes

- **Two servers.** Keeping the hand-written server while building the SDK one
  means two of everything; the old one goes when the new one covers it.
- **Token scope.** A token per user with the user's role is simple; scoped
  tokens (read-only, one queue) are tempting and can wait.
- **Long calls.** Generation and audio take minutes; over MCP they should
  enqueue a job and return its id rather than hold the connection.
- **Enola.** New laws: commands are the only door to decisions from outside
  a request, and MCP tools never call models directly.

## Appetite

Medium for the command layer, the CLI and a read-only MCP server over stdio
and HTTP; the deciding and generating tools after that.

## Decision needed

- **Whether to start** now or after the rebuild's domain settles.
- **Who may call the HTTP server in production** in its first release:
  the operator only, curators, or anyone with an account.
- **Where it runs**: inside the Rails app (one deploy) or as its own process.
- **Whether the Platform DSL is retired** once the commands cover it.
