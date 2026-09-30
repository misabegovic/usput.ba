# Plan: Autonomni AI Generator Sadržaja

## Pregled

**Filozofija: AI odlučuje SVE**

Admin samo klikne jedan gumb. AI autonomno:
1. Analizira šta nedostaje u sistemu
2. Odlučuje koje gradove/regije obraditi
3. Pronalazi lokacije putem Geoapify
4. Kreira i obogaćuje Location objekte
5. Generiše Experience-e koji povezuju lokacije
6. Kreira Plan-ove za različite profile turista

**Audio ture se NE generišu automatski** - pokreću se odvojeno zbog troškova ElevenLabs API-ja.

### Ciljevi
- **Potpuna autonomija**: Admin ne bira ništa - AI odlučuje sve
- **Jedan klik**: Pokreni i zaboravi
- **Inteligentan reasoning**: AI prvo analizira, pa djeluje
- **Fleksibilne relacije**: Lokacija može biti u više Experience-a, Experience u više Plan-ova
- **Kontrola broja Experience-a**: Admin može ograničiti koliko Experience-a se kreira

### Postojeća infrastruktura
- **RubyLLM** - `config/initializers/ruby_llm.rb`
- **Geoapify** - `app/services/geoapify_service.rb` (rate limit: 5 req/sec)
- **ElevenLabs** - `AudioTourGenerator`
- **BIH_CULTURAL_CONTEXT** - `ExperienceGenerator`
- **Translatable concern** - 14 jezika
- **Setting model** - konfiguracija

---

## Arhitektura: Autonomni AI Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AUTONOMNI AI PIPELINE                                │
└─────────────────────────────────────────────────────────────────────────────┘

ADMIN: Klikne "Generiši"
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FAZA 1: AI REASONING (Analiza i planiranje)                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  AI analizira:                                                               │
│  • Koje regije/gradovi nemaju dovoljno sadržaja?                            │
│  • Koje kategorije lokacija nedostaju? (kultura, hrana, priroda...)         │
│  • Koliko lokacija treba za svaki grad?                                      │
│  • Koje profile turista možemo podržati?                                     │
│                                                                              │
│  AI vraća PLAN AKCIJA:                                                       │
│  {                                                                           │
│    "target_cities": ["Mostar", "Travnik"],                                  │
│    "locations_to_fetch": { "Mostar": 30, "Travnik": 20 },                   │
│    "categories_needed": ["historical", "restaurant", "nature"],              │
│    "reasoning": "Mostar ima samo 5 lokacija, treba više..."                 │
│  }                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FAZA 2: PRIKUPLJANJE LOKACIJA (Geoapify)                                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Za svaki grad iz plana:                                                     │
│  • Geoapify API → sirovi podaci o mjestima                                  │
│  • Rate limiting: max 5 req/sec                                              │
│  • Deduplikacija postojećih lokacija                                         │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FAZA 3: OBOGAĆIVANJE LOKACIJA (AI)                                         │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Za svaku novu lokaciju:                                                     │
│  • AI generiše opise na 14 jezika                                           │
│  • AI generiše historical_context za audio                                   │
│  • AI predlaže tags i suitable_experiences                                   │
│  • Spremanje u Location model                                                │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FAZA 4: KREIRANJE ISKUSTAVA (AI)                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  AI analizira SVE lokacije (nove + postojeće) i kreira Experience-e:         │
│  • Grupiše lokacije TEMATSKI (ne samo geografski!)                          │
│    - "Tvrđave BiH" - lokacije iz različitih gradova                         │
│    - "UNESCO spomenici" - razbacani po cijeloj zemlji                       │
│    - "Gastronomska tura Mostara" - lokalno grupisane                        │
│  • Jedna lokacija MOŽE biti u više Experience-a                             │
│  • Generiše nazive i opise na 14 jezika                                      │
│  • Spremanje u Experience + ExperienceLocation (many-to-many)               │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FAZA 5: KREIRANJE PLANOVA (AI)                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  AI kreira Plan-ove za različite profile:                                    │
│  • Analizira SVE dostupne Experience-e (nove + postojeće)                   │
│  • Odlučuje koje profile podržati (family, couple, adventure...)            │
│  • Određuje optimalan broj dana                                              │
│  • Jedan Experience MOŽE biti u više Plan-ova                               │
│  • Organizira Experience-e po danima                                         │
│  • Spremanje u Plan + PlanExperience (many-to-many)                         │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
REZULTAT: Lokacije, Experience-i i Plan-ovi spremni za korištenje

═══════════════════════════════════════════════════════════════════════════════
                    ODVOJENO: AUDIO TURE (Admin pokreće ručno)
═══════════════════════════════════════════════════════════════════════════════

Audio ture se pokreću ODVOJENO zbog troškova ElevenLabs API-ja.
Admin može:
• Pregledati lokacije koje nemaju audio ture
• Selektirati koje lokacije želi obraditi
• Pokrenuti generiranje za odabrane lokacije
• Pratiti troškove po broju karaktera

Koristi postojeći AudioTourGenerator.
```

---

## Glavni Generator: ContentOrchestrator

**Svrha**: Jedan ulazni punkt koji orkestrira cijeli pipeline.

```ruby
module Ai
  class ContentOrchestrator
    class GenerationError < StandardError; end

    def initialize(max_experiences: nil)
      @chat = RubyLLM.chat
      @geoapify = GeoapifyService.new
      @max_experiences = max_experiences  # nil = unlimited
    end

    # JEDINA METODA KOJU ADMIN POZIVA
    def generate
      # Faza 1: AI reasoning - šta treba uraditi?
      plan = analyze_and_plan

      # Faza 2-5: Izvršavanje plana
      execute_plan(plan)
    end

    private

    # ═══════════════════════════════════════════════════════════
    # FAZA 1: AI REASONING
    # ═══════════════════════════════════════════════════════════
    def analyze_and_plan
      # Prikupi trenutno stanje
      current_state = gather_current_state

      # Pitaj AI šta treba uraditi
      response = @chat.ask(build_reasoning_prompt(current_state))
      parse_ai_json_response(response.content)
    end

    def gather_current_state
      {
        # Postojeći gradovi iz baze - AI analizira gdje treba više sadržaja
        existing_cities: Location.distinct.pluck(:city).compact,
        locations_per_city: Location.group(:city).count,
        experiences_per_city: Experience.joins(:locations)
                                        .group("locations.city").count,
        plans_per_city: Plan.where("preferences->>'generated_by_ai' = 'true'")
                           .group(:city_name).count,
        # Država iz konfiguracije (ne hardkodirana lista)
        target_country: Setting.get("ai.target_country", default: "Bosnia and Herzegovina"),
        target_country_code: Setting.get("ai.target_country_code", default: "ba")
      }
    end

    def build_reasoning_prompt(state)
      <<~PROMPT
        #{Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT}

        ---

        TASK: Analiziraj trenutno stanje turističkog sadržaja i predloži plan akcija.

        CILJNA DRŽAVA: #{state[:target_country]} (#{state[:target_country_code]})

        TRENUTNO STANJE:
        - Postojeći gradovi: #{state[:existing_cities].join(", ")}
        - Lokacije po gradu: #{state[:locations_per_city]}
        - Iskustva po gradu: #{state[:experiences_per_city]}
        - AI planovi po gradu: #{state[:plans_per_city]}

        TVOJ ZADATAK:
        1. Analiziraj koji gradovi imaju premalo sadržaja
        2. Predloži nove gradove koji bi trebali biti pokriveni
        3. Odluči koje kategorije lokacija nedostaju
        4. Predloži profile turista za planove

        KATEGORIJE LOKACIJA (Geoapify - koristi bilo koju relevantnu):
        AI sam odlučuje koje kategorije su potrebne za državu.
        Primjeri: tourism, catering, natural, entertainment, accommodation,
        sport, leisure, heritage, commercial, service, itd.

        Geoapify podržava hijerarhijske kategorije (npr. catering.restaurant.pizza)
        AI treba odabrati najprikladnije za turistički sadržaj.

        Vrati JSON sa planom akcija:
        {
          "analysis": "Kratak opis trenutnog stanja...",
          "target_cities": [
            {
              "city": "Ime grada",
              "locations_to_fetch": 30,
              "categories": ["tourism.attraction", "catering.restaurant"],
              "reasoning": "Zašto ovaj grad..."
            }
          ],
          "tourist_profiles_to_generate": ["family", "couple", "culture"],
          "estimated_new_content": {
            "locations": 50,
            "experiences": 15,
            "plans": 12
          }
        }
      PROMPT
    end

    # ═══════════════════════════════════════════════════════════
    # FAZA 2-5: IZVRŠAVANJE
    # ═══════════════════════════════════════════════════════════
    def execute_plan(plan)
      plan[:target_cities].each do |city_plan|
        # Faza 2: Prikupljanje lokacija
        raw_places = fetch_locations(city_plan)

        # Faza 3: Obogaćivanje i spremanje lokacija
        locations = enrich_and_save_locations(raw_places, city_plan[:city])

        # Faza 4: Kreiranje iskustava
        create_experiences(locations, city_plan[:city])

        # Faza 5: Kreiranje planova
        create_plans(city_plan[:city], plan[:tourist_profiles_to_generate])
      end
    end

    def fetch_locations(city_plan)
      # Geoapify sa rate limitingom
    end

    def enrich_and_save_locations(places, city)
      # AI obogaćuje svaku lokaciju
    end

    def create_experiences(new_locations, city)
      # ExperienceCreator poštuje max_experiences limit
      creator = ExperienceCreator.new(max_experiences: @max_experiences)

      # 1. Lokalni Experience-i za ovaj grad
      creator.create_local_experiences(city: city)

      # 2. Tematski Experience-i koji koriste SVE lokacije iz baze
      #    (samo ako nije dostignut limit)
      creator.create_thematic_experiences
    end

    def create_plans(city, profiles)
      # Koristi SVE Experience-e iz baze (ne samo nove)
      # Jedan Experience može završiti u više Plan-ova
      profiles.each do |profile|
        PlanCreator.new.create_for_profile(profile: profile, city: city)
        PlanCreator.new.create_for_profile(profile: profile, city: nil) # Multi-city
      end
    end

    # NAPOMENA: Audio ture se NE generišu ovdje!
    # Pokreću se odvojeno zbog troškova ElevenLabs API-ja
  end
end
```

---

## Pomoćni Generatori (koristi ih Orchestrator)

### LocationEnricher
```ruby
module Ai
  class LocationEnricher
    # Obogaćuje jednu lokaciju sa AI sadržajem
    def enrich(location)
      # Opisi, historical_context, tags, suitable_experiences
    end
  end
end
```

### ExperienceCreator
```ruby
module Ai
  class ExperienceCreator
    # Kreira Experience-e koristeći SVE lokacije iz baze
    # Može koristiti lokacije iz RAZLIČITIH gradova za tematske ture

    def initialize(max_experiences: nil)
      @max_experiences = max_experiences  # nil = unlimited
      @created_count = 0
    end

    def create_thematic_experiences
      return if limit_reached?

      # AI analizira SVE lokacije iz baze i predlaže tematska grupisanja
      # Npr: "Tvrđave BiH" - lokacije iz Travnika, Jajca, Banja Luke, Počitelja
      all_locations = Location.all

      # AI vraća prijedloge, ali kreiramo samo do limita
      proposals = ai_propose_experiences(all_locations)
      proposals.take(remaining_slots).each do |proposal|
        create_experience(proposal)
        @created_count += 1
      end
    end

    def create_local_experiences(city:)
      return if limit_reached?

      city_locations = Location.where(city: city)
      proposals = ai_propose_experiences(city_locations, scope: :local)
      proposals.take(remaining_slots).each do |proposal|
        create_experience(proposal)
        @created_count += 1
      end
    end

    private

    def limit_reached?
      @max_experiences && @created_count >= @max_experiences
    end

    def remaining_slots
      @max_experiences ? (@max_experiences - @created_count) : Float::INFINITY
    end
  end
end
```

### PlanCreator
```ruby
module Ai
  class PlanCreator
    # Kreira Plan koristeći SVE Experience-e iz baze
    # Jedan Experience može biti u VIŠE planova

    def create_for_profile(profile:, city: nil)
      # AI analizira SVE dostupne Experience-e (ne samo nove)
      # i kreira optimalan plan za profil turista

      available_experiences = if city
        # Experience-i koji imaju BAR JEDNU lokaciju u tom gradu
        Experience.joins(:locations).where(locations: { city: city }).distinct
      else
        # Svi Experience-i za multi-city planove
        Experience.all
      end

      # AI odlučuje koje Experience-e uključiti i kako ih rasporediti po danima
    end

    # Experience može biti dodan u POSTOJEĆI Plan
    def add_experience_to_plan(experience, plan, day_number:)
      PlanExperience.create(plan: plan, experience: experience, day_number: day_number)
    end
  end
end
```

---

## Many-to-Many relacije (već postoje u bazi)

```
Location ◄──── N:M ────► Experience ◄──── N:M ────► Plan
         ExperienceLocation              PlanExperience
```

### Primjeri fleksibilnog grupisanja:

**Lokacija "Stari most Mostar"** može biti u:
- Experience "Historijski Mostar" (lokalna šetnja)
- Experience "UNESCO spomenici BiH" (sa Višegradom, Sarajevom)
- Experience "Mostovi Hercegovine" (sa Počitelj, Blagaj)

**Experience "Tvrđave BiH"** može sadržavati lokacije iz:
- Travnik (Stari grad)
- Banja Luka (Kastel)
- Jajce (Tvrđava)
- Počitelj (geografski razbacane, ali tematski povezane)

**Experience "Historijski Mostar"** može biti u:
- Plan "Romantični vikend Mostar"
- Plan "Porodični odmor Hercegovina"
- Plan "Budget backpacker BiH"

---

## Postojeća polja modela (bez migracija)

### Location (schema.rb:277-306)
- `name`, `description`, `historical_context` (translatable)
- `tags` (jsonb), `suitable_experiences` (jsonb)
- `budget` (enum), `city`, `lat`, `lng`
- `audio_tour_metadata` (jsonb) - za praktične info

### Experience (već postoji)
- `title`, `description` (translatable)
- `estimated_duration`, `experience_category_id`
- Veza sa Location kroz ExperienceLocation

### Plan (schema.rb:322-348)
- `title`, `notes` (translatable)
- `city_name`, `preferences` (jsonb)
- Veza sa Experience kroz PlanExperience

### preferences struktura za AI planove:
```ruby
{
  tourist_profile: "family",
  generated_by_ai: true,
  generation_metadata: { ... }
}
```

---

## Migracije baze podataka

### NEMA MIGRACIJA
Svi podaci idu u postojeća polja.

---

## Background Job

### ContentGenerationJob (JEDINI JOB)
```ruby
# app/jobs/content_generation_job.rb
class ContentGenerationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on RubyLLM::ConfigurationError if defined?(RubyLLM::ConfigurationError)

  def perform(max_experiences: nil)
    orchestrator = Ai::ContentOrchestrator.new(max_experiences: max_experiences)
    orchestrator.generate
  end
end
```

---

## Admin UI

### JEDAN EKRAN, JEDAN GUMB

**Ruta**: `GET /admin/ai`
**Controller**: `Admin::AiController`

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI Content Generator                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                                                                      │    │
│  │  Maksimalan broj Experience-a: [ 10 ▼ ]                             │    │
│  │                                                                      │    │
│  │                    [ GENERIŠI SADRŽAJ ]                             │    │
│  │                                                                      │    │
│  │     AI će automatski analizirati šta nedostaje i generisati:        │    │
│  │     • Nove lokacije za gradove koji nemaju dovoljno                 │    │
│  │     • Opise i prijevode za sve lokacije                             │    │
│  │     • Iskustva koja povezuju lokacije (max prema limitu)            │    │
│  │     • Planove putovanja za različite profile turista                │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  TRENUTNO STANJE                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                              │
│  Grad            Lokacije    Iskustva    Planovi    Audio                   │
│  ───────────────────────────────────────────────────────────────────────    │
│  Sarajevo        45          12          6          42/45                   │
│  Mostar          32          8           4          28/32                   │
│  Banja Luka      15          4           2          10/15                   │
│  Travnik         8           2           0          5/8                     │
│  Bihać           3           1           0          0/3                     │
│  ───────────────────────────────────────────────────────────────────────    │
│  UKUPNO          103         27          12         85/103                  │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  POSLJEDNJE GENERIRANJE                                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                              │
│  15.01.2024 10:30                                                           │
│  Status: Završeno                                                           │
│  Kreirano: 25 lokacija, 8 iskustava, 6 planova                             │
│  AI odlučio: Fokus na Travnik i Bihać (nedostajao sadržaj)                 │
│                                                                              │
│  [Pogledaj detaljan izvještaj]                                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Akcije ContentOrchestrator**:
- `index` - Prikazuje stanje i gumb za generiranje
- `generate` - POST - Pokreće `ContentGenerationJob` sa `max_experiences` parametrom
- `status` - GET (AJAX) - Status trenutnog generiranja
- `report` - GET - Detaljan izvještaj posljednjeg generiranja

**Parametar za kontrolu:**
```ruby
# Admin bira iz dropdown-a (5, 10, 20, 50, unlimited)
ContentGenerationJob.perform_later(max_experiences: params[:max_experiences])
```

---

## Admin UI: Audio Ture (ODVOJENO)

**Ruta**: `GET /admin/ai/audio_tours`
**Controller**: `Admin::Ai::AudioToursController`

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Audio Ture Generator                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  UPOZORENJE: ElevenLabs API ima troškove po karakteru!                      │
│  Procijenjeni trošak za odabrane lokacije: ~$X.XX                           │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  LOKACIJE BEZ AUDIO TURA                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                              │
│  [ ] Selektiraj sve                                                          │
│                                                                              │
│  [x] Stari most, Mostar (~2500 karaktera)                                   │
│  [x] Baščaršija, Sarajevo (~3000 karaktera)                                 │
│  [ ] Pliva vodopad, Jajce (~1800 karaktera)                                 │
│  [ ] Stari grad, Travnik (~2200 karaktera)                                  │
│  ...                                                                         │
│                                                                              │
│  Odabrano: 2 lokacije | Ukupno karaktera: ~5500 | Trošak: ~$0.08            │
│                                                                              │
│  [ GENERIŠI AUDIO ZA ODABRANE ]                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Akcije AudioTours**:
- `index` - Lista lokacija bez audio tura
- `generate` - POST - Generiše audio za odabrane lokacije
- `estimate_cost` - GET (AJAX) - Procjena troška za selekciju

---

## Rake Task

```ruby
# lib/tasks/ai.rake
namespace :ai do
  desc "Pokreni autonomno AI generiranje sadržaja"
  task generate: :environment do
    puts "=" * 60
    puts "AUTONOMNI AI GENERATOR SADRŽAJA"
    puts "=" * 60
    puts
    puts "AI će automatski:"
    puts "  1. Analizirati šta nedostaje"
    puts "  2. Odlučiti koje gradove obraditi"
    puts "  3. Prikupiti lokacije sa Geoapify"
    puts "  4. Obogatiti ih opisima i prevodima"
    puts "  5. Kreirati iskustva i planove"
    puts
    puts "Pokrećem..."
    puts

    ContentGenerationJob.perform_later

    puts "Job pokrenut!"
    puts "Pratite progress u admin panelu: /admin/ai"
    puts "=" * 60
  end

  desc "Prikaži trenutno stanje sadržaja"
  task status: :environment do
    puts "=" * 60
    puts "STANJE SADRŽAJA"
    puts "=" * 60
    puts

    Location.distinct.pluck(:city).compact.each do |city|
      locations = Location.where(city: city).count
      experiences = Experience.joins(:locations).where(locations: { city: city }).distinct.count
      plans = Plan.where(city_name: city).where("preferences->>'generated_by_ai' = 'true'").count
      audio = Location.where(city: city).joins(:audio_tours).merge(AudioTour.with_audio).distinct.count

      puts "#{city.ljust(20)} #{locations.to_s.rjust(3)} lok | #{experiences.to_s.rjust(2)} isk | #{plans.to_s.rjust(2)} plan | #{audio}/#{locations} audio"
    end

    puts
    puts "=" * 60
  end
end
```

---

## Fajlovi za kreiranje/modifikaciju

### Novi fajlovi
| Fajl | Opis |
|------|------|
| `app/services/ai/content_orchestrator.rb` | Glavni orkestratar - jedini ulazni punkt |
| `app/services/ai/location_enricher.rb` | Obogaćuje lokacije AI sadržajem |
| `app/services/ai/experience_creator.rb` | Kreira Experience-e od lokacija |
| `app/services/ai/plan_creator.rb` | Kreira Plan-ove za profile turista |
| `app/services/ai/rate_limiter.rb` | Rate limiting za Geoapify (5 req/sec) |
| `app/jobs/content_generation_job.rb` | Background job za sadržaj |
| `app/controllers/admin/ai_controller.rb` | Admin controller - glavni generator |
| `app/controllers/admin/ai/audio_tours_controller.rb` | Admin controller - audio ture (odvojeno) |
| `app/views/admin/ai/index.html.erb` | Dashboard sa gumbom i statistikama |
| `app/views/admin/ai/_stats_table.html.erb` | Partial za tabelu stanja |
| `app/views/admin/ai/_last_generation.html.erb` | Partial za izvještaj |
| `app/views/admin/ai/audio_tours/index.html.erb` | Lista lokacija za audio ture |
| `lib/tasks/ai.rake` | Rake taskovi (generate, status) |

### Modifikacije postojećih fajlova
| Fajl | Izmjena |
|------|---------|
| `config/routes.rb` | Dodati `resource :ai, only: [:index], controller: 'ai'` u admin namespace |

**NAPOMENA**: Modeli `Location`, `Experience` i `Plan` se NE mijenjaju - svi podaci idu u postojeća polja.

---

## Redoslijed implementacije

### Faza 1: Infrastruktura
1. Kreirati `app/services/ai/rate_limiter.rb` - Geoapify rate limiting (5 req/sec)
2. Konfigurirati Setting za državu (`ai.target_country`, `ai.target_country_code`)
3. Testirati rate limiting sa Geoapify API

### Faza 2: Pomoćni generatori
1. Kreirati `app/services/ai/location_enricher.rb`
   - Metoda `enrich(location)` - dodaje opise, tags, historical_context
   - Koristi postojeća polja bez migracija
2. Kreirati `app/services/ai/experience_creator.rb`
   - Metoda `create_thematic_experiences` i `create_local_experiences`
   - Poštuje `max_experiences` limit
3. Kreirati `app/services/ai/plan_creator.rb`
   - Metoda `create_for_profile(profile:, city:)`
   - Sprema u Plan.preferences kao `generated_by_ai: true`

### Faza 3: ContentOrchestrator
1. Kreirati `app/services/ai/content_orchestrator.rb`
2. Implementirati Fazu 1: AI Reasoning (`analyze_and_plan`)
3. Implementirati Faze 2-5: Izvršavanje (`execute_plan`)
4. Testirati end-to-end na malom skupu podataka

### Faza 4: Background Job
1. Kreirati `app/jobs/content_generation_job.rb`
2. Implementirati retry logiku i error handling
3. Dodati logging za praćenje progresa

### Faza 5: Admin UI
1. Dodati rutu u `config/routes.rb`
2. Kreirati `Admin::AiController` sa akcijama: index, generate, status, report
3. Kreirati view sa Tailwind CSS (jedan ekran, jedan gumb)
4. Dodati navigaciju u admin layout

### Faza 6: Rake taskovi i testiranje
1. Kreirati `lib/tasks/ai.rake` (generate, status)
2. End-to-end testiranje cijelog pipeline-a
3. Optimizacija AI promptova na osnovu rezultata
4. Dokumentacija za admina

---

## Arhitekturne napomene

### Bazni obrazac za sve AI servise
```ruby
module Ai
  class ServiceName
    class GenerationError < StandardError; end

    def initialize
      @chat = RubyLLM.chat
    end

    private

    # Referencirati BIH_CULTURAL_CONTEXT iz ExperienceGenerator
    def cultural_context
      Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT
    end

    # Koristiti Setting za konfiguraciju
    def setting(key, default:)
      Setting.get(key, default: default)
    end

    # Podržani jezici iz baze
    def supported_locales
      @supported_locales ||= Locale.ai_supported_codes.presence ||
        %w[en bs hr de es fr it pt nl pl cs sk sl sr]
    end

    # Logiranje sa prefiksom
    def log_info(message)
      Rails.logger.info "[AI::#{self.class.name.demodulize}] #{message}"
    end

    def log_error(message)
      Rails.logger.error "[AI::#{self.class.name.demodulize}] #{message}"
    end

    # Parsiranje AI odgovora (JSON iz markdown bloka)
    def parse_ai_json_response(content)
      json_match = content.match(/```(?:json)?\s*([\s\S]*?)```/) ||
                  content.match(/(\{[\s\S]*\})/)
      json_str = json_match ? json_match[1] : content
      JSON.parse(json_str, symbolize_names: true)
    rescue JSON::ParserError => e
      log_error "Failed to parse AI response: #{e.message}"
      {}
    end
  end
end
```

### Error handling strategija
| Tip greške | Akcija |
|------------|--------|
| Non-critical (npr. jedan AI prompt fails) | `Rails.logger.warn` + nastavi dalje |
| Critical (npr. Geoapify down) | `raise GenerationError` → job retry |
| JSON parse error | return `{}` + log warning |
| Rate limit exceeded | automatic retry sa exponential backoff |

### Background Job konfiguracija
```ruby
class ContentGenerationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on RubyLLM::ConfigurationError if defined?(RubyLLM::ConfigurationError)
end
```

### Geoapify Rate Limiting (KRITIČNO)
**Limit: 5 zahtjeva po sekundi - NIKADA ne prekoračiti!**

```ruby
# app/services/ai/rate_limiter.rb
module Ai
  class RateLimiter
    GEOAPIFY_RATE_LIMIT = 5  # requests per second

    def self.with_geoapify_limit(items)
      items.each_slice(GEOAPIFY_RATE_LIMIT).each_with_index do |batch, index|
        yield batch
        sleep(1.1) if index < (items.size.to_f / GEOAPIFY_RATE_LIMIT).ceil - 1
      end
    end
  end
end

# Korištenje u ContentOrchestrator
def fetch_locations(city_plan)
  # AI je odlučio koje kategorije treba za ovaj grad
  categories = city_plan[:categories]
  country_code = Setting.get("ai.target_country_code", default: "ba")

  Ai::RateLimiter.with_geoapify_limit(categories) do |batch|
    batch.each do |category|
      @geoapify.search_places(
        categories: [category],
        filter: "countrycode:#{country_code}",  # Osigurava samo ciljanu državu
        bias: "proximity:#{city_plan[:city]}",  # Prioritet blizu grada
        limit: city_plan[:locations_to_fetch] / categories.size
      )
    end
  end
end
```

### Određivanje države (bez hardkodirane liste gradova)

**Pristup 1: Konfiguracija u Setting modelu**
```ruby
# Admin može promijeniti ciljanu državu
Setting.set("ai.target_country", "Bosnia and Herzegovina")
Setting.set("ai.target_country_code", "ba")  # ISO 3166-1 alpha-2
```

**Pristup 2: Geoapify API filter**
```ruby
# Traži samo u ciljanoj državi koristeći country code filter
@geoapify.search_places(
  categories: ["tourism.attraction", "catering.restaurant"],
  filter: "countrycode:ba",  # ISO 3166-1 alpha-2
  limit: 50
)
```

**Pristup 3: Validacija odgovora**
```ruby
# Geoapify vraća country u odgovoru - validirati prije spremanja
def valid_location?(place_data)
  place_data["country"] == Setting.get("ai.target_country")
end
```

**Pristup 4: Postojeći gradovi iz baze**
```ruby
# AI reasoning koristi gradove koji VEĆ postoje u Location.city
def gather_current_state
  {
    existing_cities: Location.distinct.pluck(:city).compact,
    locations_per_city: Location.group(:city).count,
    # AI može predložiti nove gradove, ali Geoapify filter osigurava državu
  }
end
```

**Kombinacija svih pristupa:**
- `Setting` definira ciljanu državu
- Geoapify `filter: countrycode:xx` osigurava da dohvaćamo samo lokacije iz ciljane države
- Validacija odgovora kao dodatna provjera
- AI reasoning analizira postojeće gradove i predlaže gdje treba više sadržaja

### Mapiranje podataka u postojeća polja

#### Location model
| Podatak | Polje | Napomena |
|---------|-------|----------|
| Naziv | `name` | Translatable |
| Opis | `description` | Translatable |
| Historijski kontekst | `historical_context` | Translatable, za audio |
| Tagovi | `tags` | JSONB array |
| Tipovi iskustava | `suitable_experiences` | JSONB array |
| Praktične info | `audio_tour_metadata` | JSONB hash |
| Koordinate | `lat`, `lng` | Float |
| Grad | `city` | String |
| Budget | `budget` | Enum (low/medium/high) |

#### Plan model
| Podatak | Polje | Napomena |
|---------|-------|----------|
| Naziv | `title` | Translatable |
| Bilješke | `notes` | Translatable |
| Grad | `city_name` | String |
| Profil turista | `preferences["tourist_profile"]` | JSONB |
| AI generiran | `preferences["generated_by_ai"]` | JSONB boolean |
| Metadata | `preferences["generation_metadata"]` | JSONB hash |

### Praćenje generiranja
Spremati u `Setting` model za prikaz u admin UI:
```ruby
Setting.set("ai.last_generation.started_at", Time.current.iso8601)
Setting.set("ai.last_generation.status", "in_progress")
Setting.set("ai.last_generation.cities", target_cities.to_json)
Setting.set("ai.last_generation.results", results.to_json)
```
