# ADR: Implementation Decisions

**Datum:** 2025-01-15
**Status:** Accepted
**Učesnici:** PM, Tech Lead, Product Owner

---

## Kontekst

Prije početka implementacije, definisali smo tehničke i product odluke kroz Q&A sesiju.

---

## Odluke

### 1. DSL Parser: Parslet

**Odluka:** Koristimo Parslet gem za parsing DSL-a.

**Razlog:**
- Pure Ruby, lakše debugovanje
- Nema dodatnih fajlova (.treetop)
- Fleksibilnije za iterativni razvoj
- DSL gramatika nije toliko kompleksna da bi Treetop performanse bile presudne

**Alternative razmatrane:** Treetop (PEG parser)

---

### 2. Embedding Model: OpenAI ada-002

**Odluka:** Koristimo OpenAI text-embedding-ada-002 za Layer 2 cluster embeddings.

**Razlog:**
- Provjereno radi
- Jednostavna integracija
- Troškovi minimalni (~$0.10 za 1M tokena)
- Možemo migrirati na self-hosted kasnije ako troškovi postanu problem

**Alternative razmatrane:** Voyage AI multilingual, self-hosted sentence-transformers

---

### 3. Summary Refresh: On-demand + Cache

**Odluka:** Layer 1 summaries se generišu on-demand i cache-iraju.

**Razlog:**
- Ne znamo unaprijed koji summaries će biti najkorisniji
- Platform sam odlučuje šta mu treba
- Lazy approach - ne generišemo dok ne treba
- Kasnije možemo dodati scheduled refresh za popularne

**Alternative razmatrane:** Svakih sat vremena, svakih 24h, hybrid

---

### 4. DSL Jezik: Engleski DSL, Bosanska komunikacija

**Odluka:** DSL syntax je na engleskom, ali Platform komunicira sa adminom na bosanskom.

**Primjer:**
```
[Interno] locations { city: "Mostar" } | aggregate count() by type
[Output]  "Imam 47 lokacija u Mostaru, od toga 12 restorana..."
```

**Razlog:**
- DSL je tehnički alat, admin ga ne mora čitati direktno
- Engleski DSL = standardno, lakše održavanje
- Platform prevodi rezultate u prirodan jezik

---

### 5. Error Handling: User-friendly + Tehnički na zahtjev

**Odluka:** Platform prikazuje user-friendly greške po default-u, tehnički detalji dostupni na zahtjev.

**Primjer:**
```
Platform: Nisam pronašla grad "Mostr". Da li si mislio "Mostar"?

Admin: Daj mi tehničke detalje

Platform: [prikaže tehnički error sa DSL query, pozicijom greške, itd.]
```

**Razlog:** Best of both worlds - admin razumije šta se desilo, a tehnički detalji su dostupni za debugging.

---

### 6. Rollback Strategija: Partial Commit + Izvještaj

**Odluka:** Batch operacije koriste partial commit - uspješne operacije se sačuvaju, neuspješne se prijave.

**Primjer:**
```
Platform: Djelimično uspješno!
  ✅ 15 lokacija kreirano
  ❌ 15 lokacija nije uspjelo

  Problemi:
  - #16: Duplikat koordinata
  - #17-30: Geoapify rate limit

  Želiš li da nastavim sa neuspjelima?
```

**Razlog:** Za content generation, bolje je sačuvati 15 dobrih lokacija nego izgubiti sve zbog jedne greške.

---

### 7. Testiranje: Unit + Integration, Fixtures za CI

**Odluka:**
- Pišemo i unit i integration testove
- Fixtures (fake data) za CI
- Produkcijski dump opcionalno za lokalni development

**Razlog:** Unit testovi za brzi feedback, integration testovi za sigurnost end-to-end flow-a.

---

## Posljedice

- Developer ima jasne smjernice za implementaciju
- Konzistentnost kroz cijeli Platform
- Dokumentovano za buduće reference
