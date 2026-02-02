# ADR: Full Introspection in P0

**Datum:** 2025-01-15
**Status:** Accepted
**Učesnici:** PM, Tech Lead, Product Owner

---

## Kontekst

Originalni plan je imao Introspection (čitanje koda, logova) i Self-Improvement (priprema fix promptova) kao P2 prioritet - "nice to have" funkcionalnosti koje dolaze nakon core content generation-a.

Product Owner je zatražio da ove funkcionalnosti budu dio P0 - core funkcionalnosti Platform-a.

---

## Odluka

**Introspection i Self-Improvement su P0 prioritet.**

Platform koji ne razumije sebe nije pravi "mozak". Self-analysis je core funkcionalnost, ne dodatak.

---

## Promjene u prioritetima

### Prije (P0 = Faze 1-9)
```
P0: Core, Knowledge Layer, Content, Audio, Generation Workflow
P1: Approval, Curator Management
P2: Introspection, Self-Improvement, Remote Access  ← ovdje je bilo
P3: Admin Mode, Cleanup
```

### Poslije (P0 = Faze 1-11)
```
P0: Core, Knowledge Layer, Content, Audio, Generation Workflow,
    Introspection, Self-Improvement  ← POMJERENO OVDJE
P1: Approval, Curator Management
P2: Remote Access
P3: Admin Mode, Cleanup
```

---

## Šta Introspection uključuje

### Code Analysis
```
code | read_file "app/models/location.rb"
code | search "def generate"
code | list_files { path: "app/models" }
code | analyze_complexity { path: "app/services" }
```

### Log Analysis
```
logs | errors { last: "24h" }
logs | slow_queries { threshold: 1000ms }
logs | exceptions { last: "7d" }
logs | api_failures { service: "geoapify" }
```

### Infrastructure Monitoring
```
infrastructure | queue_status
infrastructure | database_health
infrastructure | memory_usage
infrastructure | response_times
infrastructure | job_failures { last: "24h" }
```

---

## Šta Self-Improvement uključuje

### Priprema Fix Promptova
```
prepare fix for "N+1 query in LocationsController"
prepare fix for "Memory leak in AudioGenerator"
```

### Priprema Feature Promptova
```
prepare feature "Add rating to locations"
prepare migration "Add index on locations.city"
```

### Upravljanje Promptovima
```
prompts | list { status: "pending" }
prompts { id: 123 } | show
prompts { id: 123 } | mark_executed
```

---

## Posljedice

### Pozitivne
- Platform je self-aware od prvog dana
- Može identificirati probleme prije nego postanu kritični
- Admin ima uvid u zdravlje sistema kroz razgovor
- Osnova za buduću automatizaciju (Platform predlaže fixeve)

### Negativne
- P0 scope je veći = duži timeline do MVP-a
- Više kompleksnosti u prvoj verziji
- Potreban pristup logovima i kodu (security consideration)

### Mitigacije
- Introspection je read-only (Platform ne mijenja kod direktno)
- Prepared prompts su samo prijedlozi - čovjek odlučuje da li ih izvršiti
- Log pristup može biti ograničen na production-safe queries

---

## Reference

- Faza 12 u IMPLEMENTATION.md: Introspection
- Faza 13 u IMPLEMENTATION.md: Self-Improvement
