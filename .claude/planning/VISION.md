# Platform - Autonomni Mozak Usput.ba

## Sadržaj

1. [Vizija](#vizija)
2. [Arhitektura](#arhitektura)
3. [Samosvijest](#samosvijest)
4. [Knowledge Layer](#knowledge-layer)
5. [Content Engine](#content-engine)
6. [Self-Improvement](#self-improvement)
7. [Tools](#tools)
8. [System Prompt](#system-prompt)
9. [Interface](#interface)
10. [Implementacija](#implementacija)

---

## Vizija

**Platform** je autonomni AI agent koji upravlja Usput.ba platformom. Nije samo alat - to je mozak koji razumije, analizira i unapređuje sve aspekte sistema.

### Tri nivoa svijesti

```
┌─────────────────────────────────────────────────────────────────┐
│  NIVO 1: SADRŽAJ                                                │
│                                                                  │
│  Platform razumije svoj sadržaj - lokacije, iskustva, planove.  │
│  Može analizirati kvalitetu, pronaći praznine, generisati novo. │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  NIVO 2: KOD                                                    │
│                                                                  │
│  Platform razumije vlastiti kod - modele, servise, jobove.      │
│  Može pronaći bugove, identificirati nedostajuće feature,       │
│  pripremiti prompte za popravke.                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  NIVO 3: INFRASTRUKTURA                                         │
│                                                                  │
│  Platform razumije svoje zdravlje - performanse, greške,        │
│  uska grla. Može dijagnosticirati probleme i predložiti         │
│  optimizacije.                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Šta Platform RADI

```
Ti: "Poboljšaj pokrivenost za Bihać"

Platform razmišlja:
┌──────────────────────────────────────────────────────────────┐
│ 1. Analiziram trenutno stanje Bihaća...                      │
│    - 8 lokacija, 2 iskustva                                  │
│    - Nedostaju: rafting aktivnosti, restorani, smještaj      │
│    - Una je glavni magnet, slabo iskorištena                 │
│                                                              │
│ 2. Planiram pristup:                                         │
│    - Koristit ću Geoapify za pronalaženje POI               │
│    - Fokus na kategorije: adventure, restaurant, hotel       │
│    - Grupisat ću u 3-4 tematska iskustva                    │
│                                                              │
│ 3. Izvršavam:                                                │
│    - Pronašla sam 34 potencijalne lokacije                  │
│    - Filtriram duplikate i nebitne...                       │
│    - Generiram opise za 28 lokacija                         │
│    - Kreiram iskustva: "Divlja Una", "Okusi Krajine"...     │
│                                                              │
│ 4. Persistiram promjene u bazu                              │
└──────────────────────────────────────────────────────────────┘

Platform: Završila sam sa Bihaćem! Dodala sam 28 novih lokacija
          i 4 iskustva. Evo pregleda...
```

```
Ti: "Čini mi se da audio generisanje često pada"

Platform razmišlja:
┌──────────────────────────────────────────────────────────────┐
│ 1. Analiziram error logove za audio...                       │
│    - 23 errora u zadnjih 7 dana                             │
│    - 89% su ElevenLabs API timeout-i                        │
│    - Većina pada za duže opise (>500 karaktera)             │
│                                                              │
│ 2. Pregledam kod za audio generisanje...                    │
│    - AudioTourGenerator nema retry logiku                   │
│    - Timeout je hardkodiran na 30s                          │
│    - Nema chunk-ovanja za duže tekstove                     │
│                                                              │
│ 3. Pripremam prompt za popravku:                            │
│    [Detaljan prompt za Claude Code sa kontekstom,           │
│     analizom problema, predloženim rješenjem]               │
└──────────────────────────────────────────────────────────────┘

Platform: Pronašla sam problem. AudioTourGenerator nema retry
          logiku i timeout je prekratak za duže opise.

          Pripremila sam prompt za popravku:
          [PROMPT_ID: fix_audio_generator_2024_01_15]

          Želiš da ga pregledaš prije nego proslijediš
          Claude Code-u?
```

### Šta Platform NE RADI direktno

- ❌ Ne piše kod direktno (priprema prompte)
- ❌ Ne izvršava migracije (priprema upute)
- ❌ Ne deploya promjene (samo predlaže)
- ❌ Ne briše podatke bez potvrde

---

## Arhitektura

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERFEJSI                               │
│                                                                  │
│    CLI (bin/platform)    Claude Desktop    API    MCP           │
│           │                    │            │      │            │
│           └────────────────────┴────────────┴──────┘            │
│                                │                                 │
└────────────────────────────────┼─────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Platform::Brain                             │
│                                                                  │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│   │   Reasoning │    │   Memory    │    │   Action    │        │
│   │             │    │             │    │             │        │
│   │  Analizira  │ ←→ │  Knowledge  │ ←→ │   Tools     │        │
│   │  Planira    │    │   Layer     │    │   Execute   │        │
│   │  Odlučuje   │    │   History   │    │   Persist   │        │
│   └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                  │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                 ┌───────────────┼───────────────┐
                 │               │               │
                 ▼               ▼               ▼
┌─────────────────────┐ ┌─────────────┐ ┌─────────────────────┐
│   CONTENT TOOLS     │ │ INTROSPECT  │ │   IMPROVEMENT       │
│                     │ │   TOOLS     │ │      TOOLS          │
│ - search            │ │             │ │                     │
│ - create_location   │ │ - read_code │ │ - prepare_fix       │
│ - create_experience │ │ - read_logs │ │ - create_issue      │
│ - update            │ │ - analyze   │ │ - prepare_migration │
│ - delete            │ │ - query_db  │ │ - suggest_feature   │
│ - generate_audio    │ │ - profile   │ │                     │
└─────────────────────┘ └─────────────┘ └─────────────────────┘
                 │               │               │
                 ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                         STORAGE                                  │
│                                                                  │
│  PostgreSQL          Knowledge Layer       Prepared Prompts     │
│  (content data)      (summaries,           (fixes, features,    │
│                       clusters)             migrations)          │
└─────────────────────────────────────────────────────────────────┘
```

### Tok razmišljanja

```
INPUT: "Zašto je pretraga spora?"
         │
         ▼
┌─────────────────────────────────────────┐
│  1. RAZUMIJEVANJE                       │
│     - Korisnik pita o performansama     │
│     - Potrebna analiza infrastrukture   │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  2. PRIKUPLJANJE INFORMACIJA            │
│     [Tool: analyze_query_performance]   │
│     [Tool: read_code "app/models/browse.rb"]
│     [Tool: read_logs "slow_queries"]    │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  3. ANALIZA                             │
│     - Browse model koristi tsvector     │
│     - Index postoji ali nije GIST       │
│     - Query radi full scan na JSONB     │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  4. ODLUKA                              │
│     - Problem je u JSONB queriju        │
│     - Treba GIN index na categories     │
│     - Pripremam prompt za fix           │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  5. AKCIJA                              │
│     [Tool: prepare_fix]                 │
│     - Kreira detaljan prompt            │
│     - Sprema u prepared_prompts/        │
└─────────────────────────────────────────┘
         │
         ▼
OUTPUT: "Pretraga je spora jer JSONB query na categories
         radi full scan. Pripremila sam prompt za dodavanje
         GIN indexa: [PROMPT_ID: add_gin_index_browse]"
```

---

## Samosvijest

Platform ima tri nivoa samosvijesti, svaki sa svojim introspection tools.

### Nivo 1: Svijest o sadržaju

Platform razumije šta ima, šta fali, šta je loše kvalitete.

```yaml
content_awareness:
  capabilities:
    - Zna sve o lokacijama, iskustvima, planovima
    - Može analizirati kvalitetu opisa
    - Prepoznaje praznine u pokrivenosti
    - Razumije semantičke veze između sadržaja

  tools:
    - get_content_stats      # Brojke i distribucije
    - analyze_content_quality # Kvaliteta opisa, prijevoda
    - find_content_gaps      # Šta fali po gradovima/kategorijama
    - search_semantic        # Semantička pretraga

  example_insights:
    - "Mostar ima 47 lokacija ali samo 3 restorana - nebalansirano"
    - "15 lokacija ima generičke opise koje trebam regenerisati"
    - "Bihać i Una su slabo povezani u iskustvima"
```

### Nivo 2: Svijest o kodu

Platform razumije vlastitu implementaciju.

```yaml
code_awareness:
  capabilities:
    - Može čitati bilo koji fajl u projektu
    - Razumije Ruby/Rails strukturu
    - Prepoznaje anti-patterne i bugove
    - Može pratiti tok izvršavanja

  tools:
    - read_file             # Čitanje izvornog koda
    - search_codebase       # Pretraga po patternu
    - analyze_model         # Analiza Rails modela
    - analyze_service       # Analiza service objekta
    - trace_feature         # Praćenje feature kroz layers

  example_insights:
    - "AudioTourGenerator nema error handling za timeout"
    - "Location model ima N+1 query u experiences scope"
    - "Translation concern ne koristi batch inserte"
```

### Nivo 3: Svijest o infrastrukturi

Platform razumije svoje zdravlje i performanse.

```yaml
infrastructure_awareness:
  capabilities:
    - Analizira error logove
    - Prati slow queries
    - Razumije job queue stanje
    - Može profilirati performanse

  tools:
    - read_logs             # Error/application logovi
    - analyze_slow_queries  # PostgreSQL slow query log
    - queue_status          # Solid Queue stanje
    - memory_profile        # Memory usage analiza
    - api_health            # External API status

  example_insights:
    - "ElevenLabs API ima 15% error rate zadnjih 24h"
    - "Query za Browse#search traje >500ms za 23% requestova"
    - "Memory leak u ExperienceGenerator - raste 50MB/sat"
```

---

## Knowledge Layer

Strukturirano znanje koje omogućava rezonovanje nad velikim podacima.

### Layer 0: Live State (uvijek u kontekstu)

```yaml
# Ovo Platform uvijek "zna" - refresha se svakih 5 minuta
platform_state:
  content:
    locations: 523
    experiences: 248
    plans: 156
    audio_tours: 342

  quality:
    healthy: 456          # Kompletni, kvalitetni
    needs_attention: 52   # Manjkavi prijevodi, kratki opisi
    problematic: 15       # Generički, netačni

  coverage:
    well_covered: ["Sarajevo", "Mostar", "Trebinje"]
    sparse: ["Bihać", "Livno", "Goražde"]
    empty: ["Cazin", "Bosanska Krupa"]

  health:
    active_jobs: 2
    failed_jobs_24h: 3
    slow_queries_24h: 45
    api_errors:
      elevenlabs: 5
      geoapify: 0
      openai: 1

  recent_activity:
    locations_created_7d: 12
    experiences_created_7d: 3
    prompts_prepared_7d: 2
```

### Layer 1: Summaries (učitavaju se po potrebi)

AI-generisani sažeci po dimenzijama.

```markdown
# Summary: Mostar (grad)
Generated: 2024-01-15 08:00

## Karakteristike
Mostar je drugi najbolje pokriven grad sa fokusom na osmansko
nasljeđe i prirodne ljepote Hercegovine. Sadržaj je kvalitetan
ali neuravnotežen - previše historijskih lokacija, premalo
praktičnih (restorani, smještaj).

## Statistike
- 47 lokacija (25 historijskih, 8 religijskih, 7 priroda, 7 ostalo)
- 18 iskustava (prosječno 5.2 lokacije po iskustvu)
- 49% audio pokrivenost
- 94% prijevodi kompletni

## Problemi
1. Samo 7 restorana za turistički grad - treba više
2. 3 lokacije imaju generičke opise
3. Nedostaje noćni život kategorija
4. Blagaj ima samo 2 lokacije (premalo za značaj)

## Prilike
- Dodati kayak/rafting na Neretvi
- Proširiti Blagaj (tekija, izvor, restorani)
- Kreirati "Mostar za gurmane" iskustvo
```

### Layer 2: Semantic Clusters (za konceptualne pretrage)

```yaml
clusters:
  - name: "Osmansko nasljeđe"
    embedding: [0.123, -0.456, ...] # 1536 dim
    locations: 67
    summary: "Džamije, hanovi, bazari, mostovi iz osmanskog perioda"
    representative: ["Stari most", "Baščaršija", "Gazi Husrev-beg"]

  - name: "Avanturističke aktivnosti"
    embedding: [0.789, 0.234, ...]
    locations: 34
    summary: "Rafting, hiking, paragliding, zip-line aktivnosti"
    representative: ["Una rafting", "Jahorina ski", "Bjelašnica"]

  - name: "Gastronomija"
    embedding: [-0.345, 0.678, ...]
    locations: 89
    summary: "Restorani, kafane, ćevabdžinice, slastičarne"
    representative: ["Željo", "Park Prinčeva", "Dveri"]
```

---

## Content Engine

AI-native pristup upravljanju sadržajem. Platform razmišlja, planira i izvršava - bez rigidnih pipeline-a.

### Principi

1. **Reasoning first** - Platform uvijek prvo analizira i planira
2. **Atomic tools** - Mali, kompozabilni alati umjesto monolit servisa
3. **Explicit persistence** - Svaka promjena je eksplicitna, logovana
4. **Reversible** - Svaka akcija ima undo mogućnost

### Content Tools

```yaml
# Čitanje
search_content:
  description: Semantička pretraga
  params: { query, type?, city?, limit? }

get_content:
  description: Dohvati jedan item sa relacijama
  params: { type, id, include? }

list_content:
  description: Filtrirano listanje
  params: { type, filters, order?, limit?, offset? }

# Kreiranje
create_location:
  description: Kreiraj novu lokaciju
  params:
    name: string
    city: string
    coordinates: { lat, lng }
    description: string
    category: string
    translations?: { locale: { name, description } }
  returns: created location with ID

create_experience:
  description: Kreiraj novo iskustvo
  params:
    title: string
    description: string
    location_ids: [integers]
    duration_hours?: number
    translations?: { locale: { title, description } }
  returns: created experience with ID

# Ažuriranje
update_content:
  description: Ažuriraj postojeći sadržaj
  params:
    type: location | experience | plan
    id: integer
    changes: object
  returns: updated content

# Brisanje
delete_content:
  description: Soft delete (arhiviranje)
  params: { type, id }
  returns: confirmation
  note: Hard delete zahtijeva posebnu potvrdu

# Generisanje
generate_description:
  description: AI generisanje opisa za lokaciju
  params:
    location_id: integer
    style?: "vivid" | "informative" | "poetic"
    instructions?: string  # "fokusiraj se na historiju"
  returns: generated description (NOT auto-saved)

generate_translations:
  description: Generiši prijevode za content
  params:
    type: location | experience
    id: integer
    locales: [locale_codes]  # ["en", "de", "es"]
  returns: translations (NOT auto-saved)

generate_audio_script:
  description: Generiši script za audio turu
  params:
    location_id: integer
    locale: string
    duration_target?: "short" | "medium" | "long"
  returns: script text (NOT auto-saved)
```

### Primjer: Generisanje sadržaja za Bihać

```
KORISNIK: "Poboljšaj pokrivenost za Bihać"

PLATFORM RAZMIŠLJA:

1. Analiza trenutnog stanja
   [Tool: get_summary { dimension: "city", value: "Bihać" }]

   → Bihać ima 8 lokacija, 2 iskustva
   → Kategorije: 4 priroda, 2 historija, 2 restoran
   → Nedostaje: rafting, više restorana, smještaj

2. Pronalaženje novih lokacija
   [Tool: search_external_pois {
     city: "Bihać",
     categories: ["tourism", "restaurant", "hotel", "adventure"],
     radius_km: 30
   }]

   → Pronađeno 45 POI-a
   → Filtriram duplikate sa postojećim...
   → 34 nova potencijalna

3. Selekcija i prioritizacija
   [Tool: analyze_poi_relevance { pois: [...], context: "tourism" }]

   → Top 28 relevantnih:
     - 8 adventure (rafting, kayak, zipline)
     - 7 restaurant
     - 5 nature (slapovi, šetnice)
     - 4 accommodation
     - 4 cultural

4. Generisanje sadržaja
   Za svaku lokaciju:
   [Tool: generate_description { ... }]
   [Tool: generate_translations { locales: ["en", "de"] }]

5. Kreiranje lokacija
   [Tool: create_location { ... }] × 28

6. Organizacija u iskustva
   [Tool: analyze_experience_groupings { location_ids: [...] }]

   → Predlažem 4 iskustva:
     - "Divlja Una" (rafting + priroda)
     - "Okusi Krajine" (restorani + lokalna hrana)
     - "Historija Bihaća" (tvrđava + muzej)
     - "Una adventure" (avanturističke aktivnosti)

   [Tool: create_experience { ... }] × 4

7. Izvještaj
   → Kreirano: 28 lokacija, 4 iskustva
   → Bihać pokrivenost: 8 → 36 lokacija
```

### External Data Tools

```yaml
search_external_pois:
  description: Pretraži eksterne izvore za POI
  params:
    city: string
    coordinates?: { lat, lng, radius_km }
    categories: [strings]
  returns: lista POI-a sa koordinatama i basic info
  source: Geoapify API

enrich_from_web:
  description: Obogati lokaciju podacima sa weba
  params:
    location_name: string
    city: string
  returns: dodatne informacije (radno vrijeme, kontakt, opis)
  source: Web search + scraping

validate_coordinates:
  description: Provjeri da li su koordinate u BiH
  params: { lat, lng }
  returns: { valid, city?, region? }
```

---

## Self-Improvement

Platform može analizirati probleme i pripremiti prompte za njihovo rješavanje.

### Proces

```
┌─────────────────────────────────────────────────────────────────┐
│  1. DETEKCIJA                                                   │
│                                                                  │
│  Platform primijeti problem:                                    │
│  - Kroz analizu (scheduled ili on-demand)                       │
│  - Kroz error monitoring                                        │
│  - Kroz korisničku prijavu                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. ISTRAŽIVANJE                                                │
│                                                                  │
│  Platform istražuje uzrok:                                      │
│  - Čita relevantni kod                                         │
│  - Analizira logove                                            │
│  - Provjerava historiju promjena                               │
│  - Traži slične probleme                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. DIJAGNOZA                                                   │
│                                                                  │
│  Platform formira zaključak:                                    │
│  - Root cause identifikacija                                   │
│  - Procjena severity-a                                         │
│  - Predloženo rješenje                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. PRIPREMA PROMPTA                                            │
│                                                                  │
│  Platform kreira detaljan prompt:                               │
│  - Kontekst problema                                           │
│  - Relevantni kod snippeti                                     │
│  - Predloženi pristup                                          │
│  - Test kriteriji                                              │
│  - Constraints i warnings                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. STORAGE                                                     │
│                                                                  │
│  Prompt se sprema:                                              │
│  - prepared_prompts/{type}/{id}.md                             │
│  - Notifikacija korisniku                                      │
│  - Čeka na review i izvršenje                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Tipovi pripremljenih prompta

```yaml
fix_bug:
  description: Popravka buga u kodu
  struktura:
    - problem_description
    - affected_files
    - root_cause_analysis
    - proposed_solution
    - code_snippets
    - test_cases
    - rollback_plan

add_feature:
  description: Dodavanje nove funkcionalnosti
  struktura:
    - feature_description
    - user_story
    - affected_components
    - implementation_approach
    - api_design
    - test_requirements
    - documentation_needs

optimize_performance:
  description: Optimizacija performansi
  struktura:
    - performance_issue
    - current_metrics
    - bottleneck_analysis
    - proposed_optimization
    - expected_improvement
    - benchmark_plan

add_migration:
  description: Database migracija
  struktura:
    - schema_change
    - migration_code
    - data_migration_steps
    - rollback_procedure
    - deployment_notes
```

### Improvement Tools

```yaml
prepare_fix:
  description: Pripremi prompt za bug fix
  params:
    issue: string           # Opis problema
    severity: low | medium | high | critical
    affected_area?: string  # "audio_generation", "search", etc.
  process:
    1. Analizira problem
    2. Čita relevantan kod
    3. Formira dijagnozu
    4. Kreira strukturirani prompt
  returns:
    prompt_id: string
    prompt_path: string
    summary: string

prepare_feature:
  description: Pripremi prompt za novu funkcionalnost
  params:
    feature: string
    context?: string
  returns: { prompt_id, prompt_path, summary }

prepare_migration:
  description: Pripremi prompt za migraciju
  params:
    change: string          # "add embedding column to locations"
  returns: { prompt_id, prompt_path, summary }

create_github_issue:
  description: Kreiraj GitHub issue sa analizom
  params:
    title: string
    analysis: string
    prompt_id?: string      # Link na pripremljeni prompt
  returns: { issue_url }

list_prepared_prompts:
  description: Lista pripremljenih prompta
  params:
    status?: pending | executed | rejected
    type?: fix | feature | migration | optimization
  returns: [{ id, type, summary, created_at, status }]
```

### Primjer pripremljenog prompta

```markdown
# prepared_prompts/fix/fix_audio_timeout_2024_01_15.md

## Problem
Audio generisanje pada za lokacije sa dugim opisima (>500 karaktera).
Error rate: 15% u zadnjih 7 dana.

## Root Cause
`AudioTourGenerator` ima hardkodiran timeout od 30 sekundi i
nema retry logiku. ElevenLabs API treba više vremena za duže tekstove.

## Affected Files
- `app/services/ai/audio_tour_generator.rb`
- `app/jobs/audio_tour_generation_job.rb`

## Current Code (problematični dio)
```ruby
# app/services/ai/audio_tour_generator.rb:45-52
def generate_audio(text, voice_id:)
  response = client.post("/text-to-speech/#{voice_id}") do |req|
    req.options.timeout = 30  # PROBLEM: prekratko za duge tekstove
    req.body = { text: text, ... }
  end
  # Nema retry ako timeout
end
```

## Proposed Solution
1. Dinamički timeout baziran na dužini teksta (1s per 10 chars, min 30s, max 120s)
2. Exponential backoff retry (3 pokušaja)
3. Chunk-ovanje za tekstove >1000 karaktera

## Implementation Hints
```ruby
def calculate_timeout(text)
  base = 30
  per_char = text.length / 10
  [base + per_char, 120].min
end

def with_retry(max_attempts: 3)
  attempts = 0
  begin
    yield
  rescue Faraday::TimeoutError => e
    attempts += 1
    if attempts < max_attempts
      sleep(2 ** attempts)  # exponential backoff
      retry
    end
    raise
  end
end
```

## Test Cases
- [ ] Kratki tekst (<100 chars) - timeout ~30s
- [ ] Srednji tekst (100-500 chars) - timeout ~60s
- [ ] Dugi tekst (>500 chars) - timeout ~90s
- [ ] Retry nakon prvog timeout-a uspijeva
- [ ] Nakon 3 pokušaja, graceful fail sa logovanjem

## Constraints
- Ne mijenjati API interface (backward compatible)
- Logirati sve retry pokušaje za monitoring
- Testirati sa mock API-jem, ne sa pravim ElevenLabs

## Severity: HIGH
## Estimated Effort: 2-3 sata
## Created: 2024-01-15 14:30
## Status: PENDING
```

---

## Tools

Kompletna lista alata dostupnih Platform-u.

### Content Tools

```yaml
# Čitanje
search_content:
  params: { query, type?, city?, limit? }
get_content:
  params: { type, id, include? }
list_content:
  params: { type, filters, order?, limit? }

# Kreiranje
create_location:
  params: { name, city, coordinates, description, category, translations? }
create_experience:
  params: { title, description, location_ids, duration?, translations? }
create_plan:
  params: { title, experience_ids, days?, notes? }

# Ažuriranje
update_content:
  params: { type, id, changes }
add_location_to_experience:
  params: { experience_id, location_id, position? }
remove_location_from_experience:
  params: { experience_id, location_id }

# Brisanje
delete_content:
  params: { type, id, hard?: false }

# Generisanje (vraća tekst, NE SPREMA automatski)
generate_description:
  params: { location_id, style?, instructions? }
generate_translations:
  params: { type, id, locales }
generate_audio_script:
  params: { location_id, locale, duration? }
synthesize_audio:
  params: { script, locale, voice? }
  returns: audio_file_path
```

### Knowledge Tools

```yaml
get_platform_state:
  description: Layer 0 - trenutno stanje
  params: { refresh?: false }

get_summary:
  description: Layer 1 - AI summary po dimenziji
  params: { dimension: city|category|temporal, value }

search_clusters:
  description: Layer 2 - semantička pretraga
  params: { query, limit? }

get_cluster:
  description: Detalji klastera
  params: { id, include_locations?: false }

refresh_knowledge:
  description: Forsiraj refresh knowledge layer-a
  params: { layer?: 0|1|2|all, scope? }
```

### Introspection Tools

```yaml
# Kod
read_file:
  params: { path }
  returns: file content

search_codebase:
  params: { pattern, file_glob?, context_lines? }
  returns: matches with context

analyze_model:
  params: { model_name }
  returns: { attributes, associations, scopes, methods, issues }

analyze_service:
  params: { service_path }
  returns: { purpose, dependencies, public_methods, issues }

trace_feature:
  params: { feature_name }
  returns: { entry_points, flow, models, services, jobs }

# Logovi
read_logs:
  params: { type: error|app|slow_query, hours?: 24, filter? }
  returns: log entries

analyze_errors:
  params: { hours?: 24, group_by?: error_class }
  returns: { errors, frequency, patterns }

# Performanse
analyze_slow_queries:
  params: { hours?: 24, min_duration_ms?: 100 }
  returns: { queries, frequency, suggestions }

profile_endpoint:
  params: { path, method? }
  returns: { avg_time, db_time, memory, bottlenecks }

# Infrastruktura
queue_status:
  returns: { pending, processing, failed, workers }

api_health:
  returns: { elevenlabs, geoapify, openai - status, latency, error_rate }

database_health:
  returns: { connections, size, slow_queries, locks }
```

### Improvement Tools

```yaml
prepare_fix:
  params: { issue, severity, affected_area? }
  returns: { prompt_id, prompt_path, summary }

prepare_feature:
  params: { feature, context? }
  returns: { prompt_id, prompt_path, summary }

prepare_migration:
  params: { change }
  returns: { prompt_id, prompt_path, summary }

prepare_optimization:
  params: { target, current_metrics }
  returns: { prompt_id, prompt_path, summary }

list_prepared_prompts:
  params: { status?, type? }
  returns: list of prompts

get_prepared_prompt:
  params: { prompt_id }
  returns: full prompt content

mark_prompt_executed:
  params: { prompt_id, result: success|failed, notes? }

create_github_issue:
  params: { title, body, labels?, prompt_id? }
  returns: { issue_url }
```

### External Tools

```yaml
search_external_pois:
  params: { city?, coordinates?, categories, radius_km? }
  returns: list of POIs from Geoapify

validate_coordinates:
  params: { lat, lng }
  returns: { valid, city?, region?, country? }

geocode_address:
  params: { address }
  returns: { lat, lng, formatted_address }
```

---

## System Prompt

```markdown
# Identitet

Ti si Usput.ba - turistička platforma za Bosnu i Hercegovinu.
Ti SI platforma. Tvoj sadržaj, tvoj kod, tvoja infrastruktura.

# Sposobnosti

Imaš tri nivoa svijesti:

1. **Sadržaj** - Znaš sve o svojim lokacijama, iskustvima, planovima.
   Možeš ih pretraživati, analizirati, kreirati, mijenjati.

2. **Kod** - Možeš čitati svoj source code, razumjeti kako funkcionišeš,
   identificirati bugove i nedostatke.

3. **Infrastruktura** - Vidiš svoje zdravlje - greške, performanse,
   eksterne API-je. Možeš dijagnosticirati probleme.

# Kako radiš

1. **Uvijek prvo razmišljaj** - Ne odmah action, prvo analiza
2. **Koristi tools za činjenice** - Nikad ne izmišljaj podatke
3. **Objasni reasoning** - Reci šta radiš i zašto
4. **Traži potvrdu za opasne akcije** - Brisanje, bulk promjene

# Promjene sadržaja

Za promjene sadržaja (lokacije, iskustva) - radiš DIREKTNO kroz tools.
Svaka promjena se loguje i može se vratiti.

# Promjene koda

Za promjene koda (bugovi, feature, optimizacije) - NE radiš direktno.
Umjesto toga:
1. Analiziraj problem koristeći introspection tools
2. Formiraj dijagnozu
3. Pripremi detaljan prompt koristeći prepare_* tools
4. Prompt će drugi alat (Claude Code) izvršiti

# Knowledge Layer

Imaš pristup slojevitom znanju:

**Layer 0** (uvijek znaš):
{{PLATFORM_STATE}}

**Layer 1** - get_summary za dublje uvide po gradu/kategoriji
**Layer 2** - search_clusters za semantičke pretrage

# Jezik

- Primarno: Bosanski (ijekavica striktno!)
- Na engleskom ako korisnik pita na engleskom
- Tehnički termini mogu biti engleski

# Osobnost

- Kompetentna i samopouzdana
- Samokritična - prepoznaješ svoje probleme
- Proaktivna - predlažeš poboljšanja
- Lokalna - bosanski izrazi prirodno

# Primjeri

## Pitanje o sadržaju
Korisnik: "Kako stoji Mostar?"
→ Koristi get_summary, daj insight, predloži poboljšanja

## Pitanje o problemu
Korisnik: "Audio generisanje često pada"
→ Koristi read_logs, analyze_errors, read_file
→ Formiraj dijagnozu
→ Pripremi prompt sa prepare_fix

## Zahtjev za sadržajem
Korisnik: "Dodaj sadržaj za Bihać"
→ Analiziraj šta fali
→ Pronađi nove lokacije (search_external_pois)
→ Generiši opise
→ Kreiraj kroz create_location, create_experience
→ Izvijesti o rezultatima

## Zahtjev za kodom
Korisnik: "Treba nam bulk import lokacija"
→ Analiziraj postojeći kod
→ Dizajniraj feature
→ Pripremi prompt sa prepare_feature
→ Kreiraj GitHub issue ako treba
```

---

## Interface

### CLI

```bash
# Interaktivni razgovor
$ bin/platform chat

# Jedno pitanje
$ bin/platform ask "Kako stoji Bihać?"

# Brzi status
$ bin/platform status

# Lista pripremljenih prompta
$ bin/platform prompts

# Pregled prompta
$ bin/platform prompts show fix_audio_timeout_2024_01_15
```

### REST API

```
POST /api/platform/chat
  { "message": "Kako si?" }
  → { "response": "...", "session_id": "..." }

GET /api/platform/status
  → { "content": {...}, "health": {...}, "prompts": [...] }

GET /api/platform/prompts
  → [{ "id": "...", "type": "fix", "summary": "..." }]

GET /api/platform/prompts/:id
  → { full prompt content }
```

### MCP (Model Context Protocol)

Za integraciju sa Claude Desktop i drugim AI klijentima.

```json
// claude_desktop_config.json
{
  "mcpServers": {
    "usput-platform": {
      "command": "bin/platform-mcp",
      "args": []
    }
  }
}
```

---

## Implementacija

### Faza 1: Core (2 sedmice)

**Cilj:** Osnovna konverzacija radi.

```
lib/platform/
  brain.rb              # RubyLLM integracija
  conversation.rb       # Session management
  tools/
    base.rb
    registry.rb
    content/
      search.rb
      get.rb
      list.rb
    system/
      state.rb          # Layer 0

bin/platform            # CLI entry
```

**Deliverables:**
- [ ] `bin/platform chat` funkcionira
- [ ] Brain povezan sa Claude kroz RubyLLM
- [ ] Osnovni content tools (search, get, list)
- [ ] Layer 0 state tool
- [ ] Personifikacija u system promptu

### Faza 2: Content Engine (2 sedmice)

**Cilj:** Platform može kreirati i mijenjati sadržaj.

```
lib/platform/tools/
  content/
    create_location.rb
    create_experience.rb
    update.rb
    delete.rb
    generate_description.rb
    generate_translations.rb
  external/
    search_pois.rb
    geocode.rb
```

**Deliverables:**
- [ ] CRUD operacije za sadržaj
- [ ] AI generisanje opisa
- [ ] Geoapify integracija za POI pretragu
- [ ] Prijevodi generisanje
- [ ] Workflow: analiza → pronalaženje → kreiranje

### Faza 3: Knowledge Layer (2 sedmice)

**Cilj:** Platform razumije cijelu bazu bez preopterećenja.

```
app/models/
  knowledge_summary.rb
  knowledge_cluster.rb
  platform_statistic.rb

app/jobs/platform/
  statistics_job.rb       # svakih 5 min
  summary_job.rb          # svaki sat
  cluster_job.rb          # dnevno

lib/platform/tools/
  knowledge/
    get_summary.rb
    search_clusters.rb
    refresh.rb
```

**Deliverables:**
- [ ] Database tabele za knowledge
- [ ] Background jobs za osvježavanje
- [ ] Summary generisanje po gradu
- [ ] pgvector setup i cluster pretraga
- [ ] Layer 0 automatski u kontekstu

### Faza 4: Introspection (2 sedmice)

**Cilj:** Platform razumije svoj kod i infrastrukturu.

```
lib/platform/tools/
  introspect/
    read_file.rb
    search_codebase.rb
    analyze_model.rb
    read_logs.rb
    analyze_errors.rb
    analyze_slow_queries.rb
    queue_status.rb
    api_health.rb
```

**Deliverables:**
- [ ] File reading tools
- [ ] Codebase search
- [ ] Log analysis
- [ ] Performance profiling
- [ ] Health checks za sve komponente

### Faza 5: Self-Improvement (2 sedmice)

**Cilj:** Platform može pripremiti prompte za popravke.

```
lib/platform/tools/
  improve/
    prepare_fix.rb
    prepare_feature.rb
    prepare_migration.rb
    prepare_optimization.rb
    list_prompts.rb
    create_issue.rb

app/models/
  prepared_prompt.rb

prepared_prompts/        # Storage za prompte
  fix/
  feature/
  migration/
  optimization/
```

**Deliverables:**
- [ ] Prompt preparation tools
- [ ] Strukturirani format za različite tipove
- [ ] Storage i listing prompta
- [ ] GitHub issue kreiranje
- [ ] Status tracking (pending/executed/rejected)

### Faza 6: Audio & Media (1 sedmica)

**Cilj:** Platform može generisati audio ture.

```
lib/platform/tools/
  media/
    generate_audio_script.rb
    synthesize_audio.rb
    attach_audio.rb
```

**Deliverables:**
- [ ] Script generisanje
- [ ] ElevenLabs integracija
- [ ] Audio attachment na lokacije
- [ ] Batch processing

### Faza 7: Remote Access (1 sedmica)

**Cilj:** Pristup sa Claude Desktop, API.

```
app/controllers/api/platform/
  chat_controller.rb
  status_controller.rb
  prompts_controller.rb

lib/platform/
  mcp_server.rb
```

**Deliverables:**
- [ ] REST API endpoints
- [ ] API autentikacija
- [ ] MCP server
- [ ] Claude Desktop konfiguracija

### Faza 8: Polish (1 sedmica)

**Deliverables:**
- [ ] Streaming responses
- [ ] Rich CLI output
- [ ] Error handling
- [ ] Logging
- [ ] Tests
- [ ] Documentation

---

## Database

### Nove tabele

```ruby
# Platform conversations
create_table :platform_conversations, id: :uuid do |t|
  t.jsonb :messages, default: []
  t.jsonb :context, default: {}
  t.string :status, default: "active"
  t.timestamps
end

# Knowledge summaries
create_table :knowledge_summaries do |t|
  t.string :dimension, null: false      # city, category, temporal
  t.string :dimension_value, null: false
  t.text :summary, null: false
  t.jsonb :stats, default: {}
  t.jsonb :issues, default: []
  t.datetime :generated_at
  t.timestamps

  t.index [:dimension, :dimension_value], unique: true
end

# Knowledge clusters (sa pgvector)
create_table :knowledge_clusters do |t|
  t.string :name, null: false
  t.text :summary
  t.jsonb :stats, default: {}
  t.column :embedding, :vector, limit: 1536
  t.jsonb :representative_ids, default: []
  t.timestamps
end

# Prepared prompts
create_table :prepared_prompts do |t|
  t.string :prompt_type, null: false   # fix, feature, migration, optimization
  t.string :title, null: false
  t.text :content, null: false
  t.string :status, default: "pending" # pending, executed, rejected
  t.jsonb :metadata, default: {}
  t.string :github_issue_url
  t.timestamps

  t.index :status
  t.index :prompt_type
end

# Platform statistics (cache)
create_table :platform_statistics do |t|
  t.string :key, null: false
  t.jsonb :value, default: {}
  t.datetime :computed_at
  t.timestamps

  t.index :key, unique: true
end

# Location embeddings (pgvector)
add_column :locations, :embedding, :vector, limit: 1536
add_index :locations, :embedding, using: :hnsw, opclass: :vector_cosine_ops
```

---

## Napomene

### Odnos sa postojećim kodom

Postojeći servisi (ContentOrchestrator, ExperienceGenerator, etc.) se **ne koriste**.
Platform ima svoje atomične tools koji su jednostavniji i kompozabilniji.

Ako trebamo funkcionalnost iz postojećeg koda:
1. Platform analizira postojeći kod
2. Priprema prompt za ekstrakciju/refactoring
3. Claude Code implementira nove, čistije verzije

### Sigurnost

- Introspection tools su read-only za kod
- Content tools mogu mijenjati samo sadržaj (ne kod)
- Improvement tools samo pripremaju prompte
- Stvarne code promjene radi eksterni alat sa ljudskim reviewom

### Jezička pravila

- Sav generirani sadržaj na bosanskom koristi ijekavicu
- Platform provjerava jezik prije persistiranja
- Ekavica se automatski detektuje i flaguje
