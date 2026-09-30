# ADR: Migracija AI servisa na DSL-First arhitekturu

**Datum:** 2026-02-04
**Status:** Predloženo
**Autori:** Tech Lead, Developer

---

## Kontekst

Trenutno imamo 4 AI servisa koja koriste inline prompt logiku i direktne LLM pozive:

1. **Ai::LocationEnricher** - Obogaćuje lokacije sa AI-generisanim sadržajem (opisi, historija, tagovi, experience types)
2. **Ai::ExperienceTypeClassifier** - Klasifikuje lokacije po experience types
3. **Ai::AudioTourGenerator** - Generise audio ture sa TTS
4. **Ai::ExperienceLocationSyncer** - Sinkronizuje lokacije iz experience opisa

### Trenutno stanje

**Pozitivno:**
- Svi servisi koriste `PromptHelper` mixin
- Promptovi su izdvojeni u `app/prompts/` kao `.md.erb` fajlovi
- Svi servisi koriste `Ai::OpenaiQueue` za rate limiting
- Servisi imaju dobru test coverage

**Problemi:**
- `LocationEnricher` ima `@deprecated` tag ali nema migration path
- Servisi nisu integrirani sa Platform DSL sistemom
- Nema konzistentnog interface-a za AI operacije
- Kompleksna logika je zakopana u servisima (batch processing, metadata handling, translations)

### Arhitektonska vizija

Platform DSL treba biti jedini interface za sve AI operacije. Primjeri:

```ruby
# Umjesto: Ai::LocationEnricher.new.enrich(location)
locations { id: 123 } | enrich { fields: ["descriptions", "historical_context"] }

# Umjesto: Ai::ExperienceTypeClassifier.new.classify(location)
locations { id: 123 } | classify_experience_types

# Umjesto: Ai::AudioTourGenerator.new(location).generate(locale: "bs")
locations { id: 123 } | generate_audio { locales: ["bs", "en"] }

# Umjesto: Ai::ExperienceLocationSyncer.new.sync_locations(experience)
experiences { id: 456 } | sync_locations
```

---

## Odluka

**Migriramo AI servise u DSL executore kroz staged migration plan.**

### Princip: Postupno ugrađivanje u DSL

Ne brisati postojeće servise odmah. Umjesto toga:

1. **Kreiraj DSL executor koji koristi postojeći servis** (wrapper pattern)
2. **Postepeno refaktoriši logiku u executor** (kod zrije)
3. **Zamijeni pozive servisa sa DSL pozivima** (migracija korisnika)
4. **Ukloni legacy servis** (cleanup)

---

## Migration Plan

### Faza 1: Wrapper DSL Executors (Q1 2026 - Sedmice 1-2)

**Cilj:** DSL executori koji wrap postojeće servise. Zero business logic changes.

**Taskovi:**

#### 1.1 Enrich Executor
```ruby
# lib/platform/dsl/executors/ai_enrich.rb
module Platform::DSL::Executors
  class AiEnrich < Base
    def execute(entities, fields: nil)
      entities.map do |location|
        enricher = Ai::LocationEnricher.new
        enricher.enrich(location)
        location
      end
    end
  end
end
```

**Dodaje DSL sintaksu:**
```ruby
locations { city: "Sarajevo" } | enrich
locations { id: 123 } | enrich { fields: ["descriptions"] }
```

**Test:**
```ruby
# test/lib/platform/dsl/executors/ai_enrich_test.rb
class AiEnrichTest < ActiveSupport::TestCase
  test "wraps LocationEnricher" do
    location = locations(:stari_most)
    result = Platform::DSL::Executor.execute("locations { id: #{location.id} } | enrich")
    assert result.first.description.present?
  end
end
```

#### 1.2 Classify Experience Types Executor
```ruby
# lib/platform/dsl/executors/ai_classify.rb
module Platform::DSL::Executors
  class AiClassify < Base
    def execute(entities, hints: nil, dry_run: false)
      entities.map do |location|
        classifier = Ai::ExperienceTypeClassifier.new
        classifier.classify(location, dry_run: dry_run, hints: hints)
        location
      end
    end
  end
end
```

**DSL:**
```ruby
locations { city: "Mostar" } | classify_experience_types
locations { id: 123 } | classify_experience_types { hints: ["culture", "history"] }
```

#### 1.3 Generate Audio Executor
```ruby
# lib/platform/dsl/executors/ai_audio.rb
module Platform::DSL::Executors
  class AiAudio < Base
    def execute(entities, locales: ["bs"], force: false)
      entities.map do |location|
        generator = Ai::AudioTourGenerator.new(location)
        generator.generate_multilingual(locales: locales, force: force)
        location
      end
    end
  end
end
```

**DSL:**
```ruby
locations { id: 123 } | generate_audio { locales: ["bs", "en", "de"] }
```

#### 1.4 Sync Locations Executor
```ruby
# lib/platform/dsl/executors/ai_sync.rb
module Platform::DSL::Executors
  class AiSync < Base
    def execute(entities, dry_run: false)
      entities.map do |experience|
        syncer = Ai::ExperienceLocationSyncer.new
        syncer.sync_locations(experience, dry_run: dry_run)
        experience
      end
    end
  end
end
```

**DSL:**
```ruby
experiences { city: "Sarajevo" } | sync_locations
experiences { id: 456 } | sync_locations { dry_run: true }
```

**Deliverables:**
- [ ] 4 nova DSL executora (enrich, classify, audio, sync)
- [ ] Testovi za sve executore (>80% coverage)
- [ ] Dokumentacija u `lib/platform/dsl/README.md`
- [ ] Dodati DSL sintaksu u Grammar

**Timeline:** 1 sedmica

---

### Faza 2: Internal Migration (Q1 2026 - Sedmice 3-4)

**Cilj:** Svi interni pozivi koriste DSL, legacy servisi ostaju za compatibilnost.

**Taskovi:**

#### 2.1 Migracija Rake taskova
```ruby
# Prije:
# lib/tasks/locations.rake
task enrich_missing: :environment do
  enricher = Ai::LocationEnricher.new
  locations = Location.without_descriptions
  locations.each { |l| enricher.enrich(l) }
end

# Poslije:
task enrich_missing: :environment do
  result = Platform::DSL::Executor.execute(
    "locations | where { description: nil } | enrich"
  )
  puts "Enriched: #{result.count}"
end
```

#### 2.2 Migracija Background Jobs
```ruby
# Prije:
# app/jobs/enrich_location_job.rb
class EnrichLocationJob < ApplicationJob
  def perform(location_id)
    location = Location.find(location_id)
    enricher = Ai::LocationEnricher.new
    enricher.enrich(location)
  end
end

# Poslije:
class EnrichLocationJob < ApplicationJob
  def perform(location_id)
    Platform::DSL::Executor.execute(
      "locations { id: #{location_id} } | enrich"
    )
  end
end
```

#### 2.3 Migracija Controller akcija
```ruby
# Prije:
# app/controllers/admin/locations_controller.rb
def enrich
  @location = Location.find(params[:id])
  enricher = Ai::LocationEnricher.new
  enricher.enrich(@location)
  redirect_to @location, notice: "Enriched"
end

# Poslije:
def enrich
  @location = Location.find(params[:id])
  Platform::DSL::Executor.execute(
    "locations { id: #{@location.id} } | enrich"
  )
  redirect_to @location, notice: "Enriched"
end
```

**Deliverables:**
- [ ] Sve Rake tasks migrirane na DSL
- [ ] Svi Background Jobs migrirani na DSL
- [ ] Svi Controller pozivi migrirani na DSL
- [ ] Legacy servisi ostaju ali nisu direktno pozvani

**Timeline:** 1 sedmica

---

### Faza 3: Refactoring & Optimization (Q2 2026 - Sedmice 1-4)

**Cilj:** Poboljšanje DSL executora - bolja separacija concerns, optimizacije, bolji API.

**Taskovi:**

#### 3.1 Podijeli LocationEnricher na module

`LocationEnricher` je trenutno 585 linija sa kompleksnom logikom. Podijeli ga:

```ruby
# lib/platform/dsl/executors/ai_enrich/metadata.rb
module Platform::DSL::Executors::AiEnrich
  class Metadata
    def generate(location, place_data)
      # metadata generation logic
    end
  end
end

# lib/platform/dsl/executors/ai_enrich/descriptions.rb
module Platform::DSL::Executors::AiEnrich
  class Descriptions
    def generate(location, place_data, locales)
      # descriptions generation logic
    end
  end
end

# lib/platform/dsl/executors/ai_enrich/historical_context.rb
module Platform::DSL::Executors::AiEnrich
  class HistoricalContext
    def generate(location, place_data, locales)
      # history generation logic
    end
  end
end

# lib/platform/dsl/executors/ai_enrich.rb
module Platform::DSL::Executors
  class AiEnrich < Base
    def execute(entities, fields: ["all"])
      entities.map do |location|
        place_data = fetch_place_data(location)

        if fields.include?("all") || fields.include?("metadata")
          Metadata.new.generate(location, place_data)
        end

        if fields.include?("all") || fields.include?("descriptions")
          Descriptions.new.generate(location, place_data, locales)
        end

        if fields.include?("all") || fields.include?("historical_context")
          HistoricalContext.new.generate(location, place_data, locales)
        end

        location.save!
        location
      end
    end
  end
end
```

**Benefit:** Selective enrichment - ne generisati sve ako trebaš samo descriptions.

#### 3.2 Batch optimizacija

```ruby
# Prije: N calls to OpenAI
locations { city: "Sarajevo" } | limit(100) | enrich

# Poslije: Batch processing unutar executora
module Platform::DSL::Executors
  class AiEnrich < Base
    def execute(entities, batch_size: 10)
      entities.each_slice(batch_size) do |batch|
        # Process batch in parallel
        batch.map { |loc| enrich_async(loc) }.map(&:value)
      end
    end
  end
end
```

#### 3.3 Caching i deduplication

```ruby
# Cache responses za iste promptove
module Platform::DSL::Executors
  class AiEnrich < Base
    def execute(entities)
      entities.map do |location|
        cache_key = "enrich:#{location.id}:#{location.updated_at.to_i}"
        Rails.cache.fetch(cache_key, expires_in: 1.day) do
          # enrich logic
        end
      end
    end
  end
end
```

**Deliverables:**
- [ ] LocationEnricher podijeljen na module
- [ ] Batch processing implementiran
- [ ] Caching layer dodan
- [ ] Performance benchmarks (prije/poslije)
- [ ] Dokumentacija za nove API opcije

**Timeline:** 2 sedmice

---

### Faza 4: Deprecation Warnings (Q2 2026 - Sedmica 5)

**Cilj:** Aktiviraj deprecation warnings u legacy servisima.

```ruby
# app/services/ai/location_enricher.rb
module Ai
  # @deprecated Use Platform DSL instead:
  #   locations { id: X } | enrich { fields: ["descriptions"] }
  #
  # This service will be removed in version 2.0 (Q4 2026)
  class LocationEnricher
    def initialize
      ActiveSupport::Deprecation.warn(
        "Ai::LocationEnricher is deprecated. Use Platform DSL: " \
        "locations { id: X } | enrich"
      )
    end

    # existing implementation
  end
end
```

**Deliverables:**
- [ ] Deprecation warnings u sva 4 servisa
- [ ] Deprecation notice u README-ovima
- [ ] Migration guide u dokumentaciji

**Timeline:** 2 dana

---

### Faza 5: Documentation & Training (Q3 2026 - Sedmice 1-2)

**Cilj:** Dokumentacija i primjeri za eksterne korisnike.

**Taskovi:**

#### 5.1 DSL AI Operations Guide
```markdown
# Guide: AI Operations sa Platform DSL

## Obogaćivanje lokacija

### Obogaćivanje jedne lokacije
locations { id: 123 } | enrich

### Obogaćivanje svih bez opisa
locations | where { description: nil } | enrich

### Selektivno obogaćivanje (samo opisi)
locations { city: "Sarajevo" } | enrich { fields: ["descriptions"] }

## Klasifikacija experience types

### Klasifikuj sve bez experience types
locations | classify_experience_types

### Sa hints
locations { id: 123 } | classify_experience_types { hints: ["culture", "history"] }

## Audio ture

### Generiši audio u 3 jezika
locations { id: 123 } | generate_audio { locales: ["bs", "en", "de"] }

### Force regeneration
locations { id: 123 } | generate_audio { force: true }

## Sinkronizacija lokacija

### Sync locations za sve experiences
experiences | sync_locations

### Dry run (analiza bez promjena)
experiences { id: 456 } | sync_locations { dry_run: true }
```

#### 5.2 Migration Examples

```ruby
# PRIJE (Legacy API)
enricher = Ai::LocationEnricher.new
location = Location.find(123)
enricher.enrich(location)

# POSLIJE (DSL)
Platform::DSL::Executor.execute("locations { id: 123 } | enrich")

# Ili direktno u Rails console:
bin/platform exec 'locations { id: 123 } | enrich'
```

**Deliverables:**
- [ ] `docs/AI_OPERATIONS_DSL_GUIDE.md`
- [ ] `docs/MIGRATION_FROM_LEGACY_AI_SERVICES.md`
- [ ] Primjeri u `lib/platform/dsl/README.md`
- [ ] Video tutorial (10min screencast)

**Timeline:** 1 sedmica

---

### Faza 6: Uklanjanje Legacy Servisa (Q4 2026)

**Cilj:** Final cleanup - uklanjanje deprecated servisa.

**Pre-flight checklist:**
- [ ] Nema više direktnih poziva legacy servisa u kodu
- [ ] Svi testovi prolaze bez legacy servisa
- [ ] Dokumentacija ažurirana
- [ ] External korisnici obaviješteni (3 mjeseca ranije)

**Taskovi:**

1. Ukloni servise:
   - `app/services/ai/location_enricher.rb`
   - `app/services/ai/experience_type_classifier.rb`
   - `app/services/ai/audio_tour_generator.rb`
   - `app/services/ai/experience_location_syncer.rb`

2. Ukloni testove:
   - `test/services/ai/location_enricher_test.rb`
   - `test/services/ai/experience_type_classifier_test.rb`
   - `test/services/ai/audio_tour_generator_test.rb`
   - `test/services/ai/experience_location_syncer_test.rb`

3. Ukloni `@deprecated` tagove iz dokumentacije

4. Final validation:
   - `bin/rails test` - svi testovi prolaze
   - `bin/platform exec 'locations | enrich'` - radi
   - Production smoke test

**Deliverables:**
- [ ] Legacy servisi uklonjeni
- [ ] Testovi uklonjeni ili migrirani
- [ ] `CHANGELOG.md` entry za breaking change
- [ ] Release notes za verziju 2.0

**Timeline:** 3 dana

---

## Rollback Plan

### Ako migracija ne uspije:

**Opcija 1: Feature Flag**
```ruby
# lib/platform/dsl/executors/ai_enrich.rb
def execute(entities, **options)
  if Settings.use_legacy_enricher?
    # Use old service
    entities.map { |loc| Ai::LocationEnricher.new.enrich(loc) }
  else
    # Use new DSL logic
    # ...
  end
end
```

**Opcija 2: Dual Mode**
```ruby
# Obje implementacije koegzistiraju
locations { id: 123 } | enrich           # DSL (new)
Ai::LocationEnricher.new.enrich(location) # Legacy (still works)
```

**Opcija 3: Revert Commit**
- Legacy servisi ostaju u Git history
- Može se vratiti na staru verziju
- Deprecation warnings se samo ugase

---

## Posljedice

### Pozitivne
- **Konzistentan interface** - Sve AI operacije kroz DSL
- **Bolja integracija** - Platform CLI direktno koristi executore
- **Lakše testiranje** - DSL sintaksa je unit testable
- **Jasna separation of concerns** - Executori su pure functions
- **Bolja composability** - Pipeline operations (filter → enrich → classify)
- **Monitoring** - DSL executor calls mogu se trackati centralno

### Negativne
- **Development effort** - ~6 sedmica rada (1.5 mjeseca)
- **Dual mode kompleksnost** - Legacy + DSL paralelno tokom Q1-Q3
- **Potrebna dokumentacija** - Migration guide za eksterne korisnike
- **Risk** - Moguće performance regresije koje zahtijevaju optimizaciju

### Mitigacije
- **Staged rollout** - Faza po faza, ne big bang
- **Feature flags** - Easy rollback ako nešto ne radi
- **Testovi** - Visok coverage (>80%) prije uklanjanja legacy servisa
- **Monitoring** - Track DSL executor performance u production

---

## Reference

- `app/services/ai/` - Legacy AI servisi
- `app/prompts/` - Prompt struktura (već izdvojeni)
- `lib/platform/dsl/executors/` - Postojeći DSL executori
- `.claude/planning/IMPLEMENTATION.md` - Faze implementacije
- `.claude/planning/adr/2025-01-15-full-introspection-p0.md` - DSL-First odluka

---

## Timeline Summary

| Faza | Timeline | Deliverables |
|------|----------|--------------|
| **Faza 1: Wrapper Executors** | Q1 2026, Week 1-2 | 4 DSL executora + testovi |
| **Faza 2: Internal Migration** | Q1 2026, Week 3-4 | Rake tasks, Jobs, Controllers migrirani |
| **Faza 3: Refactoring** | Q2 2026, Week 1-4 | Module split, batch processing, caching |
| **Faza 4: Deprecation** | Q2 2026, Week 5 | Deprecation warnings aktivni |
| **Faza 5: Documentation** | Q3 2026, Week 1-2 | Migration guide, video tutorial |
| **Faza 6: Cleanup** | Q4 2026 | Legacy servisi uklonjeni |

**Ukupno:** ~3 mjeseca aktivnog development (Q1-Q2), 2 mjeseca stabilizacije (Q2-Q3), Q4 cleanup.

---

## Approval

- [ ] Tech Lead - Tehničko odobrenje
- [ ] Product Manager - Product odobrenje
- [ ] Developer - Implementation capacity potvrđen

**Datum odobrenja:** _TBD_

---

*Zadnje ažuriranje: 2026-02-04*
