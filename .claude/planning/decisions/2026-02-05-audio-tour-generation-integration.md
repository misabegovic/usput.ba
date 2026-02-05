# ADR-0005: Audio Tour Generation Integration in Curator Dashboard

## Status
Proposed

## Datum
2026-02-05

## Autori
Tech Lead, Product Manager

## Context

`Ai::AudioTourGenerator` servis već postoji (705 linija) sa punom funkcionalnošću:
- Generisanje AI skripte za lokaciju
- Text-to-speech preko ElevenLabs (26 glasova), OpenAI, ili Google Cloud
- Multilingvalna podrška (bs, en, de, fr, itd.)
- Batch generisanje za više lokacija
- Number-to-words konverzija za prirodan govor

Međutim, **nema UI za pokretanje generisanja**. Trenutno se audio ture generišu samo:
- Direktno iz Rails konzole
- Kroz Platform CLI (`bin/platform`)
- Nema način da admin ili kurator pokrene generisanje iz dashboarda

### Trenutno stanje u curator dashboard-u

- Audio Tours imaju CRUD u curator dashboardu (iza feature flaga)
- Location show stranica nema nikakav audio tour status ili player
- `AudioTour` model postoji sa: `location_id`, `locale`, `script`, `word_count`, `duration`
- Lokacije imaju `audio_file` Active Storage attachment

### Troškovi

ElevenLabs API:
- ~$0.30 po minuti generisanog audio-a (Creator plan)
- Prosječna tura: 3-5 minuta = ~$1-1.50 po turi
- Sa 26 glasova dostupnih, voice selection je besplatan

OpenAI TTS:
- $15 per 1M characters (HD quality)
- Prosječna tura ~2000 characters = ~$0.03 po turi
- Značajno jeftinije ali manja kvaliteta za bosanski

## Decision

Integrisati audio tour generisanje u curator dashboard kao **admin-only akciju** na location show stranici, sa background job izvršavanjem i real-time status prikazom.

### 1. Background Job

```ruby
# app/jobs/audio_tour_generate_job.rb
class AudioTourGenerateJob < ApplicationJob
  queue_as :default

  def perform(location_id:, locale:, requested_by_id:, voice_id: nil)
    location = Location.find(location_id)
    user = User.find(requested_by_id)

    generator = Ai::AudioTourGenerator.new(location)

    # Provjeri da li audio već postoji za ovaj locale
    if generator.audio_exists?(locale) && !force
      Rails.logger.info "Audio already exists for #{location.name} (#{locale})"
      return
    end

    result = generator.generate(locale, force: false)

    # Zabilježi aktivnost
    CuratorActivity.record(
      user: user,
      action: "audio_tour_generated",
      recordable: location,
      metadata: {
        locale: locale,
        voice_id: voice_id,
        duration: result&.dig(:duration)
      }
    )
  rescue => e
    # Zabilježi grešku
    CuratorActivity.record(
      user: user,
      action: "audio_tour_generation_failed",
      recordable: location,
      metadata: {
        locale: locale,
        error: e.message
      }
    )
    raise # Re-raise za Solid Queue retry
  end
end
```

### 2. Controller akcija

```ruby
# app/controllers/curator/locations_controller.rb
# Dodati u existing controller

def generate_audio_tour
  @location = Location.find(params[:id])

  unless current_user.admin?
    redirect_to curator_location_path(@location),
      alert: "Samo admin može generisati audio ture."
    return
  end

  locale = params[:locale] || "bs"

  # Provjeri da li već postoji pending job
  # (Solid Queue nema built-in dedup, ali možemo provjeriti
  #  CuratorActivity za recent generation request)
  recent_request = CuratorActivity
    .where(action: "audio_tour_generation_requested")
    .where(recordable: @location)
    .where("created_at > ?", 10.minutes.ago)
    .exists?

  if recent_request
    redirect_to curator_location_path(@location),
      alert: "Generisanje je već pokrenuto. Sačekajte da se završi."
    return
  end

  AudioTourGenerateJob.perform_later(
    location_id: @location.id,
    locale: locale,
    requested_by_id: current_user.id
  )

  record_activity("audio_tour_generation_requested",
    recordable: @location,
    metadata: { locale: locale }
  )

  redirect_to curator_location_path(@location),
    notice: "Audio tura za #{locale.upcase} se generise u pozadini."
end
```

### 3. Ruta

```ruby
namespace :curator do
  resources :locations do
    member do
      post :generate_audio_tour
    end
    # ... existing routes
  end
end
```

### 4. UI na Location Show stranici

Dodati sekciju na `curator/locations/show.html.erb`:

```erb
<!-- Audio Tour Status -->
<div class="rounded-lg bg-white dark:bg-gray-800 shadow">
  <div class="px-4 py-5 sm:px-6">
    <h3 class="text-lg font-medium">Audio Tura</h3>

    <% audio_tour = @location.audio_tours.first %>
    <% if audio_tour&.audio_file&.attached? %>
      <!-- Player za postojeću turu -->
      <div class="mt-3">
        <audio controls class="w-full">
          <source src="<%= url_for(audio_tour.audio_file) %>">
        </audio>
        <p class="text-sm text-gray-500 mt-1">
          <%= audio_tour.locale.upcase %> ·
          <%= audio_tour.duration || "N/A" %> ·
          <%= audio_tour.word_count || "N/A" %> riječi
        </p>
      </div>
    <% else %>
      <p class="text-sm text-gray-500 mt-2">
        Nema audio ture za ovu lokaciju.
      </p>
    <% end %>

    <% if current_user.admin? %>
      <!-- Generate button - admin only -->
      <div class="mt-4 flex items-center gap-3">
        <%= form_with url: generate_audio_tour_curator_location_path(@location),
                      method: :post, class: "flex items-center gap-2" do |f| %>
          <%= f.select :locale,
              [["Bosanski", "bs"], ["English", "en"], ["Deutsch", "de"]],
              {}, class: "rounded-md border-gray-300 text-sm" %>
          <%= f.submit "Generiši audio turu",
              class: "inline-flex items-center rounded-md bg-blue-600 px-3 py-2
                     text-sm font-semibold text-white shadow-sm hover:bg-blue-500",
              data: { confirm: "Generisanje audio ture košta ~$1-1.50. Nastaviti?" } %>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

### 5. CuratorActivity proširenje

Dodati nove action types:

```ruby
# U CuratorActivity modelu
ACTIONS = [
  # ... existing actions ...
  "audio_tour_generation_requested",
  "audio_tour_generated",
  "audio_tour_generation_failed"
]
```

### 6. Zaštite

| Zaštita | Implementacija |
|---------|----------------|
| **Admin-only** | `current_user.admin?` check u controlleru |
| **Rate limiting** | Provjera CuratorActivity za duplicate request u zadnjih 10 min |
| **Cost awareness** | `data-confirm` dialog sa informacijom o cijeni |
| **Error handling** | Job bilježi grešku u CuratorActivity, re-raise za retry |
| **Audit trail** | Svaki request i rezultat zabilježen kao CuratorActivity |

## Consequences

### Positive

- **Samoposlužno generisanje** — Admin može generisati audio ture bez Rails konzole ili CLI
- **Audit trail** — Svako generisanje je zabilježeno sa korisnik, locale, trajanje
- **Background processing** — Ne blokira UI. Solid Queue radi retry na failure.
- **Cost visibility** — Confirmation dialog upozorava na cijenu
- **Duplicate prevention** — Rate limiting sprečava slučajno dvostruko pokretanje
- **Status prikaz** — Admin i kurator odmah vide da li lokacija ima audio turu

### Negative

- **Nema real-time progress** — Korisnik ne vidi progress generisanja. Mora refreshati stranicu. (Turbo Stream upgrade je moguć u budućnosti)
- **Nema voice selection u UI** — Trenutno koristi default/random voice. Voice picker bi bio nice-to-have.
- **Jedan locale po request** — Admin mora pokrenuti generisanje za svaki jezik posebno. Batch multilingvalno generisanje je moguće kao poboljšanje.

### Neutral

- **Postojeći AudioTour CRUD ostaje** — Admin može i dalje ručno editovati script, metadata. Generisanje je dopuna, ne zamjena.
- **OpenAI vs ElevenLabs izbor** — Ostaje na konfiguraciji servisa, ne na UI odluci.

## Alternatives Considered

### Opcija 1: Audio Tour CRUD je dovoljan

Admin edituje AudioTour script ručno, upload-a audio fajl.

- **Prednosti:** Nema API troškova. Potpuna kontrola.
- **Mane:** Ručno pisanje skripte je sporo. Ručni TTS je workflow izvan platforme.
- **Zašto odbačeno:** Generator već postoji i radi. Ne iskoristiti ga je gubitak.

### Opcija 2: Batch generisanje sa dashboard stranice

Posebna stranica "Generiši audio ture" sa checkbox listom lokacija.

- **Prednosti:** Efikasno za bulk generisanje.
- **Mane:** Ogroman API trošak ako se greškom pokrene za 100 lokacija. Teže za kontrolu.
- **Zašto odbačeno:** Per-location generisanje je sigurnije za početak. Batch se može dodati kad se uspostavi workflow.

### Opcija 3: Kurator može pokrenuti generisanje

Dozvoli i kuratorima da pokreću audio generisanje.

- **Prednosti:** Manje bottleneck-a na adminu.
- **Mane:** Kurator može nepotrebno trošiti API budget. Nema cost accountability.
- **Zašto odbačeno:** Troškovi su realni (~$1.50 po turi). Samo admin treba imati tu odgovornost. Može se proširiti na kuratore kad se uspostavi budget monitoring.

## References

- RFC-0001: Curator Dashboard v2 (`.claude/planning/rfcs/0001-curator-dashboard-v2.md`)
- `Ai::AudioTourGenerator` servis (`app/services/ai/audio_tour_generator.rb`)
- `AudioTour` model (`app/models/audio_tour.rb`)
- ElevenLabs API pricing: https://elevenlabs.io/pricing
