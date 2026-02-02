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
├── planning/            # Planovi i dokumentacija
└── CLAUDE.md           # Detaljne instrukcije
```

## Agenti

Pogledaj `AGENTS.md` za listu dostupnih agenata.

## Dokumentacija

| Dokument | Lokacija |
|----------|----------|
| Detaljne instrukcije | `.claude/CLAUDE.md` |
| Agent persone | `.claude/agents/` |
| Planovi | `.claude/planning/` |
| Vizija | `.claude/planning/VISION.md` |

## Pravila

1. **Testovi obavezni** - ne commitaj kod bez testova
2. **Prati patterns** - koristi postojeće obrasce u kodu
3. **Pitaj kad nisi siguran** - bolje pitati nego pogriješiti
4. **Bosanski sadržaj** - ijekavica, "historija" ne "istorija"
