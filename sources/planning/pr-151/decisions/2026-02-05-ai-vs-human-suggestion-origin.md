# ADR-0007: Human vs AI Suggestion Origin Tracking

## Status
Proposed

## Datum
2026-02-05

## Autori
Product Manager, Tech Lead

## Context

### Problem: AI piše direktno u bazu

Trenutno svi AI servisi direktno mijenjaju resurse:

| Servis | Šta radi | Kako piše |
|--------|----------|-----------|
| `Ai::LocationEnricher` | Generise opise, prijevode, tagove | `location.save!`, `location.set_translation()` |
| `Ai::AudioTourGenerator` | Generise script + TTS audio | `audio_tour.save!`, `location.update_column(:audio_tour_metadata)` |
| `Ai::ExperienceLocationSyncer` | Sync lokacija iz opisa | `experience.add_location()`, `location.update(ai_generated: true)` |
| `Ai::ExperienceTypeClassifier` | Klasifikuje lokacije po tipu | `location.add_experience_type()` |
| Platform DSL Executor | CLI content operacije | `record.save`, `record.update!()` |

**Rezultat:** AI-generisan sadržaj je odmah vidljiv korisnicima. Nema pregleda, nema QA, nema odobrenja. Ako AI generiše loš opis, pogrešnu klasifikaciju, ili netačnu historijsku informaciju — to je odmah live.

### Zašto je ovo problem?

1. **Kvalitet** — AI može generisati netačne informacije (halucinacije), osobito za historijski kontekst BiH
2. **Ton** — AI opisi mogu biti generički, bez lokalnog štiha koji Usput.ba želi
3. **Konzistentnost** — Različiti AI pozivi mogu generisati konfliktne informacije za isti resurs
4. **Kontrola** — Admin nema pregled šta je AI promijenio i kad
5. **Rollback** — Ako AI napravi grešku, nema jednostavnog načina da se vrati na prethodno stanje

### Šta želimo

- AI-generisan sadržaj prolazi kroz **isti suggestion workflow** kao i kuratorski prijedlozi
- Admin i kuratori mogu **pregledati AI prijedloge** prije nego postanu vidljivi
- Jasno razlikovanje **ko je predložio** — čovjek ili AI (i koji AI servis)
- Kuratori mogu **recenzirati** AI prijedloge
- AI prijedlozi i ljudski prijedlozi vidljivi **odvojeno** u dashboardu

## Decision

### 1. Origin polje na Suggestable concern

Dodati `origin` enum na sve suggestion modele kroz `Suggestable` concern:

```ruby
# app/models/concerns/suggestable.rb
module Suggestable
  included do
    # ... existing code ...

    enum :origin, {
      human: 0,        # Kurator ili admin predložio
      ai_generated: 1  # AI servis generisao
    }, prefix: :origin

    # Koji AI servis je kreirao suggestion (null za human)
    # Npr: "location_enricher", "audio_tour_generator", "experience_syncer"
    attribute :ai_service, :string

    scope :human_suggestions, -> { where(origin: :human) }
    scope :ai_suggestions, -> { where(origin: :ai_generated) }
  end
end
```

```ruby
# Migration — dodati na sve suggestion tabele
add_column :location_suggestions, :origin, :integer, default: 0, null: false
add_column :location_suggestions, :ai_service, :string
# Isti za experience_suggestions, plan_suggestions
```

### 2. AI servisi kreiraju suggestion-e umjesto direktnog pisanja

**Prije (direktno):**
```ruby
# Ai::LocationEnricher
def enrich(location)
  description = generate_description(location)
  location.description = description
  location.save!  # Odmah live
end
```

**Poslije (kroz suggestion):**
```ruby
# Ai::LocationEnricher
def enrich(location)
  description = generate_description(location)
  historical = generate_historical_context(location)
  tags = generate_tags(location)
  translations = generate_translations(location)

  suggestion = LocationSuggestion.find_or_create_pending!(
    location,
    user: system_user,  # Dedicated AI system user
    origin: :ai_generated,
    ai_service: "location_enricher"
  )

  suggestion.update!(
    proposed_description: description,
    proposed_historical_context: historical,
    proposed_tags: tags,
    change_type: :update_resource
  )

  # Prijevodi idu kao zasebni prijedlozi ili metadata na suggestion
  # (vidi sekciju 5 za detalje)

  suggestion
end
```

### 3. System User za AI operacije

```ruby
# Dedicated user account za AI operacije
# Kreiran kroz seed ili migration
system_user = User.find_or_create_by!(
  email: "ai@usput.ba",
  username: "usput-ai",
  user_type: :admin  # Admin da može kreirati suggestion-e
)
```

Svi AI servisi koriste ovaj account kao `user` na suggestion-u. Dashboard prikazuje "Usput AI" umjesto korisničkog imena.

### 4. Dashboard prikaz — odvojeni tabovi

```
┌─────────────────────────────────────────┐
│  Pending Suggestions                     │
├──────────┬──────────┬───────────────────┤
│ [Human]  │  [AI]    │  [All]            │
├──────────┴──────────┴───────────────────┤
│                                          │
│  📝 LocationSuggestion #12              │
│  Origin: AI (location_enricher)          │
│  Predloženo: description, tags, context  │
│  Datum: 05.02.2026                       │
│  [Pregledaj] [Odobri] [Odbij]           │
│                                          │
│  📝 LocationSuggestion #11              │
│  Origin: Human (kurator: @jasmin)        │
│  Predloženo: name, city, photos (3)      │
│  Datum: 05.02.2026                       │
│  [Pregledaj] [Odobri] [Odbij]           │
│                                          │
└─────────────────────────────────────────┘
```

Kurator vidi oba taba. Admin vidi oba taba + approve/reject akcije.

### 5. AI servis adaptacije — po servisu

#### LocationEnricher → LocationSuggestion

```ruby
class Ai::LocationEnricher
  def enrich(location)
    # Generiši sve podatke
    data = generate_all_data(location)

    # Kreiraj suggestion umjesto direktnog save
    LocationSuggestion.find_or_create_pending!(location, user: system_user).tap do |s|
      s.update!(
        origin: :ai_generated,
        ai_service: "location_enricher",
        change_type: :update_resource,
        proposed_description: data[:description],
        proposed_historical_context: data[:historical_context],
        proposed_tags: data[:tags],
        proposed_experience_type_ids: data[:experience_type_ids]
      )
    end
  end
end
```

#### AudioTourGenerator → Direktno (izuzetak)

Audio tura generisanje ostaje **admin-only akcija** (ADR-0005). Kad admin klikne "Generiši", to je eksplicitno odobrenje — nema smisla kreirati suggestion pa ga odobriti. AudioTour se kreira direktno ali samo na admin zahtjev.

#### ExperienceLocationSyncer → ExperienceSuggestion

```ruby
class Ai::ExperienceLocationSyncer
  def sync_locations(experience)
    detected_locations = detect_locations_from_description(experience)

    ExperienceSuggestion.find_or_create_pending!(experience, user: system_user).tap do |s|
      s.update!(
        origin: :ai_generated,
        ai_service: "experience_location_syncer",
        change_type: :update_resource,
        proposed_location_uuids: detected_locations.map(&:uuid)
      )
    end
  end
end
```

#### ExperienceTypeClassifier → LocationSuggestion

```ruby
class Ai::ExperienceTypeClassifier
  def classify(location)
    types = classify_experience_types(location)

    LocationSuggestion.find_or_create_pending!(location, user: system_user).tap do |s|
      s.update!(
        origin: :ai_generated,
        ai_service: "experience_type_classifier",
        change_type: :update_resource,
        proposed_experience_type_ids: types.map(&:id)
      )
    end
  end
end
```

### 6. Prijevodi — poseban slučaj

Prijevodi (`set_translation`) koriste Mobility gem i nisu direktni atributi na modelu. Opcije:

**Opcija A: JSONB metadata polje na suggestion**
```ruby
# Na LocationSuggestion
t.jsonb :proposed_translations, default: {}
# Struktura: { "en" => { "description" => "...", "name" => "..." }, "de" => { ... } }
```

**Opcija B: Odvojeni translation workflow**
Prijevodi se generišu i primjenjuju tek kad je originalni tekst odobren. Approval callback pokreće translation generation.

**Preporučeno: Opcija B** — Prijevodi zavise od finalnog teksta. Nema smisla prevoditi prijedlog koji može biti odbijen. Kad admin odobri suggestion koji mijenja description, sistem automatski trigeruje prijevod novog teksta.

### 7. Auto-approve za pouzdane AI operacije

Neke AI operacije su dovoljno pouzdane da mogu biti auto-approved:

```ruby
# config/initializers/ai_auto_approve.rb
AI_AUTO_APPROVE_SERVICES = %w[
  # experience_type_classifier  # Možda u budućnosti
].freeze

# U Suggestable concern
after_create :auto_approve_if_eligible

def auto_approve_if_eligible
  return unless origin_ai_generated?
  return unless AI_AUTO_APPROVE_SERVICES.include?(ai_service)

  approve!(system_user, notes: "Auto-approved: trusted AI service")
end
```

Za sada: **nijedan servis nije auto-approved**. Svi AI prijedlozi čekaju ljudski pregled. Auto-approve se može postepeno omogućavati kad se uspostavi povjerenje u kvalitet.

### 8. Batch AI generation → Batch suggestions

Kad se pokrene batch operacija (npr. "enrich all locations without description"), rezultat je **lista pending suggestion-a** umjesto direktnih promjena:

```ruby
# Prije
locations.each { |l| Ai::LocationEnricher.new(l).enrich }
# → Sve lokacije odmah ažurirane

# Poslije
locations.each { |l| Ai::LocationEnricher.new(l).enrich }
# → N pending LocationSuggestion zapisa
# → Admin vidi "15 new AI suggestions" na dashboardu
# → Admin može bulk approve ili pregledati jedan po jedan
```

## Consequences

### Positive

- **Kvalitet kontrola** — Nijedan AI sadržaj nije live bez ljudskog odobrenja
- **Transparentnost** — Jasno vidljivo šta je AI generisao vs šta je čovjek napisao
- **Unified workflow** — Isti suggestion sistem za sve izvore sadržaja
- **Rollback** — Suggestion se može odbiti. Originalni resurs ostaje nepromijenjen.
- **Audit trail** — `ai_service` polje prati koji servis je generisao šta
- **Postepeno povjerenje** — Auto-approve se može uključiti po servisu kad se dokaže kvalitet
- **Kurator recenzija** — Kuratori mogu pregledati i komentarisati AI prijedloge

### Negative

- **Sporiji AI pipeline** — Sadržaj koji je ranije bio odmah live sad čeka odobrenje. Za batch operacije to znači admin bottleneck.
- **System user** — Potreban je dedicated AI user account. Treba paziti da se ne koristi za manual operacije.
- **Prijevodi postaju dvostepeni** — Originalni tekst treba odobriti, pa tek onda prevoditi. Više čekanja.
- **Refaktorizacija AI servisa** — Svi servisi moraju biti adaptirani da kreiraju suggestion-e umjesto direktnog pisanja. Nije trivijalno — 4+ servisa sa različitim logikama.
- **Conflict sa existing pending** — Ako kurator i AI oboje predlože promjenu iste lokacije, unique constraint dozvoljava samo jedan pending. Rješenje: AI contribution se dodaje na postojeći human suggestion ili obrnuto.

### Neutral

- **Audio tour generisanje** ostaje direktno — admin eksplicitno traži, to je de facto odobrenje
- **`needs_ai_regeneration` flag** se mijenja u "trigger za kreiranje AI suggestion-a" umjesto "trigger za direktnu promjenu"
- **Platform DSL** treba adaptaciju — `bin/platform exec 'content | generate_description'` sad kreira suggestion umjesto direktnog update-a

## Alternatives Considered

### Opcija 1: Samo flag na resursu (ai_generated: true/false)

Označiti resurse koje je AI kreirao/mijenjao ali bez suggestion workflow-a.

- **Prednosti:** Minimalna promjena. AI i dalje piše direktno.
- **Mane:** Nema pregleda prije objavljivanja. Flag je informativni, ne sprečava ništa.
- **Zašto odbačeno:** Ne rješava core problem — AI sadržaj je odmah live.

### Opcija 2: Odvojen AI Review Queue (ne kroz suggestion model)

Poseban `AiContentReview` model samo za AI-generirane promjene.

- **Prednosti:** Ne komplicira suggestion model.
- **Mane:** Dva odvojena sistema za review. Admin mora gledati dva inbox-a. Dupla logika za approve/reject.
- **Zašto odbačeno:** Unified suggestion model sa `origin` poljem je jednostavniji i konzistentniji.

### Opcija 3: AI piše direktno ali sa "draft" statusom na resursu

Dodati `publication_status` na svaki resurs (draft/published). AI piše u draft, admin publish-a.

- **Prednosti:** Nema suggestion modela za AI. AI piše direktno ali u draft.
- **Mane:** Zahtijeva status kolonu na svakom modelu. Public query-ji moraju filtrirati draft. Promjena na 4+ modela. Miješanje AI draft-a i manual draft-a.
- **Zašto odbačeno:** Suggestion model već postoji i radi za human prijedloge. Jednostavnije je dodati `origin` nego novi status sistem na svim modelima.

## Implementation Notes

### Redoslijed implementacije

1. **Faza 2 (ADR-0003)** — Kreiraj suggestion modele sa `origin` i `ai_service` poljem od početka
2. **Faza 2.5 (novi)** — Adaptiraj AI servise da kreiraju suggestion-e
   - LocationEnricher → LocationSuggestion
   - ExperienceTypeClassifier → LocationSuggestion
   - ExperienceLocationSyncer → ExperienceSuggestion
3. **Faza 4 (ADR-0005)** — Audio tour generisanje (ostaje direktno, admin-only)
4. **Faza 5 (cleanup)** — Ukloni stare direktne AI pipeline-e

### Conflict resolution: Human + AI pending za isti resurs

Unique constraint dozvoljava samo jedan pending suggestion per resurs. Kad AI i human oboje žele predložiti promjenu:

```ruby
# AI servis koristi find_or_create_pending! — isto kao kurator
# Ako već postoji human pending → AI dodaje contribution
# Ako već postoji AI pending → novi AI run ažurira polja

suggestion = LocationSuggestion.find_or_create_pending!(location, user: system_user)
if suggestion.origin_human? && suggestion.persisted?
  # Postoji human suggestion — AI dodaje kao contribution
  suggestion.add_contribution(
    user: system_user,
    notes: "AI enrichment via #{service_name}",
    **ai_proposed_fields
  )
else
  # AI suggestion — ažuriraj direktno
  suggestion.update!(
    origin: :ai_generated,
    ai_service: service_name,
    **ai_proposed_fields
  )
end
```

## References

- RFC-0001: Curator Dashboard v2 (`.claude/planning/rfcs/0001-curator-dashboard-v2.md`)
- ADR-0003: Per-Resource Suggestion Models (`.claude/planning/decisions/2026-02-05-per-resource-suggestion-models.md`)
- ADR-0005: Audio Tour Generation (`.claude/planning/decisions/2026-02-05-audio-tour-generation-integration.md`)
- `Ai::LocationEnricher` (`app/services/ai/location_enricher.rb`)
- `Ai::AudioTourGenerator` (`app/services/ai/audio_tour_generator.rb`)
- `Ai::ExperienceLocationSyncer` (`app/services/ai/experience_location_syncer.rb`)
- `Ai::ExperienceTypeClassifier` (`app/services/ai/experience_type_classifier.rb`)
