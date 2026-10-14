---
title: The Dayton game's map, a proper CLI and MCP, and merging, from the operator
date: 2026-10-14
via: conversation with the agent
---
# Map, CLI and MCP, merging, 2026-10-14

The operator's words, verbatim, in order.

> there's a beautiful digital map of bosnia that's built and used by post
> dayton bih game. the repo is on this device. maybe we can and should use it
> for usput?

The agent found it in the operator's Dejtonska Igra card game
(`~/projects/klosaer/card-game`): an SVG of BiH's 142 municipalities with
cantonal and entity outlines merged from shared borders, built from
polytiks.ba's `bih.json` in a 1000-unit drawing space (about 70 KB), whose
licence the game's owner did not treat as an obstacle for the game.

> we need a proper CLI and MCP for usput also

After the six open pull requests were merged, the agent asked whether to
keep merging its own pull requests with `gh pr merge --admin` once `bin/ci`
was green and signed off. Answer: "Yes, merge when green".
