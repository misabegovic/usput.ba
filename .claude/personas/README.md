# Claude Personas za Usput.ba Platform

Tri persone za različite aspekte razvoja Platform-a.

## Prije početka - OBAVEZNO

```
Svaka persona treba pročitati:

📁 .claude/planning/README.md  - Index svih planova i dokumentacije
```

Svi planovi su u `.claude/planning/` folderu. README.md služi kao index.

## Persone

### 1. Tech Lead (`tech-lead.md`)
Tehnički vodja projekta.

**Koristi kad:**
- Trebaš arhitekturnu odluku
- Trebaš code review
- Imaš tehnički problem
- Trebaš smjernice za implementaciju

**Primjer prompt:**
```
Pročitaj .claude/personas/tech-lead.md i preuzmi tu personu.

Pitanje: Kako da strukturiram Platform tools?
```

### 2. Product Manager (`product-manager.md`)
Product vodja projekta.

**Koristi kad:**
- Trebaš definirati feature
- Trebaš user story
- Trebaš prioritizaciju
- Trebaš acceptance criteria

**Primjer prompt:**
```
Pročitaj .claude/personas/product-manager.md i preuzmi tu personu.

Pitanje: Koje su ključne funkcionalnosti za MVP?
```

### 3. Developer (`developer.md`)
Senior AI Developer (hamal).

**Koristi kad:**
- Trebaš implementaciju
- Trebaš napisati kod
- Trebaš napisati testove
- Trebaš debugovati

**Primjer prompt:**
```
Pročitaj .claude/personas/developer.md i preuzmi tu personu.

Task: Implementiraj search_content tool prema specifikaciji.
```

## Workflow

### Solo development
```
1. Koristi PM personu za definisanje feature-a
2. Koristi Tech Lead personu za tehničke smjernice
3. Koristi Developer personu za implementaciju
4. Koristi Tech Lead personu za review
```

### Sa više Claude instanci
```
Terminal 1 (Tech Lead):
$ claude --prompt "Pročitaj .claude/personas/tech-lead.md i preuzmi tu personu."

Terminal 2 (PM):
$ claude --prompt "Pročitaj .claude/personas/product-manager.md i preuzmi tu personu."

Terminal 3 (Developer):
$ claude --prompt "Pročitaj .claude/personas/developer.md i preuzmi tu personu."
```

## Brzi pristup

### Claude Code komande
```bash
# Tech Lead
claude "Pročitaj .claude/personas/tech-lead.md. [tvoje pitanje]"

# Product Manager
claude "Pročitaj .claude/personas/product-manager.md. [tvoje pitanje]"

# Developer
claude "Pročitaj .claude/personas/developer.md. [tvoj task]"
```

### Kombinovano (multi-persona session)
```
Pročitaj sve persone iz .claude/personas/ direktorija.
Kada te pitam sa prefiksom [TL], odgovori kao Tech Lead.
Kada te pitam sa prefiksom [PM], odgovori kao Product Manager.
Kada te pitam sa prefiksom [DEV], odgovori kao Developer.
```

## Primjer full workflow

```
[PM] Definiši user story za search funkcionalnost.

[TL] Kako da arhitekturno strukturiram search?
     Imamo Browse model sa tsvector.

[DEV] Implementiraj search tool prema ovoj specifikaciji:
      - Query parameter obavezan
      - Optional: type, city, limit
      - Koristi Browse.search

[TL] Review ovaj kod: [code]
```
