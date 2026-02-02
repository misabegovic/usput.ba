# /add-experience

Dodaj novo iskustvo sa lokacijama i AI opisima.

**Agent:** Content Director, Curator, Guide

## Korištenje

```
/add-experience [naslov]
/add-experience "Mostarska čaršija tour"
```

## Potrebni podaci

1. **Naslov** (obavezno)
2. **Kategorija** - cultural, adventure, gastro, nature
3. **Lokacije** - lista lokacija koje uključuje
4. **Trajanje** - u satima
5. **Grad/Regija**

## DSL komande

### Pronađi lokacije za iskustvo
```
locations | where(city: "Mostar") | select(name, location_type) | limit(20)
locations | search("čaršija") | select(name, city)
```

### Provjeri kategorije
```
experience_categories | select(name, slug)
```

### Provjeri postojeća iskustva
```
experiences | where(city: "Mostar") | select(title, category)
experiences | search("čaršija") | limit(5)
```

### Nakon kreiranja
```
experiences | where(title: "Novo iskustvo") | first
```

## Proces

### 1. Pronađi lokacije (DSL)
Koristi search i where da pronađeš relevantne lokacije.

### 2. Provjeri balans
```
experiences | where(city: "Mostar") | count
experiences | group_by(category) | count
```

### 3. Generiši sadržaj

Koristi agente:
- **Guide** - praktične info, trajanje, savjeti
- **Robert** - zabavan opis
- **Historian** - historijski kontekst

### 4. Pripremi podatke

```
## Novo iskustvo

Naslov: [naslov]
Kategorija: [kategorija]
Trajanje: [X] sati
Grad: [grad]

Lokacije:
1. [Lokacija 1]
2. [Lokacija 2]
3. [Lokacija 3]

Opis:
[generisani opis 200-300 riječi]
```

## Validacija

Iskustvo MORA imati:
- Minimalno 2 lokacije
- Opis na BS
- Kategoriju
- Trajanje

## Output

```
## Novo iskustvo: [naslov]

### Podaci
- Kategorija: [kategorija]
- Lokacije: [count]
- Trajanje: [X] sati

### Opis
[generisani opis]

---
Spreman za kreiranje. Nastavi? [y/n]
```
