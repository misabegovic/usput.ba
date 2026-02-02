# /compact

Kompaktuj i sredi planning dokumentaciju.

**Agent:** Tech Lead + Product Manager

## Korištenje

```
/compact                           # Kompaktuj planning folder
/compact --review                  # Samo prikaži šta bi se promijenilo
/compact [dodatni kontekst]        # Uključi dodatne fajlove/info
```

## Primjeri

```
/compact
/compact "uključi i tmp/ skripte, ekstrahiraj korisne patterns"
/compact "dodaj learnings iz posljednje sesije"
/compact "arhiviraj sve vezano za staru admin dashboard implementaciju"
```

## Šta radi

### 1. Analiza trenutnog stanja

Prođi kroz sve u `.claude/planning/`:
- Koji dokumenti su aktivni i relevantni?
- Koji su zastarjeli ili duplikati?
- Šta nedostaje?

### 2. Kompaktovanje

Za svaki aktivan dokument:
- Ukloni redundantne sekcije
- Ažuriraj zastarjele informacije
- Spoji povezane dokumente ako ima smisla
- Zadrži samo actionable content

### 3. Arhiviranje

Premjesti u `archive/`:
- Dokumente koji više nisu relevantni
- Stare verzije koje su zamijenjene
- Completed planove (sa datumom)

### 4. Ekstrahiranje iz eksternih izvora

Ako je dat dodatni input:
- Ekstrahiraj relevantne patterns
- Dokumentuj learnings
- Dodaj u odgovarajući folder (adr/, architecture/, testing/)

## Proces

### Korak 1: Inventar
```
## Trenutni sadržaj

### Aktivni dokumenti
- VISION.md (45KB) - zadnji update: [datum]
- IMPLEMENTATION.md (22KB) - zadnji update: [datum]
...

### adr/
- 3 dokumenta

### architecture/
- 2 dokumenta

### testing/
- 3 dokumenta

### archive/
- 4 dokumenta
```

### Korak 2: Analiza

Za svaki dokument:
```
| Dokument | Status | Akcija |
|----------|--------|--------|
| VISION.md | Aktivan | Zadrži, ažuriraj sekciju X |
| TECH_DEBT_*.md | Zastarjelo | Arhiviraj |
| DSL_VALIDATION_*.md | Completed | Arhiviraj sa summary-jem |
```

### Korak 3: Prijedlog promjena
```
## Predložene promjene

### Arhivirati
- TECH_DEBT_REVIEW_2026_01_15.md → archive/
- testing/DSL_VALIDATION_PLAN.md → archive/ (completed)

### Ažurirati
- IMPLEMENTATION.md: ukloniti completed faze, dodati current status
- README.md: ažurirati stanje

### Kreirati
- adr/ADR-XXXX-new-decision.md (ako ekstrahirano iz inputa)

### Spojiti
- Nema prijedloga
```

### Korak 4: Izvršenje

Nakon potvrde:
1. Premjesti fajlove u archive/
2. Ažuriraj aktivne dokumente
3. Kreiraj nove ako treba
4. Ažuriraj README.md

## Ekstrahiranje iz dodatnog inputa

Ako korisnik da dodatni kontekst:

```
/compact "uključi learnings iz tmp/ skripti"
```

Proces:
1. Pročitaj navedene fajlove
2. Ekstrahiraj:
   - Korisne patterns
   - Odluke koje su donesene
   - Lessons learned
   - Reusable kod/logika
3. Dokumentuj u odgovarajućem formatu:
   - Patterns → architecture/
   - Odluke → adr/
   - Lessons → LEARNINGS.md ili archive/

## Output

```
## Compact Summary

### Arhivirano
- 2 dokumenta premještena u archive/

### Ažurirano
- IMPLEMENTATION.md (-500 linija, uklonjene completed faze)
- README.md (ažuriran status)

### Kreirano
- adr/ADR-2026-02-02-cleanup-patterns.md

### Statistike
- Prije: 15 dokumenata, 180KB
- Poslije: 12 dokumenata, 145KB
- Redukcija: 20%

---
Dokumentacija kompaktovana.
```

## Pravila

1. **Ne briši** - samo arhiviraj
2. **Zadrži historiju** - stavi datum u archive filename
3. **Pitaj prije** - prikaži plan prije izvršenja
4. **Dokumentuj** - svaka promjena ima razlog
5. **Fokus na actionable** - zadrži samo ono što pomaže u radu
