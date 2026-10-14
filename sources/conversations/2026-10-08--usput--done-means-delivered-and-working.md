---
title: "To the end means done, delivered and working"
date: 2026-10-08
kind: conversation
---

The integrator had read "drive it until the end" as stopping short of marking the PRs ready and merging them. The operator corrected it, verbatim:

> No, to the end means definition of done, done and delivered and working

Read as: for usput #183, #185 and the #111 tag filter, the operator's explicit approval (AGENTS.md sibling rule 6) to mark each ready for review and merge it once its CI is green, then to deliver it the way usput ships (its deploy from main), and to verify it working in production; a merge that breaks production is reverted. Scope is these usput PRs on the operator's own repository; it does not extend to other repositories or later PRs.
