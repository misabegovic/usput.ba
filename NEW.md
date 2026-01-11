# Usput.ba - Plan razvoja

## O projektu

Usput.ba je turistička platforma za Bosnu i Hercegovinu sa AI-generiranim sadržajem. Cilj je pokriti cijelu zemlju sa hiljadama kvalitetnih lokacija, iskustava i planova putovanja na 14 jezika.

### Ciljevi

- Pokrivanje cijele Bosne i Hercegovine
- Hiljade kvalitetnih lokacija i iskustava
- Podrška za sve tipove turista (porodice, parovi, backpackeri, penzioneri...)
- Višejezičnost (14 jezika)
- Audio ture za odabrane lokacije
- Community curation sistem

---

## Pregled trenutnog stanja

- **Lokacije:** 500+ (razna stanja kvalitete)
- **Iskustva:** ~250 (razna stanja kvalitete)
- **Planovi:** 0
- **Audio ture:** 0 (generisanje ne radi ispravno)
- **Fotografije:** Uklonjene (problematični AI rezultati)

### Identificirani problemi sa sadržajem

- Loši/generički opisi
- Iskustva referišu lokacije koje ne postoje u bazi
- Neprimjeren ton (previše pozitivan za teške lokacije)
- Osjetljive teme tretirane olako
- Previše servisa, analyzera, jobova - kompleksnost

---

## 1. Arhiviranje postojećeg sadržaja

Dodati `archived` flag na Location i Experience modele.

- Postojeći sadržaj označiti kao arhiviran
- Explore stranica prikazuje samo `archived: false`
- Admin može vidjeti sve
- Sadržaj se ne briše - možda bude koristan kasnije

---

## 2. Fotografije

### Pristup

Kombinacija ručnog uploada i AI prijedloga sa admin odobrenjem.

### Funkcionalnosti

- Admin može ručno uploadati slike za lokaciju/iskustvo
- Sistem predlaže slike putem Google Custom Search
- Admin pregleda predložene: izabere dobre, odbaci loše
- **Nijedna slika ne ide live bez admin odobrenja**

---

## 3. Generisanje sadržaja - Nova arhitektura

### Filozofija

- AI slobodno rezonuje i dizajnira, bez ograničenja data modela
- Struktura i mapiranje dolaze naknadno
- Hands-off proces sa pravilima definisanim unaprijed

### Format outputa

**Hybrid pristup:**

1. AI razradi koncept i priču (kreativno, originalno)
2. AI strukturira u standardizirani format
3. Mi koristimo podatke za kreiranje modela

### Tok generisanja

```
ISKUSTVO (koncept, narativ)
    ↓
LOKACIJE (izvučene iz iskustva)
    ↓
PLANOVI (kombinacija iskustava)
```

Iskustvo je priča - lokacije su elementi te priče.

### Persona sistem

**Kreatori:**
- Lokalni poznavalac
- Historičar
- Foodie/gastro entuzijast
- Avanturista
- Kulturni vodič
- ...

**Ciljne grupe:**
- Porodica sa djecom
- Par na romantičnom putovanju
- Solo backpacker
- Penzioneri
- Avanturisti
- Biznis putnik
- ...

**Proces:**

- Dinamički odabir persona prema tipu sadržaja
- Real-time feedback tokom kreiranja (persone u dijalogu)
- Više verzija istog iskustva za različite ciljne grupe
- Quality reviewer persona na kraju

**Primjer dijaloga:**

```
Kreator (Lokalni poznavalac):
  "Predlažem iskustvo 'Skriveni dragulji Trebinja' -
   obilazak manastira, vinarije i starog grada..."

Recenzent (Historičar):
  "Dodaj kontekst o Tvrdošu - važan je za razumijevanje
   pravoslavne baštine regije"

Ciljna persona (Porodica sa djecom):
  "Da li ima nešto za djecu? Djeluje previše orijentisano
   na odrasle"

Kreator:
  "OK, dodajem historijski kontekst za Tvrdoš i ubacujem
   posjet pčelinjaku - interaktivno za djecu"

Quality Reviewer:
  "Iskustvo sada ima dobar balans. Odobravamo."

→ FINALNI PRIJEDLOG
```

### Kontekst postojećeg sadržaja

- **pgvector** ekstenzija za PostgreSQL
- Svaki sadržaj ima embedding (vector reprezentaciju)
- Prije generisanja, AI provjerava šta već postoji
- Izbjegava duplikate i slične ideje

### Pravila

Sva pravila u prompt fajlovima:

```
prompts/
  generation_rules.md      # glavna pravila
  sensitive_topics.md      # osjetljive teme - human only
  tone_guidelines.md       # ton za različite tipove lokacija
  personas/
    creators/              # definicije kreator persona
    targets/               # definicije ciljnih grupa
```

### Osjetljive teme

- Definirane u prompt fajlu
- Human-only curation
- AI ih ne dira automatski

### Alat

Ruby skripta u istom projektu:

```
lib/
  content_generation/
    generator.rb        # entry point
    prompts/            # prompt fajlovi
    personas/           # persona definicije
    validators/         # validacija outputa
```

- Koristi postojeći RubyLLM
- Jasno odvojeno od `app/services/ai/` (stari pristup)
- MCP integracija moguća u budućnosti

### Stari kod (`app/services/ai/`)

Postojeći AI servisi ostaju zamrznuti:
- Ne brišemo - možda bude korisno za referencu
- Ne koristimo za novo generisanje
- Novi sistem živi u `lib/content_generation/`
- Vremenom možda ukloniti kada novi sistem bude stabilan

### Validacija

Automatske provjere:

- Da li iskustvo ima logičan tok (AI self-check)
- Da li spominje osjetljive teme → flag za posebnu pažnju
- Da li je ton primjeren tipu sadržaja
- Da li se preklapa sa postojećim (pgvector similarity)
- Da li su sve lokacije interno konzistentne

Rezultat:
- Prošlo sve → spreman za review
- Upozorenja → review sa napomenama
- Osjetljiva tema → human-only, posebna pažnja

### AI Output format

```yaml
iskustvo:
  naziv: "Skriveni dragulji Trebinja"
  narativ: "Putovanje kroz vrijeme i ukuse..."
  trajanje: "4-5 sati"
  sezona: ["proljeće", "ljeto", "jesen"]

  lokacije:
    - naziv: "Manastir Tvrdoš"
      opis: "..."
      zašto_je_tu: "Historijska srž regije"
      tip: historijski
      osjetljivo: false

    - naziv: "Vinarija Tvrdoš"
      opis: "..."
      zašto_je_tu: "Degustacija lokalnih vina"
      tip: gastronomija
```

AI dizajnira kompletno iskustvo sa svim lokacijama. Mi mapiramo na data model.

### Staging sistem

Staging tabele u istoj bazi:

```
staged_experiences
  - id
  - data (JSONB) - kompletan AI output
  - status: pending/approved/rejected
  - created_by_persona
  - reviewed_by_personas
  - quality_score
  - validation_notes
  - created_at

staged_locations
  - id
  - staged_experience_id
  - data (JSONB)
  - matched_location_id (ako postoji match)
  - status
  - created_at
```

### Workflow

```
┌─────────────────────────────────┐
│     STAGING SISTEM              │
├─────────────────────────────────┤
│  1. AI generiše (persone)       │
│  2. Quality reviewer            │
│  3. Automatska validacija       │
│  4. Batch review (admin)        │
│     → odobri/odbij selektivno   │
└───────────────┬─────────────────┘
                │ ODOBRENJE
                ▼
┌─────────────────────────────────┐
│     PRODUKCIJA (draft)          │
├─────────────────────────────────┤
│  - Import + deduplikacija       │
│  - Geoapify koordinate          │
│  - Slike (admin bira)           │
│  - Prijevodi (14 jezika)        │
│  - Audio tura (opcionalno)      │
│  - Finalna provjera             │
└───────────────┬─────────────────┘
                │ PUBLISH
                ▼
┌─────────────────────────────────┐
│     PRODUKCIJA (published)      │
│     Vidljivo na Explore         │
└─────────────────────────────────┘
```

### Status u produkciji

```
experiences.status / locations.status:
  - draft      → uvezeno, priprema u toku
  - ready      → sve kompletno, čeka publish
  - published  → live na Explore
  - archived   → stari sadržaj
```

Explore prikazuje samo `published`.

### Deduplikacija lokacija

Pri importu, za svaku lokaciju:

1. Provjeri ime (fuzzy match)
2. Provjeri pgvector similarity
3. Provjeri koordinate (ako ih ima)

Rezultat:
- Match pronađen → poveži iskustvo sa postojećom lokacijom
- Nema matcha → kreiraj novu lokaciju

Jedna lokacija može biti u više iskustava.

---

## 4. Admin CLI

`bin/admin` skripta sa JSON outputom (AI-friendly).

### Komande

```bash
# Staging review
bin/admin staging list
bin/admin staging show [id]
bin/admin staging approve [id]
bin/admin staging reject [id]
bin/admin staging approve-all

# Produkcija
bin/admin content drafts
bin/admin content show [id]
bin/admin content add-images [id]
bin/admin content translate [id]
bin/admin content audio [id]
bin/admin content publish [id]
bin/admin content publish-ready

# Pregled
bin/admin content status
```

### Format

- JSON output po defaultu (za Claude/AI)
- `--pretty` flag za human-readable output

Pripremljeno za MCP integraciju u budućnosti.

---

## 5. Kurator sistem

### Poboljšanja

- Bolji UX za predlaganje promjena i admin odobrenje
- Sadržaj od kuratora = human made, ne AI generated
- Vidljivi tagovi/oznake: ko je kreator, ko je kurirao sadržaj

### Transparentnost

Korisnici vide:
- Da li je sadržaj AI generisan ili human made
- Ko je autor/kurator sadržaja

---

## 6. Planovi

- Planovi kreirani od korisnika **ne smiju** biti označeni kao AI generated
- AI generirani planovi dolaze kroz novi content generation sistem

---

## 7. Audio ture

### Pristup

- Selektivan proces - ne za sve lokacije
- AI kreira narativ prilagođen audio formatu (priča, ne suhi opis)
- Popraviti trenutno generisanje koje ne radi ispravno

### Pokretanje

- Dio finalne pripreme prije publish
- Admin odlučuje koje lokacije dobijaju audio turu
- Pokreće se kroz CLI: `bin/admin content audio [id]`

---

## 8. Ostala poboljšanja

### SEO
- Meta tagovi
- Strukturirani podaci
- Sitemap
- Treba pažnja

### Mobile
- Responsive dizajn postoji
- Treba poboljšati

### Offline
- PWA funkcionalnost postoji
- Treba poboljšati

### Social sharing
- OG meta tagovi
- Preview-i za dijeljenje
- Treba pažnja

### Mape
- Može kasnije (nije prioritet za lansiranje)

---

## Prioriteti implementacije

### Faza 1: Priprema
- [ ] Arhivirati postojeći sadržaj
- [ ] Dodati status polja (draft/ready/published/archived)
- [ ] Kreirati staging tabele
- [ ] Postaviti pgvector

### Faza 2: Content Generation sistem
- [ ] Struktura `lib/content_generation/`
- [ ] Prompt fajlovi i persona definicije
- [ ] Generator sa persona sistemom
- [ ] Validacija
- [ ] Staging workflow

### Faza 3: Admin CLI
- [ ] `bin/admin` skripta
- [ ] Staging komande
- [ ] Content komande
- [ ] JSON output format

### Faza 4: Fotografije
- [ ] Admin upload funkcionalnost
- [ ] Google suggestions sa odobrenjem
- [ ] UI za izbor/odbijanje slika

### Faza 5: Finalizacija
- [ ] Prijevodi workflow
- [ ] Audio ture (popraviti generisanje)
- [ ] SEO poboljšanja
- [ ] Mobile/Offline poboljšanja
- [ ] Kurator sistem poboljšanja

---

## Napomene

- Nema strogog timelina
- Monetizacija nije prioritet za sada
- MCP integracija za budućnost
- Fokus na kvaliteti sadržaja prije lansiranja
