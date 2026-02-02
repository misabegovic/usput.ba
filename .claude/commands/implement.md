# /implement

Implementiraj feature ili task.

**Agent:** Developer

## Korištenje

```
/implement [opis]
/implement "Dodaj search za lokacije"
/implement --from-issue 123
```

## Proces

### 1. Razumijevanje zadatka

- Pročitaj opis/issue
- Identifikuj acceptance criteria
- Pitaj za pojašnjenja ako treba

### 2. Istraži codebase

```
- Gdje se slična funkcionalnost već koristi?
- Koji patterns pratiti?
- Koje fajlove trebam modificirati?
```

### 3. Napravi plan

```markdown
## Implementation Plan

### Fajlovi za kreiranje
- [ ] app/services/search_service.rb
- [ ] test/services/search_service_test.rb

### Fajlovi za modifikaciju
- [ ] app/controllers/locations_controller.rb
- [ ] app/views/locations/index.html.erb

### Koraci
1. Kreiraj service
2. Dodaj controller action
3. Updatuj view
4. Napiši testove
```

### 4. Implementiraj

Za svaki fajl:
1. Pročitaj postojeći kod
2. Napravi promjene
3. Prati postojeće patterns

### 5. Testovi

```bash
bin/rails test [test_file]
```

### 6. Verifikacija

```bash
bin/rails test
bin/rails runner "puts 'OK'"
```

## Pravila

- **Prati patterns** - koristi postojeće obrasce
- **Minimalne promjene** - ne refaktoruj nepotrebno
- **Testovi obavezni** - svaka feature ima test
- **Inkrementalno** - mali commitovi

## Output

```
## Implementacija: [opis]

### Kreirano
- app/services/search_service.rb (45 linija)
- test/services/search_service_test.rb (30 linija)

### Modificirano
- app/controllers/locations_controller.rb (+12 linija)

### Testovi
✓ 5 tests, 12 assertions, 0 failures

Commit? [y/n]
```
