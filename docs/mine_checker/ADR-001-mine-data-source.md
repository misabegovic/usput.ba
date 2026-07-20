# ADR-001: Izvor podataka o minski sumnjivim područjima za Mine Checker

- Status: accepted
- Datum: 2026-07-20
- Odlučuje: Muhamed
- Tehnički kontekst: Usput.ba (Rails 8, PostGIS)

## Kontekst i problem

Usput.ba mora spriječiti kreiranje geo-sadržaja u blizini minski sumnjivih
područja (MSP) u BiH. BHMAC vodi autoritativnu, dnevno ažuriranu bazu, ali
ne objavljuje javni WMS/WFS/GeoJSON servis. Potreban je izvor podataka za
Fazu 1 (interni check) koji ne blokira razvoj dok traju pregovori s
BHMAC/UNDP o zvaničnom feedu.

## Razmotrene opcije

1. **EUFOR MICC PDF karte → vektorska ekstrakcija** (Henning-arround/BiH_mines
   pipeline; javno objavljeno, BHMAC podaci, cijela BiH, 80 JOG listova)
2. **Čekati zvanični BHMAC/UNDP sporazum** prije bilo kakvog koda
3. **Reverse-engineering backenda mobilne aplikacije "BH Mine Suspected
   Areas"** (nedokumentovan API)
4. **DRAS (drasinfo.org) tile slojevi** (UNDP, samo odabrane općine)

## Odluka

**Opcija 1** za Fazu 1, uz eksplicitan plan migracije na zvanični BHMAC feed
(Faza 2) i uz sljedeće ugrađene mjere:
- podaci se koriste isključivo interno (nikad prikaz korisnicima),
- svaki rezultat nosi `data_as_of`, staleness → fail-closed,
- buffer 500 m kompenzuje preciznost izvora (1:50.000) i GPS grešku,
- degenerisane geometrije iz ekstrakcije tretiraju se kao opasnost
  (bufferuju se), ne odbacuju.

## Obrazloženje

- Op. 2 znači da platforma do daljnjeg nema nikakvu zaštitu — gore od
  konzervativnog snapshota. Radni sistem je ujedno i jači pregovarački
  argument prema BHMAC/UNDP ("uključite svjež feed u postojeći sistem").
- Op. 3 je pravno i etički neprihvatljiva (nedokumentovan API, licenca) i
  krhka.
- Op. 4 pokriva samo dio općina i također nema dokumentovan servis.
- Op. 1 koristi javno objavljene karte (EUFOR ih objavljuje upravo radi
  sigurnosti javnosti), s BHMAC-om kao imenovanim izvorom, i ima
  reproducibilan open-source pipeline za refresh.

## Posljedice

- (+) Odmah funkcionalan interni safety sloj; demo za BHMAC/UNDP pitch.
- (−) Snapshot zastarijeva → obavezan refresh proces
  (`scripts/scrape_eufor_pdfs.py` + ekstrakcija) i tvrdi staleness prag.
- (−) Pozicijska preciznost diktira velik buffer → više false positives;
  prihvaćeno kao asimetrični trade-off.
- (→) Faza 2 (javni route-check API, prikazi) uslovljena je isključivo
  potpisanim sporazumom s BHMAC/UNDP; ovaj ADR se tada zamjenjuje novim.
