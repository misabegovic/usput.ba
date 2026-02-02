# /simplify

Pojednostavi kod bez promjene funkcionalnosti.

**Agent:** Tech Lead + Developer

## Korištenje

```
/simplify [file]
/simplify app/services/ai/content_orchestrator.rb
/simplify --method MyClass#my_method
```

## Šta tražiti

### 1. Kompleksnost
- Preduge metode (>20 linija)
- Duboko ugnježđenje (>3 nivoa)
- Previše parametara (>4)

### 2. Duplikacija
- Copy-paste kod
- Slična logika na više mjesta

### 3. Dead code
- Nekorištene metode
- Zakomentirani kod
- Unreachable code

### 4. Over-engineering
- Nepotrebne abstrakcije
- Previše klasa za jednostavan problem
- Generalizacija koja nije potrebna

## Proces

### 1. Analiziraj fajl
```ruby
# Metrике
- Broj linija
- Broj metoda
- Prosječna dužina metode
- Cyclomatic complexity
```

### 2. Identificiraj probleme
```markdown
## Problemi

1. **Metoda `process` preduga** (45 linija)
   - Može se podijeliti na 3 manje metode

2. **Duplikacija u `validate_*` metodama**
   - Izvuci common logic u helper

3. **Nekorištena metoda `legacy_import`**
   - Može se obrisati
```

### 3. Predloži refaktoring
```markdown
## Predložene promjene

### Prije
```ruby
def process(data)
  # 45 linija kompleksnog koda
end
```

### Poslije
```ruby
def process(data)
  validated = validate(data)
  transformed = transform(validated)
  save(transformed)
end

private

def validate(data)
  # 10 linija
end

def transform(data)
  # 15 linija
end

def save(data)
  # 10 linija
end
```

### 4. Implementiraj

- Napravi promjene inkrementalno
- Pokreni testove nakon svake promjene
- Održi istu funkcionalnost

## Pravila

- **Ne mijenjaj ponašanje** - samo strukturu
- **Testovi moraju prolaziti** - prije i poslije
- **Inkrementalno** - male promjene
- **Dokumentuj** - zašto je promjena napravljena

## Output

```
## Simplifikacija: [file]

### Prije
- Linije: 245
- Metode: 12
- Avg metoda: 20 linija
- Kompleksnost: visoka

### Promjene
1. Podijeljena `process` metoda (45→3x15)
2. Izvučen `ValidationHelper` modul
3. Obrisana `legacy_import` (nekorištena)

### Poslije
- Linije: 198 (-47)
- Metode: 15
- Avg metoda: 13 linija
- Kompleksnost: srednja

### Testovi
✓ 24 tests, 0 failures

Commit? [y/n]
```
