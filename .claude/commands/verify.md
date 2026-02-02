# /verify

Verifikuj da kod radi ispravno.

**Agent:** Developer

## Korištenje

```
/verify                    # Puna verifikacija
/verify --quick            # Brza provjera (lint + unit tests)
/verify --file [path]      # Verifikuj specifični fajl
```

## Šta provjerava

### 1. Sintaksa
```bash
ruby -c app/models/location.rb
```

### 2. Rails učitavanje
```bash
bin/rails runner "puts 'OK'"
```

### 3. Testovi
```bash
bin/rails test
```

### 4. Routes
```bash
bin/rails routes | head -20
```

### 5. Database
```bash
bin/rails db:migrate:status
```

### 6. Assets (ako relevantno)
```bash
bin/rails assets:precompile --dry-run
```

## Verifikacija specifičnog fajla

### Model
```ruby
# Učitaj model
Location

# Provjeri validacije
l = Location.new
l.valid?
l.errors.full_messages

# Provjeri query
Location.first
Location.count
```

### Controller
```bash
# Provjeri route
bin/rails routes | grep locations

# Pokreni controller test
bin/rails test test/controllers/locations_controller_test.rb
```

### Service
```ruby
# Učitaj service
MyService.new

# Pokreni test
bin/rails test test/services/my_service_test.rb
```

## Output

```
## Verifikacija

### Sintaksa
✓ Svi Ruby fajlovi validni

### Rails
✓ Aplikacija se učitava

### Testovi
✓ 150 tests, 0 failures

### Routes
✓ 45 routes definisano

### Database
✓ Sve migracije primijenjene

---
✓ Sve provjere prošle
```

## Quick mode

```
/verify --quick

### Quick Verify
✓ Sintaksa OK
✓ Rails loads
✓ Unit tests pass (2.3s)
```
