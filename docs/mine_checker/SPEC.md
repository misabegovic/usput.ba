# SPEC: Mine Checker za Usput.ba — Faza 1 (interni sloj)

Status: ready for implementation · Vlasnik: Muhamed · Datum: 2026-07-20

## 1. Problem i cilj

BiH ima ~820 km² minski sumnjive površine (MSP). Usput.ba vodi korisnike na
teren (POI, treasure hunt zadaci, rute), pa platforma mora garantovati da
nikad ne postavi sadržaj u blizini MSP-a. Faza 1 je **isključivo interni
mehanizam**: svaki geo-sadržaj pri kreiranju/izmjeni prolazi mine-check;
unutar buffera → hard block.

**Van scope-a (Faza 2, tek nakon sporazuma s BHMAC/UNDP):** javni route-check
API, tile sloj, bilo kakav prikaz minskih podataka korisnicima.

## 2. Izvor podataka i njegova ograničenja

Dataset u `data/` je izveden iz EUFOR MICC "Mine Contamination Maps"
(BHMAC podaci, JOG listovi 1:50.000) kroz open-source pipeline
Henning-arround/BiH_mines (PDF → Inkscape SVG → vektorska ekstrakcija).

| Fajl | Sadržaj | Broj | Geometrija |
|---|---|---|---|
| `suspect_areas_original.geojson` | Suspected Minefield poligoni | 11.068 | Polygon, WGS84 |
| `cleared_areas_original.geojson` | Očišćena područja | 8.329 | Polygon |
| `lifted_minefields.geojson` | Uklonjena minska polja | 925 | Point |
| `incidents.geojson` | Minski incidenti | 1.442 | Point |

Properties: `typeArea` (string), `fileId` (JOG list, npr. `2585-III`).

**Kritična ograničenja — moraju biti kodirana, ne samo dokumentovana:**
- `data_as_of = 2024-07-31` (datum ekstrakcije iz repoa). EUFOR stranica je
  u međuvremenu osvježena (jun 2025); refresh = `scripts/scrape_eufor_pdfs.py`
  + ponovni run ekstrakcije. Import task MORA primati `DATA_AS_OF` env var
  i odbiti import bez njega.
- Ovo su periodični snapshotovi, ne živa BHMAC baza. BHMAC upozorava da su
  mape podložne dnevnim promjenama.
- Ekstrakcija iz SVG-a nosi artefakte: **3.076/11.068 suspect poligona ima
  degenerisan ring (<4 tačke)** — vidi §3.
- Preciznost izvora je 1:50.000 karta → pozicijska greška realno 25–100 m.
  Ovo je dio opravdanja za veliki default buffer (§4).

## 3. Import pipeline

Rake task `mine_data:import` (idempotentan, truncate+reload u transakciji):

1. Parsiraj GeoJSON (RGeo + rgeo-geojson).
2. **Čišćenje degenerisanih geometrija — obavezno i konzervativno:**
   - Ring s ≥4 tačke → import kao poligon, pa `ST_MakeValid`.
   - Ring s 1–3 tačke → NE odbacuj (fail-closed!): konvertuj u point/linestring
     i primijeni `ST_Buffer(geom::geography, 100)` da postane površina.
     Artefakt vjerovatno predstavlja stvaran objekt s karte koji je
     ekstrakcija osakatila — tretiraj ga kao opasnost, ne kao šum.
   - Loguj broj svake kategorije u output taska.
3. Snimi u `mine_areas` sa `source='eufor_micc_extract'`,
   `data_as_of=ENV['DATA_AS_OF']`, `imported_at=Time.current`.
4. Post-import sanity check (task faila ako ne prođe):
   - count(kind='suspected') ≥ 10.000
   - bounding box svih geometrija unutar lon 15.5–19.7, lat 42.4–45.4
   - 0 nevalidnih geometrija (`ST_IsValid`)

## 4. Model podataka

```ruby
create_table :mine_areas do |t|
  t.string  :kind, null: false   # suspected | cleared | lifted | incident
  t.geography :geom, limit: { srid: 4326, type: "geometry" }, null: false
  t.string  :source, null: false
  t.string  :file_id             # JOG sheet, npr. "2585-III"
  t.date    :data_as_of, null: false
  t.datetime :imported_at, null: false
  t.timestamps
end
add_index :mine_areas, :geom, using: :gist
add_index :mine_areas, :kind
```

Gemovi: `activerecord-postgis-adapter`, `rgeo`, `rgeo-geojson`.
`geography` (ne `geometry`) da `ST_DWithin` radi u metrima bez reprojekcija.

Konfiguracija (`config/mine_checker.yml` + Rails credentials override):

```yaml
buffer_m: 500            # udaljenost od suspected area koja blokira
staleness_days: 365      # nakon ovoga: fail-closed
bih_bbox: [15.5, 42.4, 19.7, 45.4]  # checkovi se rade samo unutar BiH
```

Buffer 500 m = pozicijska greška karte + GPS greška uređaja + margina.
Smanjivanje ispod 300 m zahtijeva BHMAC-kvalitet podataka (Faza 2).

## 5. Servisni sloj

`app/services/mine_checker/` — čisti PORO servisi, bez controller logike.

```ruby
result = MineChecker::PointCheck.call(lat:, lon:)
result = MineChecker::RouteCheck.call(points: [[lat, lon], ...])
```

`Result` (immutable Struct):
- `verdict` — jedan od:
  - `:blocked` — presjeca ili je unutar buffera bar jednog suspected područja
  - `:no_known_intersections` — nema poznatih presjeka (NIKAD ne imenovati
    "safe" u kodu, testovima ni docs)
  - `:data_stale` — podaci stariji od `staleness_days` → tretirati kao block
  - `:out_of_coverage` — tačka van BiH bbox-a → check se preskače (Usput.ba
    sadržaj van BiH ne prolazi mine-check)
- `matches` — [{kind:, file_id:, distance_m:}] za blocked (interno, za admin log)
- `data_as_of` — Date, uvijek prisutan
- `checked_at` — Time

SQL srž (RouteCheck gradi LineString od tačaka pa isto):

```sql
SELECT id, kind, file_id,
       ST_Distance(geom, :point::geography) AS distance_m
FROM mine_areas
WHERE kind = 'suspected'
  AND ST_DWithin(geom, :point::geography, :buffer_m)
ORDER BY distance_m ASC
```

`cleared`/`lifted`/`incident` slojevi se NE koriste u verdictu Faze 1 —
importuju se radi Faze 2 i admin uvida, ništa više.

## 6. Integracione tačke u Usput.ba

Hook = model validacija + service call, na svakom modelu koji nosi
koordinate koje vode korisnika na fizičku lokaciju (POI, hunt zadatak,
checkpoint, ruta). Pronađi ih u repou; očekivani obrazac:

```ruby
validate :must_pass_mine_check, if: :coordinates_changed?

def must_pass_mine_check
  result = MineChecker::PointCheck.call(lat: latitude, lon: longitude)
  case result.verdict
  when :blocked
    errors.add(:base, :mine_check_blocked)   # bez detalja geometrije u poruci
  when :data_stale
    errors.add(:base, :mine_check_data_stale)
  end
end
```

- Poruka korisniku/adminu NE otkriva geometriju ni udaljenost — samo da
  lokacija ne može biti prihvaćena iz sigurnosnih razloga i da se za
  informacije o minskoj situaciji kontaktira BHMAC (033/253-800).
- `matches` detalji idu isključivo u interni audit log
  (`MineCheckAudit` tabela: content_type, content_id, verdict, matches jsonb,
  data_as_of, created_at). Svaki check se loguje, i blocked i prošli.
- Postojeći sadržaj: jednokratni backfill task `mine_data:audit_existing`
  koji provuče sve postojeće geo-sadržaje i izlista pogotke (bez auto-brisanja
  — lista ide Muhamedu na review).

## 7. Obavezni tekstualni paket

i18n ključevi (bs + en), koristiti doslovno ovaj smisao:

- `mine_check.disclaimer`: "Provjera se vrši prema posljednje dostupnim
  podacima o minski sumnjivim područjima ({data_as_of}). Odsustvo poznatih
  presjeka NIJE garancija da je područje bez mina. Za ažurne informacije
  obratite se BHMAC-u: 033/253-800."
- `mine_check.blocked`: "Lokacija ne može biti prihvaćena iz sigurnosnih
  razloga (blizina minski sumnjivog područja prema podacima od {data_as_of})."
- `mine_check.emergency`: "Policija 122 · Civilna zaštita 121 · BHMAC 033/253-800"

Disclaimer se prikazuje adminima uz svaki rezultat checka.

## 8. Testovi

Fixtures izvedi programski iz dataseta pri test setupu (ne hardkodiraj
geometrije u testove — dataset se mijenja pri refreshu):

1. Odaberi suspected poligon s ≥20 tačaka (npr. `fileId=2585-III`, centroid
   ~lon 17.0361, lat 45.2207), verifikuj `ST_Contains` pa koristi kao
   "inside" fixture.
2. "Near" fixture: tačka na ~300 m od ruba tog poligona (unutar buffera).
3. "Clear" fixture: tačka u Jadranskom moru (lon 16.0, lat 42.9) →
   `:out_of_coverage`; i tačka u BiH verifikovano >2 km od svih suspected
   geometrija → `:no_known_intersections`.

Obavezni slučajevi:
- inside → `:blocked`; near (unutar buffera) → `:blocked`;
  clear u BiH → `:no_known_intersections`; van BiH → `:out_of_coverage`
- RouteCheck: ruta čiji segment prolazi kroz buffer iako su obje krajnje
  tačke čiste → `:blocked` (presjek segmenta, ne samo vertexa!)
- staleness: `travel_to(data_as_of + staleness_days + 1.day)` → `:data_stale`
- degenerisan ring iz §3 → nakon importa postoji kao površina i blokira
- import bez `DATA_AS_OF` env → task faila
- model validacija: kreiranje POI-a na inside fixtureu → invalid record
- svaki check upisuje `MineCheckAudit` red

## 9. Šta NE raditi

- Ne dodavati javne rute/endpointe za minske podatke.
- Ne keširati verdicte po koordinati bez `data_as_of` u ključu.
- Ne "optimizovati" tako da se degenerisane geometrije odbace.
- Ne koristiti cleared slojeve za bilo kakvo ublažavanje verdicta.
- Ne mijenjati buffer ili staleness prag u kodu — samo kroz config.
