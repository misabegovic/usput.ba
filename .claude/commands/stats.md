# /stats

Prikaži statistike baze podataka.

**Agent:** Curator, Content Director

## Korištenje

```
/stats
/stats locations
/stats regions
```

## DSL komande

### Osnovne statistike
```
schema | stats
```

### Lokacije
```
locations | count
locations | where(status: "published") | count
locations | where(status: "draft") | count
locations | group_by(city) | count | order(count: desc) | limit(15)
locations | group_by(location_type) | count
```

### Iskustva
```
experiences | count
experiences | where(status: "published") | count
experiences | group_by(category) | count
experiences | group_by(city) | count | order(count: desc)
```

### Planovi
```
plans | count
plans | where(status: "published") | count
plans | group_by(city) | count
```

### Kvaliteta
```
locations | where(description: nil) | count
locations | where(latitude: nil) | count
experiences | where(locations_count: 0) | count
```

### Audio ture
```
audio_tours | count
audio_tours | group_by(locale) | count
```

## Output format

```
## Usput.ba Statistike

### Sadržaj
| Tip | Ukupno | Objavljeno | Draft |
|-----|--------|------------|-------|
| Lokacije | X | Y | Z |
| Iskustva | X | Y | Z |
| Planovi | X | Y | Z |

### Top 10 gradova
| Grad | Lokacije | Iskustva |
|------|----------|----------|
| Sarajevo | X | Y |
| Mostar | X | Y |
| Banja Luka | X | Y |
...

### Kvaliteta
- Lokacije bez opisa: X
- Lokacije bez koordinata: Y
- Iskustva bez lokacija: Z

### Audio ture
| Jezik | Broj |
|-------|------|
| BS | X |
| EN | Y |
| DE | Z |
```

## Platform CLI

Alternativno, koristi direktno:
```bash
bin/platform exec 'schema | stats'
bin/platform exec 'locations | count'
```
