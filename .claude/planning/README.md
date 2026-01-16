# Planning dokumentacija za Usput.ba

Centralna lokacija za svu plansku dokumentaciju projekta.

---

## Aktivni dokumenti

### VISION.md
**Šta:** Kompletna vizija Platform-a - arhitektura, tools, system prompt

**Čitaj kada:**
- Trebaš razumjeti šta gradimo
- Trebaš vidjeti arhitekturne dijagrame
- Trebaš specifikaciju tools-a
- Trebaš system prompt za Platform

**Sadržaj:**
```
1. Vizija              - Tri nivoa svijesti Platform-a
2. Arhitektura         - Dijagrami, tok podataka
3. Samosvijest         - Content, Code, Infrastructure awareness
4. Knowledge Layer     - Layer 0, 1, 2
5. Content Engine      - AI-native pristup
6. Self-Improvement    - Priprema prompta za fixeve
7. Tools               - Kompletna specifikacija
8. System Prompt       - Personifikacija
9. Interface           - CLI, API, MCP
10. Implementacija     - Kratki pregled
```

---

### IMPLEMENTATION.md
**Šta:** Detaljan plan implementacije sa 17 faza

**Čitaj kada:**
- Počinješ novu fazu
- Trebaš vidjeti taskove za fazu
- Trebaš database migracije
- Trebaš file strukturu

**Sadržaj (DSL-First Architecture):**
```
Faza 1:  Core + DSL Foundation    - CLI, Brain, DSL Parser/Executor
Faza 2:  Knowledge Layer 0        - Real-time statistike
Faza 3:  Knowledge Layer 1        - AI summaries per region/category
Faza 4:  Knowledge Layer 2        - Semantic clusters (pgvector)
Faza 5:  External Integration     - Geoapify, geocoding
Faza 6:  Content Mutations        - create, update, delete via DSL
Faza 7:  AI Content Generation    - opisi, prijevodi via DSL
Faza 8:  Audio Synthesis          - ElevenLabs via DSL
Faza 9:  Full Generation Workflow - end-to-end za grad
Faza 10: Approval Workflow        - prijedlozi, aplikacije
Faza 11: Curator Management       - spam, blocking
Faza 12: Introspection            - čitanje koda, logova
Faza 13: Self-Improvement         - priprema prompta
Faza 14: Remote Access            - API, MCP
Faza 15: Curator Admin Mode       - photo approval
Faza 16: Remove Admin Dashboard   - cleanup
Faza 17: Polish & Documentation   - finalizacija
```

**Prioriteti:**
```
P0 (Critical Path):  Faze 1-8   - MVP Platform
P1 (Important):      Faze 9-11  - Approval, curator, knowledge
P2 (Nice to Have):   Faze 12-14 - Introspection, self-improvement
P3 (Cleanup):        Faze 15-17 - Finalizacija
```

---

## Ostali dokumenti

### TAILWIND_GUIDE.md
**Šta:** Vodič za Tailwind CSS Pro feature-e

**Čitaj kada:**
- Radiš na frontend-u
- Trebaš koristiti custom komponente (buttons, cards, etc.)
- Trebaš znati koje boje i klase su dostupne

---

### DEVELOPER_ONBOARDING.md
**Šta:** Onboarding dokument za Developer-a (hamal)

**Čitaj kada:**
- Počinješ raditi na projektu
- Trebaš podsjetnik o coding standardima
- Trebaš vidjeti SOLID principe i primjere
- Trebaš setup instrukcije

---

## Arhiva

Stari dokumenti za referencu. Ne koristi za aktivni development.

| Dokument | Opis |
|----------|------|
| `archive/PLATFORM_V1.md` | Prva verzija Platform plana |
| `archive/AI_ARCHITECTURE_PROMPT.md` | Originalna ideja za AI arhitekturu |
| `archive/PLAN_CONTENT_ORCHESTRATOR.md` | Stari ContentOrchestrator pristup (zamijenjen DSL-First) |
| `archive/NEW_OLD_PLAN.md` | Stari plan razvoja sa lib/content_generation/ pristupom |

---

## Odluke (decisions/)

Architecture Decision Records (ADR) - dokumentovane ključne odluke.

### Aktivne odluke

| Datum | Odluka | Status | Fajl |
|-------|--------|--------|------|
| 2025-01-15 | DSL-First Architecture | ✅ Accepted | `decisions/2025-01-15-dsl-first-architecture.md` |
| 2025-01-15 | Implementation Decisions | ✅ Accepted | `decisions/2025-01-15-implementation-decisions.md` |
| 2026-01-16 | Executor Simplification | ✅ Accepted | `decisions/ADR-2026-01-16-executor-simplification.md` |
| 2025-01-15 | Full Introspection in P0 | ✅ Accepted | `decisions/2025-01-15-full-introspection-p0.md` |

### Ključne odluke

**DSL-First Architecture:**
- AI generiše DSL queries (LogQL-inspired)
- 4 Knowledge Layer-a za scale do 1M+ rekorda

**Implementation Decisions:**
- Parslet za DSL parser
- OpenAI ada-002 za embeddings
- On-demand + cache za summaries
- Partial commit za batch operacije

**Full Introspection in P0:**
- Platform mora razumjeti sebe od prvog dana
- Code, logs, infrastructure analysis u P0 prioritetu

---

## Quick Reference

### Za Tech Lead-a
```
1. VISION.md → Sekcija "Arhitektura"
2. VISION.md → Sekcija "Tools"
3. IMPLEMENTATION.md → Trenutna faza
```

### Za Product Manager-a
```
1. VISION.md → Sekcija "Vizija"
2. VISION.md → Sekcija "Content Engine"
3. IMPLEMENTATION.md → Prioriteti
```

### Za Developer-a
```
1. IMPLEMENTATION.md → Trenutna faza (taskovi, file struktura)
2. VISION.md → Tools specifikacija za implementaciju
3. IMPLEMENTATION.md → Database migracije
```

---

## Trenutno stanje

**Kompletne faze:**
- ✅ Faza 1: Core + DSL Foundation
- ✅ Faza 2: Knowledge Layer 0 (Stats)
- ✅ Faza 3: Knowledge Layer 1 (Summaries)
- ✅ Faza 4: Knowledge Layer 2 (Clusters + pgvector)

**Sljedeća faza:** Faza 5 - External Data Integration (Geoapify)

**Implementirane DSL komande:**
```
schema | stats                              # Layer 0 statistike
schema | health                             # System health
summaries | list                            # Lista AI summaries
summaries { city: "Mostar" } | show         # Prikaz summary-ja
summaries | issues                          # Problemi u podacima
clusters | list                             # Lista clusters
clusters { id: "ottoman-heritage" } | show  # Prikaz cluster-a
clusters | semantic "traditional food"      # Semantic search (pgvector)
locations { city: "X" } | sample 10         # Raw record queries
```

**Arhitektura:** DSL-First (ADR: 2025-01-15)

**Referenca:** `IMPLEMENTATION.md` → Faza 5
