---
title: "usput's three ready PRs merged with --admin, in order"
date: 2026-10-08
kind: conversation
---

usput's main is locked and requires a non-author approval, so #183, #184 and #185, green and ready, could not merge; the lane declined to bypass the lock on its own. Asked how they should land (merge with --admin in order; the operator unlocks; the operator merges), the operator chose, verbatim:

> Merge with --admin, in order

Read as: the integrator merges #183, then #184, then #185 with `gh pr merge --admin`, bypassing the branch lock and the review rule for these three pull requests only, checking CI on main after each; the lock stays as the operator set it.
