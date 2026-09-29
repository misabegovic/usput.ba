# Test Coverage Plan: 50% → 70%

## Cilj
- **Trenutno:** 50.22% line coverage
- **Cilj:** 70% line coverage
- **Potrebno:** ~2,200 dodatnih linija pokriveno

---

## Prioritetne oblasti

### Faza 1: Jobs (0% coverage) - ~1,000 linija

| Fajl | Linija | Prioritet |
|------|--------|-----------|
| `location_image_finder_job.rb` | 336 | P0 |
| `rebuild_experiences_job.rb` | 257 | P0 |
| `location_city_fix_job.rb` | 189 | P1 |
| `experience_type_sync_job.rb` | 132 | P1 |
| `delete_location_photos_job.rb` | 126 | P1 |
| `delete_experience_photos_job.rb` | 126 | P1 |
| `rebuild_plans_job.rb` | 116 | P2 |
| `regenerate_translations_job.rb` | 104 | P2 |
| `audio_tour_generation_job.rb` | 93 | P2 |

**Strategija:** Stub external services (OpenAI, Geoapify, S3), test job logic

### Faza 2: Controllers (0% coverage) - ~700 linija

| Fajl | Linija | Prioritet |
|------|--------|-----------|
| `new_design_controller.rb` | 279 | P0 |
| `user_plans_controller.rb` | 164 | P0 |
| `travel_profiles_controller.rb` | 145 | P1 |
| `curator/locations_controller.rb` | 111 | P1 |
| `curator/audio_tours_controller.rb` | 101 | P1 |
| `curator/plans_controller.rb` | 100 | P1 |
| `curator/experiences_controller.rb` | 98 | P1 |

**Strategija:** Integration tests, test happy path + edge cases

### Faza 3: AI Services - ~800 linija

| Fajl | Linija | Coverage | Prioritet |
|------|--------|----------|-----------|
| `country_wide_location_generator.rb` | 351 | 38.9% | P0 |
| `content_orchestrator.rb` | 214 | 27.7% | P0 |
| `experience_analyzer.rb` | 209 | 21.7% | P1 |
| `location_analyzer.rb` | 191 | 0% | P1 |
| `audio_tour_generator.rb` | 158 | 18.1% | P2 |
| `experience_location_syncer.rb` | 130 | 26.1% | P2 |

**Strategija:** Mock AI responses, test parsing i business logic

### Faza 4: Platform & Misc - ~300 linija

| Fajl | Linija | Coverage | Prioritet |
|------|--------|----------|-----------|
| `platform/dsl/executor.rb` | 228 | 78.1% | P1 |
| `platform/cli.rb` | 116 | 0% | P2 |
| `google_image_search_service.rb` | 129 | 0% | P2 |

---

## Sprint Plan

### Sprint 1: Jobs + Critical Controllers
- [ ] `location_image_finder_job.rb` tests
- [ ] `rebuild_experiences_job.rb` tests
- [ ] `new_design_controller.rb` tests
- [ ] `user_plans_controller.rb` tests
- **Cilj:** 57% coverage

### Sprint 2: AI Services
- [ ] `country_wide_location_generator.rb` (povećaj na 80%+)
- [ ] `content_orchestrator.rb` tests
- [ ] `experience_analyzer.rb` tests
- [ ] `location_analyzer.rb` tests
- **Cilj:** 63% coverage

### Sprint 3: Curator Controllers + Remaining Jobs
- [ ] `curator/locations_controller.rb` tests
- [ ] `curator/experiences_controller.rb` tests
- [ ] `curator/plans_controller.rb` tests
- [ ] `curator/audio_tours_controller.rb` tests
- [ ] Remaining jobs
- **Cilj:** 70% coverage

---

## Test Patterns

### Job Testing Pattern
```ruby
class LocationImageFinderJobTest < ActiveSupport::TestCase
  setup do
    @location = locations(:mostar)
    # Stub external services
    GoogleImageSearchService.any_instance.stubs(:search).returns([])
  end

  test "performs job successfully" do
    assert_nothing_raised do
      LocationImageFinderJob.perform_now(@location.id)
    end
  end

  test "handles missing location gracefully" do
    assert_nothing_raised do
      LocationImageFinderJob.perform_now(-1)
    end
  end
end
```

### Controller Testing Pattern
```ruby
class NewDesignControllerTest < ActionDispatch::IntegrationTest
  test "home page loads successfully" do
    get root_path
    assert_response :success
  end

  test "home page displays featured locations" do
    get root_path
    assert_select ".location-card", minimum: 1
  end
end
```

### AI Service Testing Pattern
```ruby
class Ai::ContentOrchestratorTest < ActiveSupport::TestCase
  setup do
    # Mock AI responses
    mock_response = { "content" => "Generated content" }
    OpenaiQueue.any_instance.stubs(:chat).returns(mock_response)
  end

  test "generates content for location" do
    result = Ai::ContentOrchestrator.new(@location).generate
    assert result.present?
  end
end
```

---

## CI Enforcement

Dodaj u `.github/workflows/ci.yml`:
```yaml
- name: Check coverage threshold
  run: |
    COVERAGE=$(ruby -e "require 'json'; puts JSON.parse(File.read('coverage/.last_run.json'))['result']['line']")
    if (( $(echo "$COVERAGE < 70" | bc -l) )); then
      echo "Coverage $COVERAGE% is below 70% threshold"
      exit 1
    fi
```

---

## Napomene

1. **Mock external APIs** - Ne testiraj stvarne API pozive
2. **Fixture data** - Koristi fixtures za konzistentne testove
3. **Fast tests** - Izbjegavaj sleep/wait u testovima
4. **Isolated tests** - Svaki test treba biti nezavisan

---

## Metrike

| Metrika | Trenutno | Sprint 1 | Sprint 2 | Sprint 3 |
|---------|----------|----------|----------|----------|
| Line Coverage | 50.22% | 57% | 63% | 70% |
| Branch Coverage | 42.68% | 48% | 55% | 60% |
| Test Count | 1449 | ~1600 | ~1750 | ~1900 |

---

**Autor:** Tech Lead
**Datum:** 2026-01-15
**Status:** Active
