---
title: Mine Checker data from EUFOR maps
kind: decision
status: accepted
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- docs/mine_checker/ADR-001-mine-data-source.md
- config/mine_checker.yml
- app/services/mine_checker/base_check.rb
- app/services/mine_checker/static_index.rb
- app/models/location.rb
- scripts/mine_checker/scrape_eufor_pdfs.py
enola_intent:
  page:
    type: decision
    status: accepted
    scope:
    - usput.ba
    origin:
    - repo
---
# Mine Checker data from EUFOR maps

## Context

Usput.ba must stop geo content from being created near suspected mined areas in Bosnia and Herzegovina. BHMAC keeps the authoritative, daily updated database but publishes no public WMS, WFS or GeoJSON service. Phase 1 (an internal check) needed a data source that would not block development while talks with BHMAC and UNDP about an official feed go on. Decided by Muhamed on 2026-07-20; the original is `docs/mine_checker/ADR-001-mine-data-source.md`.

## Decision

For Phase 1, extract vector data from the EUFOR MICC PDF maps (the public Henning-arround/BiH_mines pipeline over 80 JOG sheets, BHMAC data, all of BiH), with an explicit plan to move to an official BHMAC feed in Phase 2. Built-in safeguards:

- The data is used internally only and never shown to users.
- Every result carries `data_as_of`, and staleness fails closed.
- A 500 m buffer covers the source's 1:50,000 precision and GPS error.
- Degenerate geometries from the extraction count as danger and are buffered, never dropped.

## Alternatives

- Wait for an official BHMAC or UNDP agreement before writing code. Rejected: until then the platform has no protection at all, which is worse than a conservative snapshot, and a working system is a stronger argument in the negotiation.
- Reverse engineer the backend of the "BH Mine Suspected Areas" mobile app. Rejected as legally and ethically unacceptable (undocumented API, licence) and fragile.
- DRAS (drasinfo.org) tile layers. Rejected: UNDP data for selected municipalities only, with no documented service.

## Consequences

An internal safety layer works at once and doubles as a demo for the BHMAC and UNDP pitch. The snapshot ages, so a refresh process and a hard staleness threshold are required. Source precision forces a wide buffer and more false positives, accepted as an asymmetric trade-off. Phase 2 (a public route check API and any display) depends only on a signed agreement with BHMAC and UNDP, and a new ADR will replace this one then.

## Status notes

Mostly matches; Phase 1 landed in commit 84d74b4 (#157, 2026-07-21). `config/mine_checker.yml` sets `buffer_m: 500`, `staleness_days: 365` and a BiH bounding box. `Location` refuses a coordinate change that fails `MineChecker::PointCheck` (`app/models/location.rb`), and every check writes a `MineCheckAudit` row. The refresh script lives at `scripts/mine_checker/scrape_eufor_pdfs.py`, not `scripts/scrape_eufor_pdfs.py` as the ADR says.

One rule diverges. The ADR says staleness fails closed, and the comment in `config/mine_checker.yml` still says so, but `app/services/mine_checker/base_check.rb` records an owner decision of 2026-07-21 that old data does not block: only missing data returns `:data_stale`, and results carry the snapshot date as a caveat. `StaticIndex#stale?` (`app/services/mine_checker/static_index.rb`) exists but no check calls it. The checks also run on a static index with no database geometry, although the ADR names PostGIS as context.
