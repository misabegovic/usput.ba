---
title: Local CI, Enola laws and Obie's gems, from the operator
date: 2026-10-14
via: conversation with the agent
---
# Local CI, Enola and Obie's gems, 2026-10-14

The operator's words, verbatim, in order.

> also, I want to use enola for usput.ba

> there's the enola-rb gem

> I mean within the repo so when folks pull the repo or see it they also see
> enola used

> maybe we should also try to use the gems Obie has been putting out for our
> CI etc ? also use enola for CI and use the constraints it has. define them
> yourself for the app.

> all of our CI needs to be local also, we don't have github actions minutes
> to spare

The agent then disabled the GitHub workflow (`gh workflow disable ci.yml`)
so that no further push spent minutes. `main` required one approving review
and no status checks.

> ok, merge and continue

Read as: merge the six open pull requests (#186, #187, #182, #188, #189,
#190), each brought up to date with main and checked locally first, with
`gh pr merge --admin` since main asks for a review by someone other than the
author; then continue with the queued work, local CI first.
