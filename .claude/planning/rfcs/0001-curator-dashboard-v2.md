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
│   (user_type │  + LocationSuggestion (tekst + slike)    │
│    = curator)│  + ExperienceSuggestion (novo)           │
│              │  + PlanSuggestion (novo)                 │
│              │  + Pregled reviews + flagging             │
└──────────────┴──────────────────────────────────────────┘
```

**Ključne razlike od prethodnog sistema:**
- **Jedan pending suggestion per resurs** — unique constraint, više kuratora doprinosi istom
- **PhotoSuggestion se ukida** — slike idu u LocationSuggestion
- **Multi-contributor** — svaki kurator doprinosi istom suggestion-u, typed kolone za audit trail

### Princip dizajna: Dva režima rada

**Admin režim:** Direktan CRUD. Forme rade kao standardne Rails forme — `Location.create!`, `Location.update!`, `Location.destroy!`. Nema proposal workflow-a. Admin je autoritet.

**Curator režim:** Suggestion-based. Kurator vidi resurs, klikne "Predloži promjenu", popuni formu specifičnu za taj resurs. Suggestion se kreira sa statusom `pending`. Admin odobri ili odbije.

### Data Model

#### A. Per-Resource Suggestion modeli

**Ključni principi:**
- **Jedan pending suggestion per resurs** (unique constraint u bazi)
- **Multi-contributor** — više kuratora doprinosi istom suggestion-u
- **Typed kolone** umjesto JSONB — i na suggestion i na contribution modelima
- **Active Storage za fajlove** — slike idu uz suggestion (zamjenjuje PhotoSuggestion)

Detaljan dizajn: vidi **ADR-0003** (`.claude/planning/decisions/2026-02-05-per-resource-suggestion-models.md`)

```ruby
# Suggestable concern — zajednicka logika
module Suggestable
  included do
    belongs_to :user
    belongs_to :reviewed_by, class_name: "User", optional: true
    has_many :contributions  # Per-resource contribution model
    enum :status, { pending: 0, approved: 1, rejected: 2 }
    enum :change_type, { create_resource: 0, update_resource: 1, delete_resource: 2 }
  end

  def approve!(admin, notes: nil) ... end
  def reject!(admin, notes: nil) ... end
  def add_contribution(user:, **proposed_fields) ... end
end
```

```ruby
# LocationSuggestion — zamjenjuje i ContentChange i PhotoSuggestion za lokacije
class LocationSuggestion < ApplicationRecord
  include Suggestable
  belongs_to :location, optional: true
  has_many :contributions, class_name: "LocationSuggestionContribution"
  has_many_attached :proposed_photos  # Zamjenjuje PhotoSuggestion
  # Typed kolone: proposed_name, proposed_city, proposed_description, ...
end

# LocationSuggestionContribution — audit trail, iste typed kolone
class LocationSuggestionContribution < ApplicationRecord
  belongs_to :location_suggestion
  belongs_to :user
  # Iste typed kolone — samo popunjena = polja koja ovaj kurator mijenja
end
```

```ruby
# ExperienceSuggestion
class ExperienceSuggestion < ApplicationRecord
  include Suggestable
  belongs_to :experience, optional: true
  has_many :contributions, class_name: "ExperienceSuggestionContribution"
  has_one_attached :proposed_cover_photo
  # Typed kolone: proposed_title, proposed_description, proposed_seasons,
  #   proposed_video_urls (jsonb), proposed_contact_*, ...
end

# PlanSuggestion
class PlanSuggestion < ApplicationRecord
  include Suggestable
  belongs_to :plan, optional: true
  has_many :contributions, class_name: "PlanSuggestionContribution"
  has_one_attached :proposed_cover_photo  # ADR-0006: direktan cover photo
  # Typed kolone: proposed_title, proposed_city_name, proposed_experience_days, ...
end
```

#### B. PhotoSuggestion — UKIDA SE

`PhotoSuggestion` se apsorbira u `LocationSuggestion`. Funkcionalnost slika postaje dio unified suggestion workflow-a. Pending photo suggestion-e se migriraju u LocationSuggestion zapise.

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
    # Suggestion-i (kurator predlaže promjenu ili dodaje contribution)
    resources :location_suggestions, only: [:new, :create, :edit, :update]
    member do
      post :generate_audio_tour  # Admin only
    end
    collection do
      get :needs_photos
    end
  end

  resources :experiences do
    resources :experience_suggestions, only: [:new, :create, :edit, :update]
  end

  resources :plans do
    resources :plan_suggestions, only: [:new, :create, :edit, :update]
  end

  resources :reviews, only: [:index, :show] do
    member do
      post :flag         # Kurator flaga review
    end
  end

  # Admin sekcija
  namespace :admin do
    # Unified suggestion pregled — svi tipovi na jednom mjestu
    resources :suggestions, only: [:index] # Dashboard sa svim pending
    resources :location_suggestions, only: [:show] do
      member { post :approve; post :reject }
    end
    resources :experience_suggestions, only: [:show] do
      member { post :approve; post :reject }
    end
    resources :plan_suggestions, only: [:show] do
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
- Dugme "Predloži promjenu" → otvara LocationSuggestion formu (tekst + slike zajedno)
- Ako postoji pending suggestion, dugme "Doprinesi" → otvara isti formular sa current suggestion podacima
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

1. **Više modela/tabela** — 3 suggestion modela + 3 contribution modela + review_flags = 7 novih tabela. Više migracija, više kontrolera.
2. **Duplicirane kolone** — Suggestion i Contribution imaju iste typed kolone. Kad se doda polje na resurs, treba dodati na oba.
3. **Migracija podataka** — Pending ContentChange + pending PhotoSuggestion zapise treba migrirati ili odbaciti.
4. **Kompleksniji merge** — Typed kolone rješavaju type safety, ali logika "ažuriraj suggestion + sačuvaj contribution" je više koda.

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

1. **Migracija podataka** — Koliko ima pending ContentChange i PhotoSuggestion zapisa na produkciji? Migrirati ih ili odbaciti?
2. **Contribution conflict resolution** — Kad kurator B prepiše polje kuratora A, da li kurator A dobije notifikaciju? Ili je "last write wins" dovoljno uz audit trail?
3. **Notifikacije** — Da li kuratori trebaju email/in-app notifikaciju kad admin odobri/odbije suggestion ili kad neko doprinese?
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
Zamijeniti ContentChange + PhotoSuggestion sa LocationSuggestion, ExperienceSuggestion, PlanSuggestion.

**Deliverables:**
- [ ] `Suggestable` concern
- [ ] `LocationSuggestion` model + `LocationSuggestionContribution` + migracija + kontroler + forme + testovi
- [ ] `ExperienceSuggestion` model + `ExperienceSuggestionContribution` + migracija + kontroler + forme + testovi
- [ ] `PlanSuggestion` model + `PlanSuggestionContribution` + migracija + kontroler + forme + testovi
- [ ] Admin unified suggestion inbox + per-type approval panel
- [ ] Migracija pending PhotoSuggestion → LocationSuggestion
- [ ] Migracija ili cleanup starih ContentChange zapisa

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
- [ ] Ukloniti `PhotoSuggestion` model + kontroleri + views
- [ ] Ukloniti `Proposals` kontroler i views
- [ ] Ukloniti `curator_edit_delete` feature flag (više nije potreban)
- [ ] Ažurirati CuratorActivity action types
- [ ] Drop tabele: `content_changes`, `content_change_contributions`, `photo_suggestions`
