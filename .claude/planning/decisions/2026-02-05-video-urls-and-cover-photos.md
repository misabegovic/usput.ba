# ADR-0006: Multiple Video URLs + Cover Photo Support

## Status
Proposed

## Datum
2026-02-05

## Autori
Product Manager, Tech Lead

## Context

### Video URL — trenutno stanje

`Location` ima jednu `video_url` string kolonu. Ovo je ograničavajuće:
- Lokacija može imati više videa (YouTube tura, drone snimak, Instagram reel, TikTok)
- Jedan URL ne pokriva različite platforme i formate
- `Experience` i `Plan` nemaju nikakvu video podršku

### Cover Photo — trenutno stanje

| Model | Cover Photo | Kako |
|-------|-------------|------|
| Location | `has_many_attached :photos` | Active Storage, više slika, thumb/medium/large varijante |
| Experience | `has_one_attached :cover_photo` | Active Storage, jedna slika, nema varijanti |
| Plan | Nema | Derivira iz experience-a kroz `display_cover_photos` |

Experience već ima `cover_photo` ali Plan nema direktan upload — oslanja se na fotografije iz asociranih iskustava. Problem: plan bez iskustava nema cover photo, a admin ponekad želi specifičnu sliku za plan.

## Decision

### 1. Multiple video URLs na Location i Experience

Zamijeniti `video_url` (string kolona) sa `video_urls` (JSONB array) na Location. Dodati isto na Experience.

```ruby
# Migration za Location
class ChangeVideoUrlToVideoUrlsOnLocations < ActiveRecord::Migration[8.0]
  def up
    add_column :locations, :video_urls, :jsonb, default: []

    # Migracija postojećih podataka
    execute <<-SQL
      UPDATE locations
      SET video_urls = jsonb_build_array(video_url)
      WHERE video_url IS NOT NULL AND video_url != ''
    SQL

    remove_column :locations, :video_url
  end

  def down
    add_column :locations, :video_url, :string

    execute <<-SQL
      UPDATE locations
      SET video_url = video_urls->>0
      WHERE jsonb_array_length(video_urls) > 0
    SQL

    remove_column :locations, :video_urls
  end
end

# Migration za Experience
class AddVideoUrlsToExperiences < ActiveRecord::Migration[8.0]
  def change
    add_column :experiences, :video_urls, :jsonb, default: []
  end
end
```

```ruby
# app/models/location.rb
class Location < ApplicationRecord
  # Validacija video URL-ova
  validate :valid_video_urls

  private

  def valid_video_urls
    return if video_urls.blank?

    video_urls.each_with_index do |url, i|
      unless url.match?(URI::DEFAULT_PARSER.make_regexp(%w[http https]))
        errors.add(:video_urls, "URL ##{i + 1} is not valid")
      end
    end
  end
end

# app/models/experience.rb — ista validacija
```

**UI — Video URLs forma:**
```erb
<%# Dinamički fieldset — dodaj/ukloni URL-ove %>
<div data-controller="dynamic-fields">
  <% (resource.video_urls.presence || [""]).each_with_index do |url, i| %>
    <div class="flex gap-2" data-dynamic-fields-target="field">
      <%= f.url_field "video_urls[]", value: url, placeholder: "https://youtube.com/..." %>
      <button type="button" data-action="dynamic-fields#remove">Ukloni</button>
    </div>
  <% end %>
  <button type="button" data-action="dynamic-fields#add">+ Dodaj video</button>
</div>
```

### 2. Cover Photo na Plan modelu

```ruby
# Migration
class AddCoverPhotoToPlans < ActiveRecord::Migration[8.0]
  # Active Storage ne zahtijeva migraciju — koristi existing active_storage_attachments
  # Samo treba dodati has_one_attached u model
end

# app/models/plan.rb
class Plan < ApplicationRecord
  has_one_attached :cover_photo

  def display_cover_photo
    # Prioritet: direktan upload > experience cover > location photo
    return cover_photo if cover_photo.attached?

    # Postojeći fallback
    experiences_with_photos = experiences.select { |e| e.cover_photo.attached? }
    return experiences_with_photos.first.cover_photo if experiences_with_photos.any?

    # Dalje fallback na lokacije
    experiences.each do |exp|
      exp.locations.each do |loc|
        return loc.photos.first if loc.photos.attached?
      end
    end

    nil
  end
end
```

**UI — Plan Cover Photo forma:**
```erb
<%# Isti pattern kao Experience forma %>
<% if plan.persisted? && plan.cover_photo.attached? %>
  <div class="mb-4">
    <%= image_tag rails_blob_path(plan.cover_photo, disposition: "inline"),
                  class: "h-32 w-48 object-cover rounded-lg" %>
    <label>
      <%= check_box_tag "plan[remove_cover_photo]", "1" %>
      Ukloni cover photo
    </label>
  </div>
<% end %>
<%= f.file_field :cover_photo, accept: "image/*" %>
<p class="text-xs text-gray-500">Preporučena veličina: 1200x800px</p>
```

### 3. Varijante za Experience cover_photo

Experience ima `has_one_attached :cover_photo` ali nema definirane varijante. Dodati za konzistentnost sa Location:

```ruby
# app/models/experience.rb
has_one_attached :cover_photo do |attachable|
  attachable.variant :thumb, resize_to_limit: [200, 200]
  attachable.variant :medium, resize_to_limit: [400, 400]
  attachable.variant :large, resize_to_limit: [800, 800]
end

# app/models/plan.rb — isti varijante
has_one_attached :cover_photo do |attachable|
  attachable.variant :thumb, resize_to_limit: [200, 200]
  attachable.variant :medium, resize_to_limit: [400, 400]
  attachable.variant :large, resize_to_limit: [800, 800]
end
```

### 4. Uticaj na Suggestion modele

Ove promjene zahtijevaju ažuriranje per-resource suggestion modela (ADR-0003):

```ruby
# LocationSuggestion — dodati:
t.jsonb :proposed_video_urls, default: []
# (proposed_photos već postoji kroz Active Storage)

# ExperienceSuggestion — dodati:
t.jsonb :proposed_video_urls, default: []
# (proposed_cover_photo već postoji kroz Active Storage)

# PlanSuggestion — dodati:
# (proposed_cover_photo — novi, kroz Active Storage)
has_one_attached :proposed_cover_photo
```

Iste kolone treba dodati i na odgovarajuće contribution modele.

## Consequences

### Positive

- **Više videa po lokaciji** — YouTube, drone, TikTok, Instagram — svi na jednom mjestu
- **Video na iskustvima** — Experience može imati promo video ili tutorial
- **Direktan cover za planove** — Admin ne zavisi od experience-a za vizual plana
- **Konzistentne varijante** — Svi modeli imaju thumb/medium/large
- **Backward compatible** — Migracija čuva postojeće video_url podatke

### Negative

- **JSONB za URL-ove** — Nema foreign key constraint. URL validacija mora biti u modelu.
- **Stimulus controller** — Potreban `dynamic-fields` Stimulus controller za add/remove UI. Nije kompleksno ali je novi JS.
- **Plan cover photo može biti zbunjujuć** — Ako plan ima i direktnu sliku i experience slike, šta se prikazuje? (Riješeno prioritetom u `display_cover_photo`)

### Neutral

- **Active Storage ne zahtijeva migraciju** — Polimorfna tabela se koristi automatski kad se doda `has_one_attached`.
- **Video URL ne zahtijeva embed** — Za sada čuvamo samo URL. Embed/player se može dodati kasnije.

## Alternatives Considered

### Opcija 1: Odvojena video_urls tabela (has_many)

```ruby
class LocationVideo < ApplicationRecord
  belongs_to :location
  validates :url, presence: true
  validates :platform, inclusion: { in: %w[youtube tiktok instagram other] }
end
```

- **Prednosti:** Čistiji model. Može se dodati platform, title, thumbnail.
- **Mane:** Previše overhead za listu URL-ova. Svaki video je novi DB record. CRUD za nested resources.
- **Zašto odbačeno:** JSONB array je dovoljno za URL-ove. Ako zatrebaju metapodaci, može se migrirati u budućnosti.

### Opcija 2: Zadržati video_url (singular) i dodati video_url na Experience

- **Prednosti:** Minimalna promjena.
- **Mane:** Lokacija sa više videa i dalje ne može čuvati sve. Problem se samo širi.
- **Zašto odbačeno:** Korisnik eksplicitno želi više video URL-ova.

## References

- ADR-0003: Per-Resource Suggestion Models (`.claude/planning/decisions/2026-02-05-per-resource-suggestion-models.md`)
- RFC-0001: Curator Dashboard v2 (`.claude/planning/rfcs/0001-curator-dashboard-v2.md`)
- Location model (`app/models/location.rb`)
- Experience model (`app/models/experience.rb`)
- Plan model (`app/models/plan.rb`)
