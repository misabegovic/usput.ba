# RFC-0001: Curator Dashboard v2 — Per-Resource Suggestions, Reviews, Audio Tours

## Summary

Kompletna refaktorizacija curator dashboard sistema. Zamjena nefunkcionalnog polimorfnog `ContentChange` modela sa **per-resource suggestion modelima**, dodavanje **reviews upravljanja**, i integracija **audio tour generisanja** direktno iz curator dashboarda. Admin korisnici dobijaju direktan CRUD, kuratori predlažu promjene.

## Motivation

### Problem

Trenutni `ContentChange` model ne radi na produkciji. Samo `PhotoSuggestion` funkcioniše. Ključni problemi:

1. **Jedan model za sve resurse** — Polimorfni JSONB pristup ne može pokriti specifičnosti svakog resursa (M2M asocijacije za lokacije, ordered lokacije za iskustva, dnevni raspored za planove)
2. **Fotografije isključene iz prijedloga** — Kod eksplicitno kaže `File attachments are not included in proposals`. Kurator popuni formu sa slikama, ali prijedlog ih ignoriše
3. **Type mismatch pri approve** — Form parametri su stringovi, JSONB deserijalizacija ne konvertuje tipove nazad
4. **Merge contributions gubi podatke** — Shallow `Hash#merge!` znači da zadnji kurator prepiše prethodnog
5. **Zbunjujući UX za create** — Kurator "kreira" lokaciju koja ne postoji dok admin ne odobri
6. **PhotoSuggestion je odvojen** — Dokazuje da per-resource pristup radi, ali lekcija nije primijenjena na ostale resurse

### Ko je affected?

- **Kuratori** — Ne mogu predlagati promjene osim slika
- **Admini** — Ne mogu direktno upravljati sadržajem (sve je iza disabled feature flaga)
- **Platforma** — Sadržaj stagnira jer nema efikasnog workflow-a za promjene

### Zašto sada?

Feature flag `curator_edit_delete` je disabled na produkciji. Jedina funkcionalna akcija za kuratore je predlaganje slika. Platforma treba funkcionalan content management odmah.

## Detailed Design

### Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Curator Dashboard                     │
├──────────────┬──────────────────────────────────────────┤
│   Admin      │  Direktan CRUD na svim resursima         │
│   (user_type │  + Pregled i odobravanje suggestion-a    │
│    = admin)  │  + Upravljanje reviews                   │
│              │  + Pokretanje audio tour generisanja      │
├──────────────┼──────────────────────────────────────────┤
│   Curator    │  Read-only pregled resursa               │
│   (user_type │  + PhotoSuggestion (postoji, radi)       │
│    = curator)│  + LocationSuggestion (novo)             │
│              │  + ExperienceSuggestion (novo)           │
│              │  + PlanSuggestion (novo)                 │
│              │  + Pregled reviews                       │
└──────────────┴──────────────────────────────────────────┘
```

### Princip dizajna: Dva režima rada

**Admin režim:** Direktan CRUD. Forme rade kao standardne Rails forme — `Location.create!`, `Location.update!`, `Location.destroy!`. Nema proposal workflow-a. Admin je autoritet.

**Curator režim:** Suggestion-based. Kurator vidi resurs, klikne "Predloži promjenu", popuni formu specifičnu za taj resurs. Suggestion se kreira sa statusom `pending`. Admin odobri ili odbije.

### Data Model

#### A. Per-Resource Suggestion modeli

```ruby
# Zajednički concern za sve suggestion modele
# app/models/concerns/suggestable.rb
module Suggestable
  extend ActiveSupport::Concern

  included do
    belongs_to :user                      # Kurator koji predlaže
    belongs_to :reviewed_by, class_name: "User", optional: true

    enum :status, { pending: 0, approved: 1, rejected: 2 }
    enum :change_type, { create_resource: 0, update_resource: 1, delete_resource: 2 }

    validates :status, presence: true
    validates :user, presence: true

    scope :pending_review, -> { where(status: :pending) }
    scope :recent, -> { order(created_at: :desc) }
  end

  def approve!(admin, notes: nil)
    transaction do
      apply_changes!
      update!(
        status: :approved,
        reviewed_by: admin,
        reviewed_at: Time.current,
        admin_notes: notes
      )
    end
  end

  def reject!(admin, notes: nil)
    update!(
      status: :rejected,
      reviewed_by: admin,
      reviewed_at: Time.current,
      admin_notes: notes
    )
  end
end
```

```ruby
# app/models/location_suggestion.rb
class LocationSuggestion < ApplicationRecord
  include Suggestable

  belongs_to :location, optional: true  # nil za create_resource

  # Typed kolone umjesto JSONB
  # Tekst polja
  attribute :proposed_name, :string
  attribute :proposed_city, :string
  attribute :proposed_description, :text
  attribute :proposed_historical_context, :text

  # Koordinate
  attribute :proposed_lat, :decimal
  attribute :proposed_lng, :decimal

  # Kontakt
  attribute :proposed_phone, :string
  attribute :proposed_email, :string
  attribute :proposed_website, :string

  # Kategorije i tagovi
  attribute :proposed_category_ids, :json     # Array integer IDs
  attribute :proposed_experience_type_ids, :json
  attribute :proposed_tags, :json             # Array stringova

  # Fotografije - Active Storage
  has_many_attached :proposed_photos

  validates :proposed_name, presence: true, if: :create_resource?
  validates :proposed_city, presence: true, if: :create_resource?
  validates :location, presence: true, unless: :create_resource?

  private

  def apply_changes!
    case change_type.to_sym
    when :create_resource
      location = LocationCreator.new(build_attributes).call
      update!(location: location.location)
    when :update_resource
      LocationUpdater.new(location, changed_attributes_only).call
    when :delete_resource
      location.destroy!
    end
  end

  def build_attributes
    # Vraća hash samo sa popunjenim poljima, typed
    # Nema JSONB konverzija, nema type mismatch
  end

  def changed_attributes_only
    # Vraća samo polja koja se razlikuju od location originals
  end
end
```

```ruby
# app/models/experience_suggestion.rb
class ExperienceSuggestion < ApplicationRecord
  include Suggestable

  belongs_to :experience, optional: true

  attribute :proposed_title, :string
  attribute :proposed_description, :text
  attribute :proposed_category_id, :integer
  attribute :proposed_duration, :integer
  attribute :proposed_seasons, :json            # ["spring", "summer"]
  attribute :proposed_location_uuids, :json     # ordered array

  # Kontakt
  attribute :proposed_contact_name, :string
  attribute :proposed_contact_email, :string
  attribute :proposed_contact_phone, :string
  attribute :proposed_contact_website, :string

  # Cover photo
  has_one_attached :proposed_cover_photo

  validates :proposed_title, presence: true, if: :create_resource?
  validates :experience, presence: true, unless: :create_resource?

  private

  def apply_changes!
    case change_type.to_sym
    when :create_resource
      # Kreira experience + sync lokacije
    when :update_resource
      # Update experience + re-sync lokacije ako se promijenile
    when :delete_resource
      experience.destroy!
    end
  end
end
```

```ruby
# app/models/plan_suggestion.rb
class PlanSuggestion < ApplicationRecord
  include Suggestable

  belongs_to :plan, optional: true

  attribute :proposed_title, :string
  attribute :proposed_city_name, :string
  attribute :proposed_notes, :text
  attribute :proposed_visibility, :string
  attribute :proposed_start_date, :date
  attribute :proposed_end_date, :date
  attribute :proposed_preferences, :json     # {budget:, daily_hours:}
  attribute :proposed_experience_days, :json # {1: [uuid1], 2: [uuid2]}

  validates :proposed_title, presence: true, if: :create_resource?
  validates :plan, presence: true, unless: :create_resource?
end
```

#### B. PhotoSuggestion — ZADRŽAVA SE

`PhotoSuggestion` ostaje kakav jeste. Radi, testiran je, na produkciji je. Nema razloga da se mijenja.

#### C. Reviews upravljanje

`Review` model već postoji (polimorfni: Location, Experience, Plan). Curator dashboard treba:

```ruby
# Rute — reviews su read + moderate (ne create)
# Kurator: pregled reviews, flagging
# Admin: pregled + odobravanje/brisanje/odgovaranje

# app/controllers/curator/reviews_controller.rb
# Već postoji sa: index, show, destroy
# Proširiti sa:
#   - Filtriranje po statusu, resursu, ratingu
#   - Bulk akcije za admin (approve/reject multiple)
#   - Flag system za kuratore

# app/models/review.rb — dodati:
#   - enum :moderation_status (unreviewed, approved, flagged, removed)
#   - scope :needs_moderation
#   - scope :flagged
```

**Nova tabela: review_flags**
```ruby
create_table :review_flags do |t|
  t.references :review, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true  # Kurator koji flaga
  t.string :reason, null: false     # spam, inappropriate, inaccurate, other
  t.text :notes
  t.timestamps

  t.index [:review_id, :user_id], unique: true  # Jedan flag per kurator
end
```

#### D. Audio Tour generisanje

Integracija postojećeg `Ai::AudioTourGenerator` servisa u curator dashboard:

```ruby
# Admin-only akcija na location show stranici
# app/controllers/curator/locations_controller.rb
def generate_audio_tour
  require_admin  # Samo admin može pokrenuti
  @location = Location.find(params[:id])

  Ai::AudioTourGenerateJob.perform_later(
    location_id: @location.id,
    locale: params[:locale] || "bs",
    requested_by: current_user.id
  )

  redirect_to curator_location_path(@location),
    notice: "Audio tura se generise u pozadini..."
end
```

UI na location show stranici:
- Status postojeće audio ture (ima/nema, za koje jezike)
- Dugme "Generiši audio turu" (samo za admin)
- Player za postojeću audio turu
- Dropdown za izbor jezika

### Routes

```ruby
namespace :curator do
  resources :locations do
    resources :photo_suggestions, only: [:new, :create]
    resources :location_suggestions, only: [:new, :create]
    member do
      post :generate_audio_tour  # Admin only
    end
    collection do
      get :needs_photos
    end
  end

  resources :experiences do
    resources :experience_suggestions, only: [:new, :create]
  end

  resources :plans do
    resources :plan_suggestions, only: [:new, :create]
  end

  resources :reviews, only: [:index, :show] do
    member do
      post :flag         # Kurator flaga review
    end
  end

  # Admin sekcija
  namespace :admin do
    resources :photo_suggestions, only: [:index, :show] do
      member { post :approve; post :reject }
    end
    resources :location_suggestions, only: [:index, :show] do
      member { post :approve; post :reject }
    end
    resources :experience_suggestions, only: [:index, :show] do
      member { post :approve; post :reject }
    end
    resources :plan_suggestions, only: [:index, :show] do
      member { post :approve; post :reject }
    end
    resources :reviews, only: [:index, :show] do
      member { post :approve; post :remove }
      collection { post :bulk_action }
    end
    # Postojeći
    resources :users, only: [:index, :show, :edit, :update]
    resources :curator_applications, only: [:index, :show]
  end
end
```

### UI Changes

#### Location Show (Kurator)
- Pregled svih podataka (read-only)
- Dugme "Predloži promjenu" → otvara LocationSuggestion formu
- Dugme "Predloži slike" → otvara PhotoSuggestion formu (postoji)
- Sekcija "Reviews" sa listom i flag opcijom
- Audio player ako tura postoji

#### Location Show (Admin)
- Sve isto kao kurator PLUS:
- Dugme "Uredi" → direktan CRUD (standardna Rails forma)
- Dugme "Obriši"
- Dugme "Generiši audio turu" sa jezičkim opcijama
- Badge sa brojem pending suggestion-a
- Link na admin panel za odobravanje

#### Admin Suggestion Panel
- Unified inbox svih suggestion-a (sa filterima po tipu resursa)
- Diff prikaz: lijevo original, desno predloženo (side-by-side)
- Approve/Reject sa notes poljem
- Fotografije prikazane inline

#### Reviews Management
- Lista reviews sa filterima (rating, resurs, status)
- Flagged reviews istaknuti
- Admin: bulk approve/remove
- Kurator: flag dugme

## Drawbacks

1. **Više modela/tabela** — Umjesto jednog ContentChange, imamo 3 nova suggestion modela + review_flags. Više migracija, više kontrolera.
2. **Dupliciranje logike** — `Suggestable` concern pokriva zajednički dio, ali svaki model ima svoju `apply_changes!` metodu. To je trade-off za ispravnost.
3. **Migracija podataka** — Ako postoje pending ContentChange zapisi na produkciji, trebaju se migrirati ili odbaciti.
4. **PhotoSuggestion ostaje odvojen** — Konzistentnije bi bilo imati `LocationPhotoSuggestion`, ali PhotoSuggestion radi i nema razloga ga dirati.

## Alternatives

### A. Popraviti ContentChange

Umjesto novih modela, popraviti postojeći:
- Dodati type casting pri approve
- Dodati Active Storage polje
- Popraviti merge logic

**Odbačeno jer:** Fundamentalni problem je JSONB pristup za typed podatke. Svaki novi resurs ili polje zahtijeva ručno rukovanje serialization/deserialization. Krhko i error-prone.

### B. Inline field-level suggestions

Kurator klikne na jedno polje i predloži promjenu samo tog polja.

**Odbačeno kao standalone jer:** Previše granularno za create. Može se dodati kao poboljšanje u budućnosti (fase 3+), ali per-resource forme su potrebne za create workflow.

### C. Git-style branching

Svaki kurator radi na "branchu" resursa, admin "merge-a".

**Odbačeno jer:** Overkill za turističku platformu sa malim brojem kuratora. Kompleksna implementacija bez proporcionalnog benefita.

## Unresolved Questions

1. **Migracija ContentChange podataka** — Ima li pending prijedloga koji trebaju biti migrirani? Ili su svi stale i mogu se odbaciti?
2. **CuratorReview model** — Da li zadržati peer-review sistem ili je dovoljan samo admin approve/reject?
3. **Notifikacije** — Da li kuratori trebaju email/in-app notifikaciju kad admin odobri/odbije suggestion?
4. **Audio tour cost control** — Generisanje audio tura košta (ElevenLabs API). Treba li limit po lokaciji/danu?
5. **Review moderation default** — Da li novi reviews trebaju biti `approved` po defaultu ili `unreviewed`?

## Implementation Plan

### Faza 1: Admin Direct CRUD (prioritet: VISOK)
Omogućiti `curator_edit_delete` flag za admin korisnike putem Flipper actors. Admini odmah mogu direktno upravljati sadržajem kroz postojeće forme.

**Deliverables:**
- [ ] Flipper: enable `curator_edit_delete` per-actor za admine
- [ ] Razdvojiti controller logiku: admin = direktan CRUD, curator = suggestion
- [ ] Testovi za oba režima

### Faza 2: Per-Resource Suggestion modeli (prioritet: VISOK)
Zamijeniti ContentChange sa LocationSuggestion, ExperienceSuggestion, PlanSuggestion.

**Deliverables:**
- [ ] `Suggestable` concern
- [ ] `LocationSuggestion` model + migracija + kontroler + forme + testovi
- [ ] `ExperienceSuggestion` model + migracija + kontroler + forme + testovi
- [ ] `PlanSuggestion` model + migracija + kontroler + forme + testovi
- [ ] Admin approval panel za svaki tip
- [ ] Migracija ili cleanup starih ContentChange zapisa
- [ ] Uklanjanje ContentChange, CuratorReview, ContentChangeContribution modela

### Faza 3: Reviews Management (prioritet: SREDNJI)
Dodati moderation workflow za korisničke recenzije.

**Deliverables:**
- [ ] `moderation_status` kolona na reviews tabeli
- [ ] `ReviewFlag` model + migracija
- [ ] Curator reviews controller (index, show, flag)
- [ ] Admin reviews controller (approve, remove, bulk_action)
- [ ] UI za pregled i filtriranje reviews
- [ ] Testovi

### Faza 4: Audio Tour Integration (prioritet: SREDNJI)
Integrisati audio tour generisanje u curator dashboard.

**Deliverables:**
- [ ] `generate_audio_tour` akcija na locations controlleru
- [ ] Background job za generisanje
- [ ] UI: status, player, generate dugme na location show
- [ ] Testovi

### Faza 5: Cleanup (prioritet: NIZAK)
- [ ] Ukloniti `ContentChange` model, migracije, kontrolere, views
- [ ] Ukloniti `CuratorReview` model
- [ ] Ukloniti `ContentChangeContribution` model
- [ ] Ukloniti `Proposals` kontroler i views
- [ ] Ukloniti `curator_edit_delete` feature flag (više nije potreban)
- [ ] Ažurirati CuratorActivity action types
