# Tech Lead Review - 2026-01-15

## Status: Action Required

**Reviewer:** Tech Lead
**Za:** Developer
**Prioritet:** P0 - Kritično

---

## Izvršni sažetak

Platform implementacija (17 faza) je kompletna i funkcionalna. Međutim, test coverage je **35.18%** što je ispod prihvatljivog minimuma za production code. Developer treba povećati coverage na **minimum 50%** prije merga u main.

---

## Trenutno stanje

| Metrika | Vrijednost | Cilj | Status |
|---------|------------|------|--------|
| Line Coverage | 35.18% | 50%+ | ❌ |
| Branch Coverage | 36.28% | 50%+ | ❌ |
| Test Count | 1099 | - | ✅ |
| Test Failures | 0 | 0 | ✅ |
| ERB Linting | None | HERB | ⚠️ P2 |

---

## Zadaci za Developer-a

### P0 - MORA SE URADITI

#### 1. Povećati test coverage na 50%+

**Prioritetne oblasti (po važnosti):**

1. **Platform API Controller** (`app/controllers/api/platform_controller.rb`)
   - Chat endpoint
   - Execute endpoint
   - Streaming functionality
   - Error handling

2. **Curator Controllers** (`app/controllers/curator/`)
   - Dashboard
   - Proposals
   - Reviews
   - Admin namespace

3. **Core Services** (`app/services/`)
   - AI services (LocationEnricher, ExperienceCreator, PlanCreator)
   - Any uncovered service classes

4. **Platform Core** (`lib/platform/`)
   - MCP Server
   - CLI (if testable)
   - Any uncovered modules

**Kako provjeriti coverage:**
```bash
COVERAGE=true bin/rails test
open coverage/index.html
```

**Kako vidjeti šta nije pokriveno:**
```bash
# Coverage report će pokazati uncovered lines
# Fokusiraj se na files sa <50% coverage
```

---

### P1 - SLJEDEĆI SPRINT

#### 2. ERB Linting (HERB ili erb_lint)

**Problem:** 8166 linija ERB bez static analysis.

**Opcije:**
- HERB: https://github.com/marcoroth/herb
- erb_lint: https://github.com/Shopify/erb-lint

**Koraci:**
1. Dodaj gem u Gemfile (development/test group)
2. Konfigurisi linter
3. Dodaj u CI workflow
4. Fiksaj sve warnings

---

## Kriterij za completion

- [ ] Line coverage >= 50%
- [ ] Branch coverage >= 50%
- [ ] Svi testovi prolaze (0 failures, 0 errors)
- [ ] CI prolazi

---

## Korisne komande

```bash
# Run tests with coverage
COVERAGE=true bin/rails test

# Run specific test file
bin/rails test test/controllers/api/platform_controller_test.rb

# Run tests matching pattern
bin/rails test -n /platform/

# View coverage report
open coverage/index.html

# Check which files have low coverage
# Look at coverage/index.html for red/yellow files
```

---

## Napomene

1. **Ne žuri** - Bolje kvalitetni testovi nego brzi
2. **Testiraj edge cases** - Ne samo happy path
3. **Mock external APIs** - RubyLLM, ElevenLabs, Geoapify
4. **Pitaj ako zapneš** - Tech Lead je tu da pomogne

---

**Deadline:** Prije merge u main
**Kontakt:** Tech Lead
