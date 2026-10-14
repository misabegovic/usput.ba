---
title: Rails Event Store, Roundhouse and Spinel, and one repository, from the operator
date: 2026-10-14
via: conversation with the agent
---
# Event store, compiling, and one repository, 2026-10-14

The operator's words, verbatim, in the order they came, with what the agent
had said in between.

## Rails Event Store

> is there a use for the rails event store for Usput?

The agent answered that there is a narrow use (moderation history for the
Jev bands, the admin trail that `AdminEvent` and `CuratorActivity` cover,
handlers reacting to "review submitted"), that usput has nothing to
event-source, and recommended a plain table first.

> I just want to use the Rails event store for my project. We should also
> explore optimizations with Roundhouse and Spinel here.

## One repository

The agent was working in git worktrees beside the checkout
(`usput.ba-pr182`, `usput.ba-llm`, `usput.ba-langfuse`).

> let's keep everything in a single repository

> everything related to usput.ba should be in usput.ba repo

Read as: work happens in `/home/muhamed/projects/usput.ba` only, and usput
material kept elsewhere on the operator's machine moves into this
repository: the usput pages and conversations of the estate brain
(`~/projects/tt/brain`), the usput pages and sources of `phone-brain`, and
the Remotion promo project (`~/projects/usput-promo`).

## All devices

While the phone brain's deferral of wider mobile browser support
(2026-08-02, "do nothing for now") was being brought into this repository:

> we need to make sure the application works for all devices too.

The agent laid out three floors and asked how far back "all devices"
reaches. Answer: "iOS 15 / ~2019 Android". That covers the iPhone 6s, 7 and
first SE on their last iOS, and older Huawei and Android WebViews, through
es-module-shims, Tailwind 4.3's fallbacks, guarded localStorage and a
notice when JavaScript does not run, keeping the no-build setup. Anything
older still gets readable server-rendered pages and the notice.
