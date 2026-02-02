# /rfc

Kreiraj Request for Comments za veće promjene.

**Agent:** Product Manager + Tech Lead

## Korištenje

```
/rfc [naslov]
/rfc "Novi sistem za audio ture"
```

## Kada koristiti RFC

- Veće arhitekturne promjene
- Nove features koje utiču na više sistema
- Promjene API-ja
- Promjene data modela

## Proces

### 1. Problem statement

Pitaj:
- Koji problem rješavamo?
- Ko je affected?
- Zašto je važno riješiti sada?

### 2. Proposed solution

- High-level dizajn
- Komponente
- Data flow
- API dizajn

### 3. Alternatives

- Koje druge opcije postoje?
- Zašto je predloženo rješenje bolje?

### 4. Kreiraj RFC

Lokacija: `.claude/planning/rfcs/NNNN-[slug].md`

```markdown
# RFC-NNNN: [Naslov]

## Summary
Jedan paragraf koji opisuje promjenu.

## Motivation
Zašto ovo radimo? Koji problem rješavamo?

## Detailed Design

### Overview
High-level opis.

### Data Model
```ruby
# Novi modeli ili promjene
```

### API Changes
```ruby
# Novi endpoints ili promjene
```

### UI Changes
Wireframes ili opisi.

## Drawbacks
Zašto NE bismo ovo radili?

## Alternatives
Koje druge opcije smo razmatrali?

## Unresolved Questions
Šta još treba odlučiti?

## Implementation Plan
1. Faza 1: ...
2. Faza 2: ...
```

## Output

```
Kreiran RFC: .claude/planning/rfcs/NNNN-[slug].md

## RFC-NNNN: [Naslov]

Summary: [kratki opis]

Komponente:
- [komponenta 1]
- [komponenta 2]

Sljedeći koraci:
1. Review od tima
2. ADR za ključne odluke
3. Implementation plan
```
