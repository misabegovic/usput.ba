# Developer Onboarding - Usput.ba Platform

Dobrodošao u tim. Ovaj dokument ti daje sve što trebaš da počneš produktivno raditi.

---

## Brzi start

```bash
# Setup
bundle install
bin/rails db:setup

# Pokreni development server
bin/dev

# Pokreni testove
bin/rails test

# Pokreni specifičan test
bin/rails test test/models/location_test.rb

# Rails console
bin/rails console
```

---

## Produkcijska infrastruktura

```
┌─────────────────────────────────────────────────────┐
│                   PRODUCTION                         │
├─────────────────────────────────────────────────────┤
│  2 instance (web + background workers)               │
│                                                      │
│  2 baze podataka:                                    │
│    - Primary DB (aplikacijski podaci)                │
│    - Queue DB (Solid Queue jobs)                     │
│                                                      │
│  Deploy: Automatski pri merge u main                 │
└─────────────────────────────────────────────────────┘
```

**Zapamti:** Nema instant rollback-a. Svaki merge u main ide direktno u produkciju.

---

## Tech Stack

| Tehnologija | Svrha | Dokumentacija |
|-------------|-------|---------------|
| Ruby 3.3+ | Jezik | |
| Rails 8 | Framework | guides.rubyonrails.org |
| PostgreSQL | Primary DB | |
| pgvector | Semantic search | |
| Solid Queue | Background jobs | već konfigurisano |
| RubyLLM | Claude API wrapper | |
| Thor | CLI commands | |
| Stimulus | JavaScript | stimulus.hotwired.dev |
| Tailwind CSS | Styling | `.claude/planning/TAILWIND_GUIDE.md` |

---

## Coding standardi

### Ruby / Rails

```ruby
# ✅ DOBRO - Service object sa jasnom odgovornošću
class LocationEnricher
  def initialize(location)
    @location = location
  end

  def call
    enrich_description
    enrich_coordinates
    @location
  end

  private

  def enrich_description
    # ...
  end
end

# ❌ LOŠE - God object sa previše odgovornosti
class LocationManager
  def create_and_enrich_and_translate_and_notify(params)
    # 500 linija koda...
  end
end
```

### JavaScript = Stimulus ONLY

```javascript
// ✅ DOBRO - Stimulus controller
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
```

```erb
<!-- Korištenje u view-u -->
<div data-controller="dropdown">
  <button data-action="click->dropdown#toggle">Menu</button>
  <div data-dropdown-target="menu" class="hidden">
    <!-- menu items -->
  </div>
</div>
```

```javascript
// ❌ LOŠE - Vanilla JS u view-u
<script>
  document.getElementById('btn').onclick = function() {
    // NIKAD OVO
  }
</script>

// ❌ LOŠE - jQuery
$('#btn').click(function() {
  // NIKAD OVO
});
```

### SOLID principi

**S - Single Responsibility**
```ruby
# ✅ Jedna klasa, jedna odgovornost
class LocationGeocoder
  def call(location)
    # samo geocoding
  end
end

class LocationDescriptionGenerator
  def call(location)
    # samo generisanje opisa
  end
end
```

**O - Open/Closed**
```ruby
# ✅ Extendable bez modifikacije
class ContentExporter
  def export(content, formatter:)
    formatter.format(content)
  end
end

class JsonFormatter
  def format(content) = content.to_json
end

class CsvFormatter
  def format(content) = content.to_csv
end
```

**D - Dependency Inversion**
```ruby
# ✅ Zavisi od abstrakcije
class LocationService
  def initialize(geocoder: GeoapifyGeocoder.new)
    @geocoder = geocoder
  end

  def enrich(location)
    @geocoder.geocode(location.address)
  end
end

# U testu možeš zamijeniti sa mock-om
LocationService.new(geocoder: MockGeocoder.new)
```

---

## Testiranje

### Obavezno
- **Svaki novi kod MORA imati test**
- Undercover gem će hvatati nepokriveni kod
- Tech Lead neće approvati PR bez testova

### Struktura testa
```ruby
# test/models/location_test.rb
require "test_helper"

class LocationTest < ActiveSupport::TestCase
  # Setup - priprema podataka
  setup do
    @location = locations(:mostar_old_bridge)
  end

  # Opisni naziv testa
  test "validates presence of name" do
    @location.name = nil
    assert_not @location.valid?
    assert_includes @location.errors[:name], "can't be blank"
  end

  test "geocodes address on create" do
    location = Location.create!(
      name: "Test",
      address: "Sarajevo, BiH"
    )

    assert_not_nil location.latitude
    assert_not_nil location.longitude
  end
end
```

### Pokretanje testova
```bash
# Svi testovi
bin/rails test

# Specifičan file
bin/rails test test/models/location_test.rb

# Specifičan test (po liniji)
bin/rails test test/models/location_test.rb:15

# Sa verbose outputom
bin/rails test -v
```

---

## Git workflow

### Branch naming
```
feature/add-location-search
fix/geocoding-timeout
refactor/location-service
```

### Commit poruke
```
[Platform] Add search_content tool

- Implemented full-text search via Browse model
- Added type and city filters
- Added tests for all scenarios
```

### PR checklist
- [ ] Testovi prolaze (`bin/rails test`)
- [ ] Nema Rubocop grešaka
- [ ] Stimulus za sav JS
- [ ] Bez hardcodiranih stringova (koristi I18n)
- [ ] Dokumentacija ako je potrebna

---

## Folder struktura

```
app/
├── controllers/          # Rails controlleri
├── models/               # ActiveRecord modeli
├── views/                # ERB templates
├── jobs/                 # Solid Queue jobs
├── services/             # Business logic
└── javascript/
    └── controllers/      # Stimulus controlleri

lib/
└── platform/             # Platform AI sistem
    ├── cli.rb            # Thor CLI
    ├── brain.rb          # RubyLLM wrapper
    ├── conversation.rb   # Session management
    └── tools/            # Atomic tools
        ├── base.rb
        ├── content/      # Content CRUD
        ├── external/     # Geoapify, etc.
        └── generate/     # AI generation

test/
├── models/
├── controllers/
├── services/
└── lib/
    └── platform/
```

---

## Quality tools

### Rubocop
```bash
# Provjeri stil
bundle exec rubocop

# Auto-fix gdje je moguće
bundle exec rubocop -a
```

### Undercover (test coverage)
```bash
# Provjeri coverage za izmijenjene fajlove
bundle exec undercover
```

### HERB (ERB linting)
```bash
# Lint ERB fajlove
bundle exec herb lint
```

---

## Česti problemi

### "Test fails in CI but passes locally"
- Provjeri da nemaš hardcodirane ID-eve
- Provjeri date/time dependent testove
- Koristi fixtures, ne factory_bot za speed

### "Geocoding ne radi"
- Geoapify ima rate limit: 5 req/sec
- Provjeri da imaš API key u credentials

### "Background job ne radi"
- Provjeri da Solid Queue radi: `bin/rails solid_queue:start`
- Provjeri queue bazu

---

## Komunikacija sa Tech Lead-om

### Kad pitati
- Arhitekturne odluke
- Nejasna specifikacija
- Trade-off odluke
- Blocked situacije

### Format pitanja
```
## Problem
[Šta pokušavam uraditi]

## Kontekst
[Relevantne informacije]

## Opcije koje sam razmotrio
1. [Opcija A] - pros/cons
2. [Opcija B] - pros/cons

## Pitanje
[Konkretno pitanje]
```

---

## Dokumentacija

| Dokument | Svrha |
|----------|-------|
| `.claude/planning/README.md` | Index svih dokumenata |
| `.claude/planning/VISION.md` | Arhitektura Platform-a |
| `.claude/planning/IMPLEMENTATION.md` | Faze implementacije |
| `.claude/planning/TAILWIND_GUIDE.md` | Tailwind CSS komponente |

---

## Tvoja pravila

1. **Testovi su obavezni** - Nema koda bez testova
2. **Stimulus za JS** - Nikad vanilla JS
3. **Pitaj kad nisi siguran** - Nema glupih pitanja
4. **Small PRs** - Lakše za review, brži feedback
5. **Čitaj dokumentaciju** - `.claude/planning/` folder
