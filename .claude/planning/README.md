# Planning dokumentacija za Usput.ba

Centralna lokacija za svu plansku dokumentaciju projekta.

---

## Struktura

```
.claude/planning/
├── README.md              # Ovaj fajl
├── VISION.md              # Vizija, arhitektura, tools
├── IMPLEMENTATION.md      # 17 faza implementacije
├── DEVELOPER_ONBOARDING.md
├── TAILWIND_GUIDE.md
├── adr/                   # Architecture Decision Records
├── architecture/          # Arhitekturni dokumenti
├── testing/               # Test planovi i scenariji
└── archive/               # Stari dokumenti
```

---

## Aktivni dokumenti

### VISION.md
**Šta:** Kompletna vizija Platform-a - arhitektura, tools, system prompt

**Čitaj kada:**
- Trebaš razumjeti šta gradimo
- Trebaš vidjeti arhitekturne dijagrame
- Trebaš specifikaciju tools-a

### IMPLEMENTATION.md
**Šta:** Detaljan plan implementacije sa 17 faza

**Čitaj kada:**
- Počinješ novu fazu
- Trebaš vidjeti taskove za fazu
- Trebaš database migracije

### TAILWIND_GUIDE.md
**Šta:** Vodič za Tailwind CSS Pro komponente

### DEVELOPER_ONBOARDING.md
**Šta:** Onboarding za developere

### LEARNINGS.md
**Šta:** Ekstrahirani patterns iz maintenance skripti i development sesija

---

## ADR (adr/)

Architecture Decision Records - dokumentovane ključne tehničke odluke.

| Datum | Odluka | Status |
|-------|--------|--------|
| 2025-01-15 | Full Introspection in P0 | Accepted |
| 2026-01-16 | Restore Executor Functionality | Accepted |

**Format:** Koristi `/adr` komandu za kreiranje novih.

---

## Decisions (decisions/)

Product i tehničke odluke koje utiču na arhitekturu.

| Datum | Odluka | Status |
|-------|--------|--------|
| 2026-02-03 | Remove Platform Database | Accepted |
| 2026-02-04 | AI Services DSL Migration | Proposed |

**Location:** `.claude/planning/decisions/`

---

## Architecture (architecture/)

Arhitekturni dokumenti i dizajn odluke.

| Dokument | Opis |
|----------|------|
| `2025-01-15-dsl-first-architecture.md` | DSL-First pristup |
| `2025-01-15-implementation-decisions.md` | Ključne implementacijske odluke |

---

## Testing (testing/)

Test planovi, scenariji i coverage ciljevi.

| Dokument | Opis |
|----------|------|
| `BRAIN_TEST_SCENARIOS.md` | Scenariji za testiranje Platform Brain-a (1240+ linija) |

---

## Archive (archive/)

Stari dokumenti za referencu. Ne koristi za aktivni development.

| Dokument | Razlog arhiviranja |
|----------|-------------------|
| `PLATFORM_V1.md` | Prva verzija Platform plana |
| `AI_ARCHITECTURE_PROMPT.md` | Originalna ideja za AI arhitekturu |
| `PLAN_CONTENT_ORCHESTRATOR.md` | Stari ContentOrchestrator pristup |
| `NEW_OLD_PLAN.md` | Stari plan razvoja |
| `TECH_DEBT_REVIEW_2026_01_15.md` | Coverage cilj 50% dostignut |
| `ADR-2026-01-16-executor-simplification.md` | Zamijenjeno restore ADR-om |
| `TEST_COVERAGE_70_PLAN.md` | Zastarjeli coverage plan |
| `DSL_VALIDATION_PLAN.md` | Neimplementirana funkcionalnost |

---

## Quick Reference

### Za Tech Lead-a
```
1. VISION.md → Arhitektura
2. architecture/ → Dizajn odluke
3. adr/ → Tehničke odluke
```

### Za Product Manager-a
```
1. VISION.md → Vizija
2. IMPLEMENTATION.md → Prioriteti
```

### Za Developer-a
```
1. IMPLEMENTATION.md → Trenutna faza
2. testing/ → Test planovi
3. DEVELOPER_ONBOARDING.md → Setup
4. decisions/ → Migration plans i product odluke
```

---

## Trenutno stanje

**Kompletne faze:**
- Faza 1-4: Core + Knowledge Layers

**Sljedeća faza:** Faza 5 - External Data Integration

**Arhitektura:** DSL-First (ADR: 2025-01-15)

---

*Zadnje ažuriranje: 2026-02-04*
