# /add-location

Dodaj novu lokaciju sa AI-generiranim opisima.

**Agent:** Content Director, Curator

## Korištenje

```
/add-location [ime], [grad]
/add-location Stari Most, Mostar
```

## Potrebni podaci

Pitaj korisnika za:
1. **Ime lokacije** (obavezno)
2. **Grad** (obavezno)
3. **Tip** - monument, nature, religious, museum, etc.
4. **Kratki opis** - za kontekst AI generaciji

## DSL komande

### Provjeri duplikate
```
locations | where(name: "Stari Most") | select(name, city, status)
locations | search("Stari Most") | limit(5)
```

### Provjeri grad
```
locations | where(city: "Mostar") | count
```

### Nakon kreiranja - provjeri
```
locations | where(name: "Nova Lokacija") | first
```

## Proces

### 1. Provjeri duplikate (DSL)

### 2. Prikupi informacije
- Koristi historian agenta za historijski kontekst
- Koristi guide agenta za praktične info

### 3. Generiši sadržaj
- Opis na bosanskom (150-200 riječi)
- Historijski kontekst (ako relevantno)
- Prijevodi (EN, DE, HR)

### 4. Kreiraj lokaciju
Predaj podatke Content Director agentu ili develoeru za kreiranje.

## Output

```
## Nova lokacija: [ime]

### Podaci
- Grad: [grad]
- Tip: [tip]
- Koordinate: [lat, lng]

### Opis (BS)
[generisani opis]

### Historijski kontekst
[kontekst]

---
Spreman za kreiranje. Nastavi? [y/n]
```

## Napomena

Ova komanda priprema sadržaj. Samo kreiranje u bazi radi developer ili kroz curator dashboard.
