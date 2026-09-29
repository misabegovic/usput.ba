# Claude Code Setup

## Projekat
**Usput.ba** - Turistička platforma za Bosnu i Hercegovinu sa AI-powered content generacijom.

## Tech Stack
- Ruby 3.3+ / Rails 8
- PostgreSQL + pgvector
- Tailwind CSS
- Hotwire (Turbo + Stimulus)

## Brzi start

```bash
# Development
bin/rails server
bin/rails console
bin/rails test

# Platform CLI (DSL queries)
bin/platform exec 'locations | count'
bin/platform exec 'experiences | where(city: "Sarajevo") | limit(5)'
```

## Struktura

```
app/
├── controllers/
│   ├── curator/          # Curator dashboard
│   └── new_design/       # Public pages
├── models/               # ActiveRecord modeli
├── services/
│   └── ai/              # AI servisi (generators, enrichers)
├── views/
│   ├── curator/         # Curator UI
│   └── new_design/      # Public UI
└── javascript/
    └── controllers/     # Stimulus kontroleri

lib/
└── platform/            # Platform brain (DSL, tools)

.claude/
├── agents/              # Agent persone
├── commands/            # Slash komande
└── CLAUDE.md           # Detaljne instrukcije

wiki/                    # Brain: sinteza na engleskom (tabula)
sources/                 # Nepromjenjivi originali (planning/ na bosanskom)
brain.config.yml         # Konfiguracija braina
```

## Agenti

Pogledaj `AGENTS.md`: pravila braina (tabula) i lista dostupnih agenata.

## Dokumentacija

| Dokument | Lokacija |
|----------|----------|
| Detaljne instrukcije | `.claude/CLAUDE.md` |
| Agent persone | `.claude/agents/` |
| Brain (pravila, engleski) | `AGENTS.md` |
| Wiki (početna) | `wiki/index.md` |
| Stanje proizvoda | `wiki/state.md` |
| Odluke (ADR) | `wiki/decisions/` |
| Originalni planovi | `sources/planning/` |
| Vizija (original) | `sources/planning/VISION.md` |

## Pravila

1. **Testovi obavezni** - ne commitaj kod bez testova
2. **Prati patterns** - koristi postojeće obrasce u kodu
3. **Pitaj kad nisi siguran** - bolje pitati nego pogriješiti
4. **Bosanski sadržaj** - ijekavica, "historija" ne "istorija"
