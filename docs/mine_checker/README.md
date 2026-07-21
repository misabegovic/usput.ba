# Mine Checker — Faza 1 (interni sloj) + Faza 2 (javna provjera)

Interni sigurnosni sloj: svaki geo-sadržaj (Location lat/lng) pri
kreiranju/izmjeni prolazi mine-check protiv minski sumnjivih područja (MSP)
u BiH. Unutar buffera → hard block. Vidi `SPEC.md` (izvor istine) i
`ADR-001-mine-data-source.md`.

## Tvrda pravila
- Nikad "sigurno/safe" — jedini pozitivan ishod je `no_known_intersections`.
- Fail-closed SAMO za nedostajuće podatke: bez artefakata interni check
  blokira sav BiH geo-sadržaj. STAROST podataka ne blokira (odluka
  vlasnika, 2026-07-21 — minska slika se sporo mijenja); svaki odgovor
  nosi datum snimka kao ogradu.
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

Minesweeper igra (`/minesweeper`) — edukativna, sa STVARNIM podacima
(odluka vlasnika, 2026-07-21): tabla je geografska mreža na stvarnim
kartama (zum/pomjeranje slobodni), a mina je svaka ćelija koja se
preklapa sa evidentiranim sumnjivim područjem — isti generalizovani
javni sloj kao overlay na karti provjere, samo downsampliran na ćelije
(dakle bez ijedne nove informacije prema korisniku). Igra se SAMO tamo
gdje podaci nešto bilježe (prazna tabla → edukativna poruka); stranica
nosi puni blok upozorenja (prazna ćelija ≠ siguran teren, snimak 2024,
"nema druge šanse", nije za navigaciju, BHMAC + službena aplikacija).

## Arhitektura: statički engine (bez baze)

Odluka vlasnika (2026-07-21): sva runtime logika radi iz prekompajliranih
artefakata u `db/data/mine_checker/static/` — aplikacija NEMA prostornu
zavisnost (nema PostGIS-a, nema mine_areas tabele). U bazi ostaje samo
`mine_check_audits` (običan Postgres) kao interni zapisnik provjera.

Artefakti:
- `inside.bin.gz` (50 m) — ćelije koje sijeku sumnjivo područje (tabla igre)
- `danger.bin.gz` (100 m) — pojas ≤500 m (interni checker + javni band)
- `caution.bin.gz` (200 m) — pojas ≤2 km
- `overview.json.gz` — tačkice za nacionalni zum
- `tiles/{tx}_{ty}.json.gz` — pojednostavljene granice po 0.25° pločama
- `meta.json` — data_as_of, bbox, dimenzije mreža

Svaka maska se gradi iz geometrija proširenih za band radius PLUS pola
dijagonale ćelije, pa kvantizacija može pojas samo PROŠIRITI, nikad
suziti (konzervativno svojstvo, pokriveno testovima). Bez artefakata sve
pada u fail-closed (`unavailable` / `data_stale`).

Izgradnja artefakata (offline, JEDINO mjesto gdje se koristi PostGIS —
bilo koja privremena instanca, npr. `docker run postgis/postgis`):

```bash
MINE_BUILD_DATABASE_URL=postgres://user:pass@host:port/scratch \
DATA_AS_OF=2024-07-31 \
ruby scripts/mine_checker/build_static_artifacts.rb
```

Verifikacija naspram vektorske istine rađena je 2026-07-21 na 3000
nasumičnih tačaka: 97.5% identičnih pojaseva, SVA neslaganja u smjeru
proširenja pojasa, nula nekonzervativnih; static p50 0.008 ms vs
PostGIS p50 3.3 ms po provjeri.

## Komande

```bash
# Jednokratni audit postojećeg sadržaja (ništa se ne briše)
bin/rails mine_data:audit_existing
```

Seeds validiraju lokacije kroz statički engine; blokirane lokacije se
PRESKAČU uz upozorenje — nikad se ne forsiraju.

## Operativna stvarnost (2026-07-21)

- Vendored snapshot je od **2024-07-31** → stariji od staleness praga
  (365 dana). Provjere NORMALNO rade (starost ne blokira — odluka
  vlasnika); javni checker i igra prikazuju datum snimka i staleness
  ogradu. Blokira jedino potpuno nedostajanje artefakata.
- Refresh: `scripts/mine_checker/scrape_eufor_pdfs.py` + ekstrakcioni
  pipeline (`pdf_to_svg.sh`, `detect_elements.ipynb`), pa
  `build_static_artifacts.rb` s novim `DATA_AS_OF` i commit artefakata.

## Implementacione napomene (odstupanja/preciziranja SPEC-a)

1. **Nezatvoreni ringovi**: dio poligona u izvorniku nema zatvoren ring
   (prva ≠ zadnja tačka) — builder ih zatvara prije `ST_GeomFromText`.
2. **Zero-area poligoni**: 18 poligona sa ≥4 tačke kolabira u liniju/tačku
   nakon `ST_MakeValid` — tretiraju se kao degenerisani (buffer 100 m),
   nikad se ne učitavaju "ravni".
3. **SPEC §8 offshore fixture**: navedena tačka (lon 16.0, lat 42.9) pada
   UNUTAR §4 bbox-a — bbox je autoritet (check se tamo izvršava, što je
   konzervativnije); testovi koriste stvarno-vanjsku tačku (14.5, 42.0).
4. **Testni baseline**: test_helper usmjeri statički engine na sintetičke
   svježe artefakte (`test/support/static_artifacts.rb` — čisti Ruby, bez
   PostGIS-a) da obični testovi mogu kreirati BiH sadržaj pod fail-closed
   režimom; mine testovi instaliraju vlastite sintetičke setove s tačno
   poznatom istinom.

## Struktura

- `app/services/mine_checker/` — Config, Result, StaticIndex, BaseCheck,
  PointCheck, RouteCheck (sve nad statičkim artefaktima)
- `app/models/mine_check_audit.rb` — interni zapisnik (običan Postgres)
- `lib/tasks/mine_audit.rake` — audit_existing
- `scripts/mine_checker/build_static_artifacts.rb` — offline builder
  (jedino mjesto s PostGIS-om)
- `config/mine_checker.yml` — buffer_m / staleness_days / bih_bbox (nikad u kodu)
- `db/data/mine_checker/` — GeoJSON snapshot (izvor) + `static/` artefakti
- Hook: `Location#must_pass_mine_check` (poruke bez geometrije; detalji u
  `mine_check_audits`)
