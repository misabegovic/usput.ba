# DSL Validation Layer - Implementation Plan

**Datum:** 2026-01-21
**Problem:** AI content creation bez validacije stvara halucinacije (lokacije koje ne postoje, pogrešni gradovi, duplikati)
**Rješenje:** Unaprijediti DSL da enforcea validaciju za SVE kategorije sadržaja

---

## Pregled - Šta treba implementirati

### Nove DSL komande:

| Komanda | Prioritet | Opis |
|---------|-----------|------|
| `validate location { name, city }` | P0 | Validira lokaciju prije kreiranja |
| `validate experience from locations [...]` | P0 | Validira iskustvo prije kreiranja |
| `quality audit` | P0 | Sveobuhvatan audit kvalitete |
| `scan suspicious patterns` | P1 | Skenira bazu za halucinacije |
| `find duplicates for location { name }` | P1 | Pronalazi duplikate |
| `verify location { id }` | P2 | Web verifikacija lokacije |
| `add locations [...] to experience { id }` | P1 | Dodaje lokacije iskustvu |

### Validacijski sloj u postojećim komandama:

| Komanda | Dodati validaciju |
|---------|-------------------|
| `create location` | Automatska validacija prije kreiranja |
| `generate experience` | Validacija svih lokacija prije generisanja |
| `generate description` | Provjera halucinacija u generiranom tekstu |
| `generate translations` | Provjera konzistentnosti prijevoda |

---

## Arhitektura

### Nova klasa: `Platform::DSL::ContentValidator`

```ruby
# lib/platform/dsl/content_validator.rb
module Platform::DSL
  class ContentValidator
    # Validacija pojedinačne lokacije
    def self.validate_location(name:, city:)
      result = ValidationResult.new

      # 1. Provjeri sumnjive obrasce
      result.merge!(check_suspicious_patterns(name))

      # 2. Provjeri duplikate
      result.merge!(check_duplicates(name, city))

      # 3. Provjeri Geoapify (postoji li u BiH?)
      result.merge!(check_geoapify(name, city))

      # 4. Provjeri BiH granice ako ima koordinate
      result.merge!(check_bih_boundaries(result.coordinates))

      result
    end

    # Validacija iskustva
    def self.validate_experience(location_ids:)
      result = ValidationResult.new

      # 1. Provjeri da lokacije postoje
      result.merge!(check_locations_exist(location_ids))

      # 2. Provjeri da imaju opise
      result.merge!(check_locations_complete(location_ids))

      # 3. Provjeri geografsku koherentnost
      result.merge!(check_geographic_coherence(location_ids))

      # 4. Provjeri minimum lokacija
      result.merge!(check_minimum_locations(location_ids))

      result
    end

    # Validacija generiranog opisa
    def self.validate_description(text:, context:)
      result = ValidationResult.new

      # 1. Provjeri minimum karaktera
      result.merge!(check_minimum_length(text, context))

      # 2. Provjeri generičke fraze
      result.merge!(check_generic_phrases(text))

      # 3. Provjeri reference na druge države
      result.merge!(check_foreign_references(text))

      # 4. Provjeri konzistentnost sa kontekstom
      result.merge!(check_context_consistency(text, context))

      result
    end
  end
end
```

### Sumnjivi obrasci - Konfiguracija

```ruby
# lib/platform/dsl/suspicious_patterns.rb
module Platform::DSL
  SUSPICIOUS_PATTERNS = {
    high_risk: [
      /rimske?\s+terme/i,
      /thermal\s+waters?/i,
      /roman\s+baths?/i,
      /\[grad\]\s+(cultural|visitor)\s+center/i,
    ],
    medium_risk: [
      /\bspa\b/i,
      /wellness/i,
      /rimsk/i,
      /hotel\s+\w+/i,
      /resort/i,
      /restoran/i,
    ],
    duplicate_indicators: [
      # Iste lokacije sa različitim gradovima
      { pattern: /kravica/i, expected_city: "Ljubuški" },
      { pattern: /guber/i, expected_city: "Srebrenica" },
      { pattern: /stari\s+most/i, expected_city: "Mostar" },
    ],
    foreign_city_names: [
      # Gradovi koji postoje i u drugim državama
      { name: "Tuzla", other_countries: ["Turkey"] },
      { name: "Mostar", other_countries: ["Czech Republic"] },
    ]
  }
end
```

### ValidationResult klasa

```ruby
# lib/platform/dsl/validation_result.rb
module Platform::DSL
  class ValidationResult
    attr_reader :status, :errors, :warnings, :suggestions, :coordinates

    def initialize
      @status = :valid  # :valid, :warning, :invalid
      @errors = []
      @warnings = []
      @suggestions = []
      @coordinates = nil
    end

    def valid?
      @status == :valid
    end

    def add_error(message, code: nil)
      @errors << { message: message, code: code }
      @status = :invalid
    end

    def add_warning(message, code: nil)
      @warnings << { message: message, code: code }
      @status = :warning if @status == :valid
    end

    def add_suggestion(message)
      @suggestions << message
    end

    def to_dsl_response
      {
        status: @status,
        valid: valid?,
        errors: @errors,
        warnings: @warnings,
        suggestions: @suggestions
      }
    end
  end
end
```

---

## Implementacija po komandama

### 1. `validate location { name, city }`

**Fajl:** `lib/platform/dsl/executors/quality.rb`

```ruby
def execute_validate_location(ast)
  name = ast[:data][:name]
  city = ast[:data][:city]

  result = ContentValidator.validate_location(name: name, city: city)

  # Format za DSL output
  {
    command: "validate location",
    input: { name: name, city: city },
    result: result.to_dsl_response,
    message: format_validation_message(result)
  }
end

def format_validation_message(result)
  case result.status
  when :valid
    "✅ VALID - Lokacija može biti kreirana"
  when :warning
    "⚠️ WARNING - #{result.warnings.map { |w| w[:message] }.join(', ')}"
  when :invalid
    "❌ INVALID - #{result.errors.map { |e| e[:message] }.join(', ')}"
  end
end
```

**Grammar:** Dodati u `lib/platform/dsl/grammar.rb`

```ruby
rule(:validate_command) {
  str('validate') >> space >>
  (str('location') | str('experience') | str('content')).as(:validate_type) >>
  space >> object_literal.as(:data)
}
```

### 2. `quality audit`

**Fajl:** `lib/platform/dsl/executors/quality.rb`

```ruby
def execute_quality_audit(ast)
  detailed = ast[:options]&.dig(:detailed) || false

  audit = {
    timestamp: Time.current,
    summary: {},
    issues: []
  }

  # Lokacije bez opisa
  missing_desc = Location.left_joins(:translations)
    .where(translations: { id: nil })
    .or(Location.joins(:translations)
      .where("translations.field_name = 'description' AND LENGTH(translations.value) < 100"))
    .distinct.count
  audit[:summary][:locations_missing_description] = missing_desc

  # Lokacije bez experience types
  missing_types = Location.left_joins(:location_experience_types)
    .where(location_experience_types: { id: nil }).count
  audit[:summary][:locations_missing_types] = missing_types

  # Iskustva bez lokacija
  missing_locs = Experience.left_joins(:experience_locations)
    .where(experience_locations: { id: nil }).count
  audit[:summary][:experiences_missing_locations] = missing_locs

  # Sumnjivi nazivi
  suspicious = scan_suspicious_patterns
  audit[:summary][:suspicious_patterns] = suspicious.count

  # Duplikati
  duplicates = find_all_duplicates
  audit[:summary][:potential_duplicates] = duplicates.count

  if detailed
    audit[:issues] = {
      suspicious_patterns: suspicious,
      potential_duplicates: duplicates
    }
  end

  audit[:overall_status] = calculate_overall_status(audit[:summary])

  audit
end
```

### 3. `scan suspicious patterns`

**Fajl:** `lib/platform/dsl/executors/quality.rb`

```ruby
def execute_scan_suspicious(ast)
  results = []

  # Skeniraj lokacije
  Location.find_each do |loc|
    SUSPICIOUS_PATTERNS[:high_risk].each do |pattern|
      if loc.name =~ pattern
        results << {
          type: :location,
          id: loc.id,
          name: loc.name,
          city: loc.city,
          risk: :high,
          pattern: pattern.source,
          suggestion: "Verifikuj da ova lokacija zaista postoji u #{loc.city}"
        }
      end
    end

    # Provjeri duplikate sa pogrešnim gradom
    SUSPICIOUS_PATTERNS[:duplicate_indicators].each do |indicator|
      if loc.name =~ indicator[:pattern] && loc.city != indicator[:expected_city]
        results << {
          type: :location,
          id: loc.id,
          name: loc.name,
          city: loc.city,
          risk: :high,
          expected_city: indicator[:expected_city],
          suggestion: "Ova lokacija je obično u #{indicator[:expected_city]}, ne u #{loc.city}"
        }
      end
    end
  end

  # Skeniraj iskustva
  Experience.find_each do |exp|
    SUSPICIOUS_PATTERNS[:high_risk].each do |pattern|
      if exp.title =~ pattern
        results << {
          type: :experience,
          id: exp.id,
          title: exp.title,
          risk: :high,
          pattern: pattern.source
        }
      end
    end
  end

  {
    scanned_at: Time.current,
    total_issues: results.count,
    high_risk: results.select { |r| r[:risk] == :high }.count,
    medium_risk: results.select { |r| r[:risk] == :medium }.count,
    issues: results
  }
end
```

### 4. `find duplicates for location { name }`

**Fajl:** `lib/platform/dsl/executors/quality.rb`

```ruby
def execute_find_duplicates(ast)
  name = ast[:data][:name]

  # Fuzzy search za slične nazive
  similar = Location.where("similarity(name, ?) > 0.3", name)
    .or(Location.where("name ILIKE ?", "%#{name}%"))
    .select(:id, :name, :city)
    .map do |loc|
      {
        id: loc.id,
        name: loc.name,
        city: loc.city,
        similarity: calculate_similarity(name, loc.name)
      }
    end
    .sort_by { |r| -r[:similarity] }

  {
    query: name,
    found: similar.count,
    duplicates: similar,
    suggestion: similar.any? ?
      "Pronađeno #{similar.count} sličnih lokacija - provjeri da nije duplikat" :
      "Nije pronađen duplikat"
  }
end
```

### 5. Integracija u `create location`

**Fajl:** `lib/platform/dsl/executors/content.rb`

```ruby
def execute_create(table, data)
  # NOVO: Automatska validacija prije kreiranja
  if is_location_table?(table)
    validation = ContentValidator.validate_location(
      name: data[:name],
      city: data[:city]
    )

    if validation.status == :invalid
      raise ExecutionError, "Validacija nije prošla: #{validation.errors.map { |e| e[:message] }.join(', ')}"
    end

    if validation.status == :warning
      # Log warning ali nastavi
      Rails.logger.warn("Content creation warning: #{validation.warnings.map { |w| w[:message] }.join(', ')}")
    end
  end

  # Postojeći kod...
  validate_mutation_data!(table, data, :create)
  # ...
end
```

---

## Faze implementacije

### Faza 1: Core Validation (P0)
1. `ContentValidator` klasa
2. `ValidationResult` klasa
3. `validate location` komanda
4. Integracija validacije u `create location`
5. `quality audit` komanda

### Faza 2: Pattern Detection (P1)
1. `SUSPICIOUS_PATTERNS` konfiguracija
2. `scan suspicious patterns` komanda
3. `find duplicates` komanda
4. `add locations to experience` komanda

### Faza 3: Advanced Validation (P2)
1. `verify location` (web provjera)
2. Validacija generiranih opisa
3. Validacija prijevoda
4. Cross-validation iskustava

---

## Testovi

### Test za validaciju lokacije

```ruby
# test/lib/platform/dsl/content_validator_test.rb
class ContentValidatorTest < ActiveSupport::TestCase
  test "validates real location" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Stari most",
      city: "Mostar"
    )
    assert result.valid?
  end

  test "flags suspicious thermal pattern" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Rimske terme Olovo",
      city: "Olovo"
    )
    assert_equal :warning, result.status
    assert result.warnings.any? { |w| w[:code] == :suspicious_pattern }
  end

  test "catches wrong city for known location" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Kravica vodopad",
      city: "Posušje"  # Pogrešno - trebalo bi biti Ljubuški
    )
    assert_equal :warning, result.status
    assert result.warnings.any? { |w| w[:code] == :wrong_city }
  end

  test "rejects location outside BiH" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Beograd",
      city: "Beograd"
    )
    assert_equal :invalid, result.status
    assert result.errors.any? { |e| e[:code] == :outside_bih }
  end
end
```

---

## DSL Grammar dodaci

```ruby
# Dodati u grammar.rb

# Validate commands
rule(:validate_command) {
  str('validate') >> space >>
  (
    (str('location') >> space >> object_literal.as(:data)) |
    (str('experience') >> space >> str('from') >> space >> str('locations') >> space >> array_literal.as(:location_ids)) |
    (str('content') >> space >> string_literal.as(:name) >> space >> str('for') >> space >> str('city') >> space >> string_literal.as(:city))
  ).as(:validate_type)
}

# Quality commands
rule(:quality_command) {
  str('quality') >> space >> str('audit') >> (space >> object_literal.as(:options)).maybe
}

# Scan commands
rule(:scan_command) {
  str('scan') >> space >> str('suspicious') >> space >> str('patterns')
}

# Find duplicates
rule(:find_duplicates_command) {
  str('find') >> space >> str('duplicates') >> space >>
  str('for') >> space >> str('location') >> space >> object_literal.as(:data)
}

# Verify command
rule(:verify_command) {
  str('verify') >> space >> str('location') >> space >> object_literal.as(:filters)
}

# Add locations to experience
rule(:add_locations_command) {
  str('add') >> space >> str('locations') >> space >> array_literal.as(:location_ids) >>
  space >> str('to') >> space >> str('experience') >> space >> object_literal.as(:filters)
}
```

---

## Sljedeći koraci

1. **Implementiraj Fazu 1** - Core validation
2. **Testiraj** - Napiši testove
3. **Integriši** - Dodaj u postojeće komande
4. **Dokumentiraj** - Ažuriraj DSL referencu
5. **Deploy** - Testiraj na produkciji

---

*"Validacija je prva linija odbrane protiv halucinacija."*
