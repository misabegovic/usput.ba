# /translate

Prevedi sadržaj na sve podržane jezike.

**Agent:** Content Director

## Podržani jezici

- `bs` - Bosanski (primary)
- `en` - English
- `de` - Deutsch
- `hr` - Hrvatski

## Korištenje

```
/translate location [ime]
/translate experience [naslov]
/translate --missing
```

## DSL komande

### Pronađi resurse bez prijevoda
```
locations | where(translations_missing: true) | count
locations | where(translations_missing: true) | select(name, city) | limit(10)

experiences | where(translations_missing: true) | count
experiences | where(translations_missing: true) | select(title) | limit(10)
```

### Pronađi specifični resurs
```
locations | where(name: "Stari Most") | first
experiences | where(title: "Mostarska čaršija") | first
```

### Provjeri postojeće prijevode
```
locations | where(name: "Stari Most") | translations
```

## Proces

### 1. Identificiraj resurse (DSL)

### 2. Za svaki resurs generiši prijevode

Pravila:
- Zadrži ton i stil originala
- Za bosanski: ijekavica, "historija" ne "istorija"
- Za njemački: formalni stil (Sie)
- Ne prevodi vlastita imena mjesta

### 3. Provjeri kvalitetu

- Dužina slična originalu
- Ključne informacije zadržane
- Kulturno prilagođeno

## Output

```
## Prijevod: [resurs]

### Original (BS)
[originalni tekst]

### English
[prijevod]

### Deutsch
[prijevod]

### Hrvatski
[prijevod]

---
Spremi prijevode? [y/n]
```

## Batch prijevod

```
/translate --missing

## Resursi bez prijevoda
- Lokacije: X
- Iskustva: Y

Prevesti sve? [y/n]
```
