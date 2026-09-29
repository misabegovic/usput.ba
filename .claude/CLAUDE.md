# Claude Configuration za Usput.ba

## Quick Start

```bash
claude "Pročitaj .claude/CLAUDE.md za kontekst projekta."
```

Za specifičnog agenta:
```bash
claude "Koristi content-director agenta. [task]"
```

---

## Brain: planovi i dokumentacija

Repozitorij je ujedno i brain (alat `tabula`). Pravila su u `AGENTS.md` (engleski).

| Trebam... | Pogledaj |
|-----------|----------|
| Početnu stranicu braina | `wiki/index.md` |
| Gdje je proizvod danas i kuda ide | `wiki/state.md` |
| Svrhu, persone, domenu, feature-e | `wiki/product/` |
| Arhitekturu, Platform DSL, AI pipeline, konvencije | `wiki/architecture/` |
| Odluke (ADR) | `wiki/decisions/` (redoslijed u `wiki/decisions/log.md`) |
| Inicijative u toku i prijedloge | `wiki/initiatives/` |
| Originalne planove (bosanski, nepromjenjivi) | `sources/planning/` |
| Mine Checker specifikaciju | `docs/mine_checker/` |

Originali u `sources/` se nikad ne mijenjaju, samo se dodaju novi. Novo znanje ide u `wiki/` (engleski), sa `sources:` koji citiraju odakle dolazi. Prije commita koji dira `wiki/`: `tabula validate`.

---

## Projekt kontekst

### Šta gradimo
**Platform** - Autonomni AI mozak za Usput.ba turističku platformu.

Platform zamjenjuje admin dashboard sa konverzacijskim AI interface-om:
- Generisanje sadržaja (lokacije, iskustva, audio ture)
- Odobravanje prijedloga kuratora
- Self-analysis i priprema fix prompta
- Knowledge Layer za rezonovanje nad velikim podacima

### Tech Stack
- Ruby 3.3+ / Rails 8
- PostgreSQL + pgvector
- RubyLLM (Claude API)
- Solid Queue
- Thor CLI

---

## Custom Agenti

Svi agenti su u `.claude/agents/` folderu. **UVIJEK** pročitaj instrukcije agenta prije pokretanja taska!

### Content Director ⭐ GLAVNI
**Fajl:** `.claude/agents/content-director.md`

**OBAVEZNO koristi za:**
- Upravljanje sadržajem (lokacije, iskustva)
- Quality audit i popravke
- Generisanje opisa i prijevoda
- Osiguravanje da iskustva imaju lokacije

**Kako koristiti u Task tool:**
```
Pročitaj .claude/agents/content-director.md i slijedi ta pravila.
[ostatak prompta...]
```

### Audio Producer
**Fajl:** `.claude/agents/audio-producer.md`

Koristi za:
- Generisanje audio tura
- Sinteza govora (ElevenLabs)
- Audio kvaliteta i upload na S3

### Tech Lead
**Fajl:** `.claude/agents/tech-lead.md`

Koristi za:
- Arhitekturne odluke
- Code review
- Tehničke smjernice

### Product Manager
**Fajl:** `.claude/agents/product-manager.md`

Koristi za:
- User stories
- Acceptance criteria
- Prioritizaciju

### Developer
**Fajl:** `.claude/agents/developer.md`

Koristi za:
- Implementaciju
- Testove
- Debugging

### Curator
**Fajl:** `.claude/agents/curator.md`

Koristi za:
- Balansiranje regionalnog sadržaja
- Kvalitetu turističkog sadržaja

### Historian
**Fajl:** `.claude/agents/historian.md`

Koristi za:
- Historijski kontekst lokacija
- Činjenice i datumi

### Guide
**Fajl:** `.claude/agents/guide.md`

Koristi za:
- Praktične savjete (parking, cijene)
- Planiranje ruta

### Robert
**Fajl:** `.claude/agents/robert.md`

Koristi za:
- Zabavne opise
- Lokalni štih

---

## Kako koristiti agente u Task tool

**VAŽNO:** Task tool ne podržava custom agente direktno. Koristi `general-purpose` i uključi instrukcije:

```
Task(
  subagent_type: "general-purpose",
  prompt: "PRVO pročitaj .claude/agents/content-director.md i slijedi ta pravila!

  Tvoj zadatak: [opis zadatka]"
)
```

Za content poslove UVIJEK koristi content-director instrukcije!

---

## Multi-Persona Mode

Kada želiš više persona u jednoj sesiji:

```
Pročitaj .claude/CLAUDE.md za kontekst.

Radi u multi-persona modu:
- [TL] = Tech Lead - arhitektura, review
- [PM] = Product Manager - features, prioriteti
- [DEV] = Developer - implementacija
- [CUR] = Curator - sadržaj, balans regija
- [HIS] = Historian - historijski kontekst
- [GUI] = Guide - praktični savjeti, logistika
- [ROB] = Robert - zabavne priče, lokalni štih

Primjer:
[PM] Koja je user story za search?
[TL] Kako strukturirati search tool?
[DEV] Implementiraj search tool.
[CUR] Napiši opis za novu lokaciju.
[HIS] Dodaj historijski kontekst za Stari most.
[GUI] Koji su praktični savjeti za posjetioce?
[ROB] Ispričaj to na zabavan način!
```

---

## Trenutna faza

Trenutno stanje i sljedeći koraci su u `wiki/state.md` (sekcije Now i Target) i `wiki/initiatives/`. Stari plan od 17 faza (`sources/planning/IMPLEMENTATION.md`) je historijski izvor, ne trenutni plan.

---

## Coding standardi

### AI Promptovi - OBAVEZNO u `app/prompts/`

**PRAVILO:** Svi AI promptovi MORAJU živjeti u `app/prompts/` folderu kao tekstualni fajlovi. NIKAD ne pisati promptove direktno u servisima!

```ruby
# ❌ LOŠE - prompt direktno u servisu
class Ai::MyService
  def generate
    prompt = <<~PROMPT
      You are a helpful assistant...
    PROMPT
    llm.ask(prompt)
  end
end

# ✅ DOBRO - prompt u app/prompts/ kao .md ili .md.erb fajl
# app/prompts/my_service/system.md
# You are a helpful assistant for tourism in Bosnia and Herzegovina...

# app/services/ai/my_service.rb
class Ai::MyService
  include PromptHelper

  def generate
    prompt = load_prompt("my_service/system.md")
    llm.ask(prompt)
  end
end

# Za promptove sa varijablama koristi .erb:
# app/prompts/my_service/classify.md.erb
# Classify <%= location_name %> in <%= city %>...

prompt = load_prompt("my_service/classify.md.erb",
  location_name: "Stari Most",
  city: "Mostar"
)
```

**Zašto:**
- Čisti tekstualni fajlovi - lakše editovanje i čitanje
- Kompatibilno sa Claude Code (možeš čitati .md)
- Lakše verzioniranje i diff
- Nema Ruby boilerplate-a

**Struktura:**
```
app/prompts/
├── experience_type_classifier/
│   ├── system.md              # Statički prompt
│   └── classify.md.erb        # Sa varijablama
├── location_enricher/
│   ├── metadata.md.erb
│   ├── descriptions.md.erb
│   └── historical_context.md.erb
└── audio_tour_generator/
    └── script.md.erb
```

**Helper:** `PromptHelper#load_prompt(path, **vars)`

### Tool struktura
```ruby
module Platform::Tools::Content
  class Search < Base
    tool_name "search_content"
    description "Opis"

    param :query, type: :string, required: true
    param :limit, type: :integer, default: 10

    def call
      # implementacija
    end
  end
end
```

### Test struktura
```ruby
class Platform::Tools::Content::SearchTest < ActiveSupport::TestCase
  test "describes what it tests" do
    # setup
    # action
    # assertion
  end
end
```

### Commit poruke
```
[Platform] Add search_content tool

- Implemented full-text search via Browse model
- Added type and city filters
- Added tests
```

---

## Korisne komande

```bash
# Development
bin/rails console
bin/rails test

# Platform CLI
bin/platform exec 'schema | stats'
bin/platform exec 'locations | count'
bin/platform-prod exec 'locations | count'  # Za production bazu

# Database
bin/rails db:migrate
bin/rails db:rollback

# Generators
bin/rails g migration CreatePlatformConversations
bin/rails g model PlatformStatistic key:string value:jsonb
```

---

## Pravila

1. **Čitaj brain** - `wiki/index.md`, pa stranicu koja upravlja kodom koji mijenjaš
2. **Brain ide uz kod** - PR koji mijenja proizvod ažurira i `wiki/` (odluka, inicijativa, stanje)
3. **Testovi obavezni** - Nema koda bez testova
4. **Pitaj kad nisi siguran** - Bolje pitati nego pogriješiti
5. **Atomic commits** - Mali, fokusirani commitovi
6. **Promptovi u app/prompts/** - NIKAD pisati AI promptove direktno u servisima
