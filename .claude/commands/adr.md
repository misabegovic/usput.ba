# /adr

Kreiraj Architecture Decision Record.

**Agent:** Tech Lead

## Korištenje

```
/adr [naslov]
/adr "Koristi PostgreSQL umjesto MySQL"
```

## Proces

### 1. Prikupi kontekst

Pitaj za:
- Koja odluka se donosi?
- Koje su opcije razmatrane?
- Koji su constraints?

### 2. Analiziraj opcije

Za svaku opciju:
- Prednosti
- Mane
- Trade-offs
- Rizici

### 3. Kreiraj ADR

Lokacija: `.claude/planning/decisions/NNNN-[slug].md`

```markdown
# ADR-NNNN: [Naslov]

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
Zašto ova odluka mora biti donesena?

## Decision
Šta smo odlučili?

## Consequences

### Positive
- ...

### Negative
- ...

### Neutral
- ...

## Alternatives Considered

### Opcija 1: [ime]
- Prednosti: ...
- Mane: ...
- Zašto odbačeno: ...

### Opcija 2: [ime]
...

## References
- Link 1
- Link 2
```

### 4. Ažuriraj index

Dodaj u `.claude/planning/decisions/README.md`:
```markdown
| NNNN | [Naslov] | [Status] | [Datum] |
```

## Primjeri ADR-ova

- `0001-use-dsl-first-architecture.md`
- `0002-choose-parslet-for-dsl.md`
- `0003-pgvector-for-embeddings.md`

## Output

```
Kreiran ADR: .claude/planning/decisions/NNNN-[slug].md

## ADR-NNNN: [Naslov]
Status: Proposed
Datum: YYYY-MM-DD

Odluka: [summary]

Prihvati? [y/n]
```
