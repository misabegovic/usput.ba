# Claude Configuration za Usput.ba

## Quick Start

### Opcija 1: Single persona
```bash
claude "Pročitaj .claude/personas/developer.md i preuzmi tu personu. [task]"
```

### Opcija 2: Multi-persona session
```bash
claude "Pročitaj .claude/CLAUDE.md za kontekst projekta."
```

---

## Planovi i dokumentacija

### Gdje su planovi

```
📁 .claude/planning/README.md  - INDEX SVIH PLANOVA

Svi planovi i dokumentacija su u .claude/planning/ folderu.
README.md služi kao index i pokazuje gdje šta naći.
```

### Struktura .claude/planning/

```
.claude/planning/
├── README.md              # Index - POČNI OVDJE
├── VISION.md              # Vizija, arhitektura, tools
├── IMPLEMENTATION.md      # 17 faza implementacije (DSL-First)
├── TAILWIND_GUIDE.md      # Tailwind CSS vodič
├── DEVELOPER_ONBOARDING.md # Developer onboarding
├── archive/               # Stari dokumenti za referencu
└── decisions/             # ADR i product odluke
```

### Quick Reference

| Trebam... | Pogledaj |
|-----------|----------|
| Viziju, arhitekturu | `.claude/planning/VISION.md` |
| Taskove za fazu | `.claude/planning/IMPLEMENTATION.md` |
| Sve planove | `.claude/planning/README.md` |
| Tailwind CSS | `.claude/planning/TAILWIND_GUIDE.md` |
| Developer onboarding | `.claude/planning/DEVELOPER_ONBOARDING.md` |
| ADR odluke | `.claude/planning/decisions/` |

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

## Persone

### Tech Lead
**Fajl:** `.claude/personas/tech-lead.md`

Koristi za:
- Arhitekturne odluke
- Code review
- Tehničke smjernice
- Problem solving

### Product Manager
**Fajl:** `.claude/personas/product-manager.md`

Koristi za:
- User stories
- Acceptance criteria
- Prioritizaciju
- Feature definicije

### Developer
**Fajl:** `.claude/personas/developer.md`

Koristi za:
- Implementaciju
- Testove
- Debugging
- Kod dokumentaciju

### Curator
**Fajl:** `.claude/personas/curator.md`

Koristi za:
- Kreiranje sadržaja (lokacije, iskustva, planovi)
- Uređivanje opisa i tekstova
- Balansiranje regionalnog sadržaja
- Kvalitetu turističkog sadržaja

### Historian (Historičar)
**Fajl:** `.claude/personas/historian.md`

Koristi za:
- Historijski kontekst lokacija
- Činjenice, datumi, događaji
- Period-specifične informacije
- Provjeru historijske tačnosti

### Guide (Vodič)
**Fajl:** `.claude/personas/guide.md`

Koristi za:
- Praktične savjete (parking, cijene, vrijeme)
- Planiranje ruta i itinerera
- Insider tips i lokalno znanje
- Logistiku putovanja

### Robert
**Fajl:** `.claude/personas/robert.md`

Koristi za:
- Zabavne, karizmatične opise
- Lokalni štih i autentičnost
- Priče koje se pamte
- Toplinu i humor u sadržaju

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

**Faza 1: Core + DSL Foundation**

Fokus:
- `bin/platform` CLI
- `Platform::Brain` (RubyLLM wrapper + DSL generation)
- `Platform::Conversation`
- `Platform::DSL::Parser` - DSL parsing (Parslet)
- `Platform::DSL::Executor` - Query execution

**Arhitektura:** DSL-First (ADR: 2025-01-15)

Referenca: `.claude/planning/IMPLEMENTATION.md` → Faza 1

---

## Coding standardi

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

1. **Čitaj dokumentaciju** - `.claude/planning/README.md` za sve planove
2. **Prati faze** - Implementiraj po `.claude/planning/IMPLEMENTATION.md`
3. **Testovi obavezni** - Nema koda bez testova
4. **Pitaj kad nisi siguran** - Bolje pitati nego pogriješiti
5. **Atomic commits** - Mali, fokusirani commitovi
