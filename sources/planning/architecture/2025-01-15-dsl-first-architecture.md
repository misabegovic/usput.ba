# ADR: DSL-First Architecture za Platform

**Datum:** 2025-01-15
**Status:** Accepted
**Učesnici:** PM, Tech Lead, Product Owner

---

## Kontekst

Platform treba podržati scale od 1,000,000+ rekorda (lokacije, iskustva, planovi). Razmatrali smo tri pristupa:

### Pristup A: Tools-Only (odbačen)
```
AI direktno poziva tools → Tools čitaju bazu → AI rezonuje nad rezultatima
```
**Problem:** Ne skalira. AI ne može rezonovati nad milionima rekorda.

### Pristup B: pgvector-First (odbačen)
```
Pre-compute embeddings → Vector similarity search → AI rezonuje nad top N
```
**Problem:** "Glup" pristup - samo matematička sličnost, nema pravog razumijevanja.

### Pristup C: DSL-First (ODABRAN)
```
AI generiše DSL queries → DSL Engine izvršava → AI rezonuje nad strukturiranim rezultatima
```
**Prednosti:** Skalira, AI-native, kombinuje brzinu indexed querija sa AI reasoning.

---

## Odluka

Implementiramo **DSL-First Architecture** inspirisanu LogQL pristupom.

### Arhitektura

```
┌─────────────────────────────────────────────────────────────────┐
│                         PLATFORM                                 │
│                                                                  │
│  User Input → LLM (Claude) → Generates DSL Query                │
│                                   ↓                              │
│                            DSL Parser                            │
│                                   ↓                              │
│                           Query Executor                         │
│                                   ↓                              │
│                    ┌─────────────────────────────┐              │
│                    │   LAYERED KNOWLEDGE         │              │
│                    │                             │              │
│                    │  L0: Stats (always loaded)  │              │
│                    │  L1: Summaries (on-demand)  │              │
│                    │  L2: Clusters (pgvector)    │              │
│                    │  L3: Raw records (indexed)  │              │
│                    └─────────────────────────────┘              │
│                                   ↓                              │
│                    Structured Results → LLM → Response          │
└─────────────────────────────────────────────────────────────────┘
```

### DSL Primjeri

```
# Layer 0 - Schema i stats
schema | stats
schema | health

# Layer 1 - Summaries
summaries { region: "mostar" } | show
summaries { type: "restaurant" } | issues

# Layer 2 - Semantic clusters
clusters | semantic "ottoman heritage" | top 5
clusters { id: "adventure-sports" } | show

# Layer 3 - Raw records (indexed access only)
locations { region: "sarajevo", type: "restaurant" } | sample 10
locations { cluster_id: "fine-dining" } | aggregate count() by city
```

### Layered Knowledge

| Layer | Sadržaj | Veličina | Pristup |
|-------|---------|----------|---------|
| 0 | Stats, schema, health | ~2K tokena | Always in context |
| 1 | AI summaries po regiji/kategoriji | ~10K po summary | On-demand load |
| 2 | Semantic clusters | pgvector index | DSL semantic search |
| 3 | Raw records | Millions | Indexed queries only |

---

## Posljedice

### Pozitivne
- Skalira do 1,000,000+ rekorda
- AI-native: LLM generiše queries, ne čita raw data
- Kombinuje brzinu indexed querija sa AI reasoning
- Layered pristup optimizira context window
- pgvector se koristi pametno (samo za cluster search)

### Negativne
- Kompleksnije od tools-only pristupa
- Treba implementirati DSL parser i executor
- Duži timeline za Fazu 1
- Treba background jobs za Layer 1 i 2

### Tehnički dug
- DSL grammar treba pažljivo dizajnirati
- Query cost estimation je kritičan za scale
- Treba rate limiting i timeout handling

---

## Implementacija

### Nova struktura faza

```
Faza 1: Core + DSL Foundation
- CLI entry point
- Brain (RubyLLM wrapper)
- DSL Parser (basic grammar)
- DSL Executor (basic operations)
- Layer 0 (stats, schema)

Faza 2: Knowledge Layer
- Layer 1 (summaries) + background jobs
- Layer 2 (clusters) + pgvector
- Full DSL grammar

Faza 3+: Content operations, Audio, etc.
```

### Ključni fajlovi

```
lib/platform/
  brain.rb                 # LLM integration
  conversation.rb          # Session management
  dsl/
    parser.rb              # DSL grammar parser
    executor.rb            # Query execution
    grammar.rb             # DSL grammar definition
  knowledge/
    layer0.rb              # Stats, schema
    layer1.rb              # Summaries
    layer2.rb              # Clusters
```

---

## Reference

- Originalni plan: `.claude/planning/archive/AI_ARCHITECTURE_PROMPT.md`
- LogQL dokumentacija: https://grafana.com/docs/loki/latest/query/
- pgvector: https://github.com/pgvector/pgvector
