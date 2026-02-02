# /quality-audit

Provjeri kvalitetu sadržaja u bazi.

**Agent:** Content Director, Curator

## DSL komande

### Lokacije bez opisa
```
locations | where(description: nil) | count
locations | where(description: nil) | select(name, city) | limit(20)
```

### Lokacije bez koordinata
```
locations | where(latitude: nil) | count
locations | where(latitude: nil) | select(name, city)
```

### Iskustva bez lokacija
```
experiences | where(locations_count: 0) | count
experiences | where(locations_count: 0) | select(title, city)
```

### Iskustva bez opisa
```
experiences | where(description: nil) | count
```

### Planovi bez iskustava
```
plans | where(experiences_count: 0) | count
```

### Statistike po gradovima
```
locations | group_by(city) | count | order(count: desc) | limit(15)
experiences | group_by(city) | count | order(count: desc)
```

### Regionalni balans
```
locations | stats
experiences | stats
```

## Output format

```
## Quality Audit Report

### Lokacije (ukupno: X)
- Bez opisa: Y
- Bez koordinata: Z

### Iskustva (ukupno: X)
- Bez lokacija: Y ⚠️
- Bez opisa: Z

### Top gradovi
| Grad | Lokacije | Iskustva |
|------|----------|----------|
| Sarajevo | X | Y |
| Mostar | X | Y |

### Preporuke
1. Generiši opise za X lokacija
2. Dodaj lokacije za Y iskustava
```

## Akcije

Nakon audita, ponudi:
1. `/add-location` za nove lokacije
2. `/translate` za prijevode
