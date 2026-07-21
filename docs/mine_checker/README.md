# Mine Checker — Faza 1 (interni sloj) + Faza 2 (javna provjera)

Interni sigurnosni sloj: svaki geo-sadržaj (Location lat/lng) pri
kreiranju/izmjeni prolazi mine-check protiv minski sumnjivih područja (MSP)
u BiH. Unutar buffera → hard block. Vidi `SPEC.md` (izvor istine) i
`ADR-001-mine-data-source.md`.

## Tvrda pravila
- Nikad "sigurno/safe" — jedini pozitivan ishod je `no_known_intersections`.
- Fail-closed: bez podataka ili sa zastarjelim podacima interni check blokira
  sav BiH geo-sadržaj.
- Cleared/lifted slojevi nikad ne ublažavaju verdict.
- Geometrija i udaljenosti NIKAD ne izlaze prema korisnicima — samo grubi
  pojasevi (bands); detalji ostaju u internom audit logu.

## Faza 2 — javna provjera (odluka vlasnika, 2026-07-21)

Vlasnik je 2026-07-21 odobrio javnu provjeru blizine (`/mine-check`),
čime je zamijenjeno prvobitno pravilo "nema javnih ruta u Fazi 1".
Fail-safe svojstva javne provjere:

- Odgovori su isključivo pojasevi: `danger` (≤500 m ili unutra), `caution`
  (500 m – 2 km), `no_known` (uz datum podataka i "nije garancija"),
  `out_of_coverage`, `unavailable`. Bez udaljenosti, bez geometrije.
- Upozorenja (`danger`/`caution`) se prikazuju bez obzira na starost
  podataka — staleness samo dodaje upozorenja, nikad ih ne potiskuje.
- Bez podataka → `unavailable` (fail-closed) + upućivanje na BHMAC.
- Stranica nosi trajni blok upozorenja (datum snimka, "nije garancija",
  "nije za navigaciju", BHMAC/122/121, službena aplikacija).
- Rate limit: 30 provjera/min po IP (rack-attack) — otežava i pokušaje
  rekonstrukcije granica područja skeniranjem.
- Svaka provjera se auditira (`content_type: PublicMineCheck`).
- Vizuelni prikaz (odluka vlasnika, 2026-07-21): karta provjere prikazuje
  POJEDNOSTAVLJENE (generalizovane ~40 m) granice sumnjivih područja za
  trenutni viewport, uz legendu koja naglašava da su granice PRIBLIŽNE i
  da se opasnost može protezati izvan prikazanih oblika. Metapodaci
  (fileId itd.) se ne šalju; viewport je ograničen (max ~4°×3°), broj
  oblika ograničen (800), endpoint keširan i rate-limitovan (60/min/IP).
- **Preporuka ostaje**: prije javnog lansiranja koordinirati s BHMAC-om
  (vidi ADR-001); ovaj zapis dokumentira svjesnu odluku vlasnika.

Minolovac (`/minolovac`) i dalje koristi ISKLJUČIVO izmišljene mine;
stvarni podaci ulaze samo kao grubi agregati (km² po regiji, odnosno
jedan 5 km agregat za "custom" tačku) za skaliranje težine i edukativne
činjenice.

## Komande

```bash
# Import (obavezan DATA_AS_OF; datum vendored snapshota je u
# db/data/mine_checker/DATA_AS_OF)
bin/rails mine_data:import DATA_AS_OF=2024-07-31

# Jednokratni audit postojećeg sadržaja (ništa se ne briše)
bin/rails mine_data:audit_existing
```

`db:seed` sam pokreće import (čita DATA_AS_OF marker) prije lokacija;
lokacije koje check blokira seed PRESKAČE uz upozorenje — nikad ne zaobilazi.

## Operativna stvarnost (2026-07-20)

- Vendored snapshot je od **2024-07-31** → stariji od staleness praga
  (365 dana) → **checker trenutno FAIL-CLOSED blokira sav BiH geo-sadržaj**
  dok se ne importuju svježiji podaci. To je namjerno ponašanje.
- Refresh: `scripts/mine_checker/scrape_eufor_pdfs.py` + ekstrakcioni
  pipeline (`pdf_to_svg.sh`, `detect_elements.ipynb`), pa `mine_data:import`
  s novim `DATA_AS_OF`.

## Implementacione napomene (odstupanja/preciziranja SPEC-a)

1. **Nezatvoreni ringovi**: dio poligona u izvorniku nema zatvoren ring
   (prva ≠ zadnja tačka) — import ih zatvara prije `ST_GeomFromText`.
2. **Zero-area poligoni**: 18 poligona sa ≥4 tačke kolabira u liniju/tačku
   nakon `ST_MakeValid` — tretiraju se kao degenerisani (buffer 100 m),
   nikad se ne importuju "ravni".
3. **SPEC §8 offshore fixture**: navedena tačka (lon 16.0, lat 42.9) pada
   UNUTAR §4 bbox-a — bbox je autoritet (check se tamo izvršava, što je
   konzervativnije); testovi koriste stvarno-vanjsku tačku (14.5, 42.0).
4. **Testni baseline**: test_helper prije svakog testa instalira mini svježi
   suspected poligon u SW uglu bbox-a da obični testovi mogu kreirati BiH
   sadržaj pod fail-closed režimom; mine-checker testovi ga pregaze svojim
   fixture-ima izvedenim iz stvarnog dataseta.

## Struktura

- `app/services/mine_checker/` — Config, Result, BaseCheck, PointCheck, RouteCheck
- `app/models/mine_area.rb`, `app/models/mine_check_audit.rb`
- `lib/tasks/mine_data.rake` — import + audit_existing
- `config/mine_checker.yml` — buffer_m / staleness_days / bih_bbox (nikad u kodu)
- `db/data/mine_checker/` — GeoJSON snapshot + DATA_AS_OF marker
- Hook: `Location#must_pass_mine_check` (poruke bez geometrije; detalji u
  `mine_check_audits`)
