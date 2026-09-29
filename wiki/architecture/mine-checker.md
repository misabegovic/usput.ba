---
title: Mine Checker
kind: reference
status: living
updated: 2026-09-29
repos:
- usput.ba
confidence: medium
sources:
- docs/mine_checker/README.md
- docs/mine_checker/SPEC.md
- docs/mine_checker/ADR-001-mine-data-source.md
- app/services/mine_checker/base_check.rb
- app/services/mine_checker/point_check.rb
- app/services/mine_checker/route_check.rb
- app/services/mine_checker/result.rb
- app/services/mine_checker/config.rb
- app/services/mine_checker/static_index.rb
- app/models/location.rb
- app/controllers/mine_check_public_controller.rb
- app/controllers/minesweeper_controller.rb
- app/javascript/controllers/mine_check_controller.js
- app/javascript/controllers/minesweeper_controller.js
- config/mine_checker.yml
- config/routes.rb
- config/initializers/rack_attack.rb
- config/locales/bs.yml
- db/data/mine_checker/static/meta.json
- lib/tasks/mine_audit.rake
- Gemfile
- https://github.com/misabegovic/usput.ba/pull/157
depends_on:
- architecture/overview.md
enola_intent:
  page:
    type: reference
    status: living
    scope:
    - usput.ba
    origin:
    - repo
    - web
    relations:
    - rel: depends-on
      to: wiki/architecture/overview.md
---
# Mine Checker

Bosnia and Herzegovina still has about 820 km² of mine-suspected area, and
Usput.ba sends people onto the terrain. The Mine Checker keeps the platform
from placing content near those areas, lets anyone check a point against
them in coarse bands, and teaches through a minesweeper game ("Minolovac")
played on real map cells. It shipped in #157 on 2026-07-21. The living
specification stays at `docs/mine_checker/` because the code cites it by
section; this page summarizes it and records where the code and the
documents now differ.

## The documents

- `docs/mine_checker/SPEC.md` (2026-07-20) specifies Phase 1: an internal,
  fail-closed check on every geo-content create and update, hard-blocking
  anything within 500 m of a suspected area. It describes a PostGIS
  `mine_areas` table, a DATA_AS_OF-gated import, `PointCheck` and
  `RouteCheck` services, an immutable `Result`, a `MineCheckAudit` log, the
  required disclaimer texts in bs and en, SPEC §8 tests, and a "do not" list
  (no public endpoints, never soften a verdict with cleared layers, never
  tune thresholds in code).
- `docs/mine_checker/ADR-001-mine-data-source.md` (2026-07-20, accepted)
  chooses the data source: vector extraction of EUFOR MICC mine
  contamination PDF maps (BHMAC data, 1:50,000 JOG sheets) through the
  open-source Henning-arround/BiH_mines pipeline. It rejects waiting for an
  official BHMAC/UNDP feed (no protection meanwhile), reverse engineering
  the "BH Mine Suspected Areas" app backend (legally and ethically
  unacceptable), and DRAS tiles (partial coverage). It accepts a large
  buffer and more false positives as the price of a coarse source.
- `docs/mine_checker/README.md` is the operational record. It is written in
  Bosnian and holds the owner decisions of 2026-07-21 that change the SPEC
  and the ADR, listed below.

## How it works now

**Static engine, no spatial database.** By owner decision on 2026-07-21 all
runtime logic reads precomputed artifacts in
`db/data/mine_checker/static/`, and the application has no PostGIS
dependency and no `mine_areas` table. The artifacts are bit masks per band
(`inside.bin.gz` at 50 m cells, `danger.bin.gz` at 100 m for the 500 m
band, `caution.bin.gz` at 200 m for the 2 km band), `overview.json.gz` for
the national zoom, simplified boundary tiles per 0.25 degree, and
`meta.json` with `data_as_of`, the bounding box and grid sizes.
`MineChecker::StaticIndex` loads them (overridable with `MINE_STATIC_DIR`).
Every mask is dilated by its band radius plus half a cell diagonal, so
rasterizing can only widen a band, never narrow it. A 2026-07-21 check of
3,000 random points against the vector truth gave 97.5% identical bands,
every disagreement toward the wider band, and a median of 0.008 ms per
check against 3.3 ms in PostGIS. PostGIS is used only offline, in
`scripts/mine_checker/build_static_artifacts.rb`.

**Data.** The vendored snapshot in `db/data/mine_checker/` is dated
2024-07-31 and holds 11,068 suspected polygons, 8,329 cleared polygons, 925
lifted minefields and 1,442 incidents. Refreshing means running
`scripts/mine_checker/scrape_eufor_pdfs.py`, the extraction steps
(`pdf_to_svg.sh`, `detect_elements.ipynb`) and the builder with a new
`DATA_AS_OF`, then committing the artifacts.

**Configuration.** `config/mine_checker.yml` sets `buffer_m: 500`,
`staleness_days: 365` and `bih_bbox: [15.5, 42.4, 19.7, 45.4]`, with an
optional override under `mine_checker:` in Rails credentials
(`MineChecker::Config`). The SPEC forbids tuning these in code and says the
buffer may drop below 300 m only with BHMAC-grade data.

**Checks.** `MineChecker::PointCheck.call(lat:, lon:)` and
`MineChecker::RouteCheck.call(points:)` share `BaseCheck`. Outside the
bounding box the verdict is `:out_of_coverage`. With no artifacts it is
`:data_stale`, which counts as blocked. A point in the danger band, or a
route with any segment crossing it (grid traversal, not vertex tests), is
`:blocked`. Everything else is `:no_known_intersections`, the only positive
verdict; the word "safe" is never used. A route is checked whenever the
line touches BiH, even if both ends lie outside. Every check writes a
`MineCheckAudit` row, blocked or not, and match details live only there.

**Where it is enforced.** `Location` validates `must_pass_mine_check`
whenever `lat` or `lng` changes, adding a geometry-free error for
`:blocked` (with the snapshot date) or `:data_stale`
(`app/models/location.rb`). Because it is a model validation, it covers the
curator dashboard, the Platform DSL and seeds alike; seeds skip blocked
locations with a warning. `rake mine_data:audit_existing` checks all
existing locations and prints the blocked ones without changing anything
(`lib/tasks/mine_audit.rake`). `RouteCheck` has no caller outside its tests
yet.

## Public check (Phase 2)

On 2026-07-21 the owner approved a public proximity check at `/mine-check`,
replacing the SPEC's "no public routes" rule. `MineCheckPublicController`
answers `POST /mine-check/check` with a band only: `danger` (inside or
within 500 m), `caution` (500 m to 2 km), `no_known` (with the data date and
"not a guarantee"), `out_of_coverage` or `unavailable`, plus `data_as_of`
and a `stale` flag. No distance or geometry leaves the server. Warnings show
whatever the data's age; staleness only adds caveats. Missing data answers
`unavailable` and points to BHMAC. The page carries a permanent warning
block (snapshot date, not a guarantee, not for navigation, BHMAC, police
122, civil protection 121, the official app). Each check is audited with
`content_type: "PublicMineCheck"`.

`GET /mine-check/areas` returns simplified (about 40 m) outlines of
suspected areas for the current viewport, with a legend saying the edges
are approximate and danger can extend past them. The viewport is capped at
4° by 3°, shapes at 800, and no source metadata is sent.
`config/initializers/rack_attack.rb` limits checks to 30 a minute per IP,
which also makes scanning for boundaries harder, and the areas endpoint to
60 a minute. The browser side is `mine_check_controller.js`, which only
styles the band it is given.

## Minolovac, the minesweeper game

`/minesweeper` (`MinesweeperController`, `minesweeper_controller.js`) is an
educational minesweeper on real map tiles. The board is a geographic grid
(9 by 9 at 150 m cells on easy, 12 by 12 at 125 m on medium, 14 by 14 at
100 m on hard), and a mine is any cell that overlaps a recorded suspected
area: the same generalized layer as the check map, downsampled, so the game
reveals nothing new. Preset regions (Sarajevo, Mostar, Banja Luka, Jajce, NP
Una, NP Sutjeska) are anchored on the largest suspected area within 30 km,
so every preset has real mines. There is no first-click protection. The
game plays only where the data records something; an empty board shows an
educational message. The page carries the full warning block: an empty cell
is not safe ground, the data is a 2024 snapshot, there is no second chance,
it is not for navigation. The Bosnian title "Minolovac" comes from
`config/locales/bs.yml`.

## Safety posture in one list

- Never say "safe". The best answer is "no known intersections", always
  with the data date.
- Fail closed only on missing data. Age does not block (owner decision,
  2026-07-21: the mine picture changes slowly); every answer carries the
  snapshot date instead.
- Cleared and lifted layers never soften a verdict.
- Degenerate geometries from the extraction are buffered 100 m and treated
  as hazards, never dropped.
- Users see bands and approximate outlines only; distances and match
  details stay in the internal audit log.
- The README still recommends coordinating with BHMAC before public launch.

## Where documents and code disagree

- **Staleness.** The SPEC (§4, §8) and ADR-001 say data older than
  `staleness_days` fails closed. The README and `BaseCheck` say it does not:
  only missing artifacts block. `Result`'s comment and the
  `staleness_days` comment in `config/mine_checker.yml` still describe the
  old rule. With the 2024-07-31 snapshot past 365 days, the old rule would
  block all BiH content.
- **Storage.** The SPEC's PostGIS table, import task and gems were
  replaced by the static engine. The `Gemfile` still has a comment line
  about PostGIS with no gem under it.
- **Publicity.** ADR-001 says the data is used only internally and that
  Phase 2 requires a signed BHMAC/UNDP agreement, after which the ADR is to
  be replaced. The public check and the game shipped on an owner decision
  instead, recorded in the README, and ADR-001 still reads "accepted"
  unchanged.
