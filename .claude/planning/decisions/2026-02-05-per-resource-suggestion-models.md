# ADR-0003: Replace ContentChange with Per-Resource Suggestion Models

## Status
Proposed

## Datum
2026-02-05

## Autori
Tech Lead, Product Manager

## Context

Curator dashboard koristi polimorfni `ContentChange` model za sve content prijedloge (Location, Experience, Plan, AudioTour). Ovaj model:

1. **Ne radi na produkciji** — Feature flag `curator_edit_delete` je disabled. Jedini funkcionalni suggestion sistem je `PhotoSuggestion` koji je per-resource model.

2. **JSONB proposed_data gubi type safety** — Form parametri dolaze kao stringovi (`"1"`, `"true"`). Kad se sprema u JSONB, tipovi se gube. Pri `approve!()`, `location.update!(proposed_data)` šalje `location_category_ids: ["1", "2"]` umjesto `[1, 2]`. Rails asocijacije ne rade ispravno.

3. **File attachments su isključeni** — Komentar u kodu: `# Note: File attachments (photos, audio) are not included in proposals`. Kurator popuni formu SA slikama, ali proposal ih tiho odbaci. Kad admin odobri, resurs nema slika.

4. **Merge contributions je destruktivan** — `merge_contributions!` radi shallow `Hash#merge!` po redu kreacije. Kad kurator B edituje isti ključ kao kurator A, podatci kuratora A nestanu bez upozorenja.

5. **safe_attributes_for je krhka** — Svaki model ima hardcoded whitelist u ContentChange modelu. Kad se doda novo polje na Location, mora se ručno dodati i u ContentChange. Lako se zaboravi.

6. **Dual identity problem** — Model ima i `changeable_type` (polimorfna asocijacija) i `changeable_class` (string kolona za create kad changeable_id je nil). Kontroleri moraju koristiti `.or()` query na oba.

7. **PhotoSuggestion dokazuje da per-resource radi** — Jednostavan model, typed kolone, Active Storage za slike, `approve!`/`reject!` metode. Na produkciji je i funkcioniše.

### Zahvaćeni fajlovi

| Fajl | Linije | Opis |
|------|--------|------|
| `app/models/content_change.rb` | 295 | Polimorfni model |
| `app/models/curator_review.rb` | 27 | Peer review na ContentChange |
| `app/models/content_change_contribution.rb` | ~30 | Multi-curator contributions |
| `app/controllers/curator/proposals_controller.rb` | ~60 | Curator proposal pregled |
| `app/controllers/curator/admin/content_changes_controller.rb` | ~80 | Admin approve/reject |
| `app/views/curator/proposals/` | ~200 | Proposal views |
| `test/models/content_change_test.rb` | 480 | Testovi koji prolaze ali testiraju broken flow |
| `test/controllers/curator/*/` | 240+ | Controller testovi |

## Decision

**Zamijeniti `ContentChange` sa per-resource suggestion modelima:**

- `LocationSuggestion` — za predlaganje promjena na lokacijama
- `ExperienceSuggestion` — za predlaganje promjena na iskustvima
- `PlanSuggestion` — za predlaganje promjena na planove

**Zadržati `PhotoSuggestion`** bez promjena — radi, testirano je.

### Ključni principi dizajna

#### 1. Typed kolone umjesto JSONB

```ruby
# LOŠE (ContentChange)
t.jsonb :proposed_data  # {"name": "Stari Most", "category_ids": ["1","2"]}

# DOBRO (LocationSuggestion)
t.string :proposed_name
t.string :proposed_city
t.text :proposed_description
t.json :proposed_category_ids    # Typed kao Array<Integer>
```

**Zašto:** Rails zna tip svake kolone. Nema type mismatch pri approve. Validacije rade normalno. Migracije dokumentuju schema.

#### 2. Active Storage za fajlove

```ruby
class LocationSuggestion < ApplicationRecord
  has_many_attached :proposed_photos
end

class ExperienceSuggestion < ApplicationRecord
  has_one_attached :proposed_cover_photo
end
```

**Zašto:** Fajlovi se čuvaju uz suggestion, ne gube se. Kad admin odobri, attachmenti se kopiraju na resurs.

#### 3. Suggestable concern za zajedničku logiku

```ruby
module Suggestable
  extend ActiveSupport::Concern

  included do
    belongs_to :user
    belongs_to :reviewed_by, class_name: "User", optional: true

    enum :status, { pending: 0, approved: 1, rejected: 2 }
    enum :change_type, { create_resource: 0, update_resource: 1, delete_resource: 2 }

    scope :pending_review, -> { where(status: :pending) }
  end

  def approve!(admin, notes: nil)
    transaction do
      apply_changes!
      update!(status: :approved, reviewed_by: admin,
              reviewed_at: Time.current, admin_notes: notes)
    end
  end

  def reject!(admin, notes: nil)
    update!(status: :rejected, reviewed_by: admin,
            reviewed_at: Time.current, admin_notes: notes)
  end

  # Svaki model implementira svoju verziju
  def apply_changes!
    raise NotImplementedError
  end
end
```

#### 4. Admin = direktan CRUD, Kurator = suggestion

```ruby
# app/controllers/curator/locations_controller.rb
def update
  if current_user.admin?
    # Direktno ažuriranje
    LocationUpdater.new(@location, location_params).call
    redirect_to curator_location_path(@location)
  else
    # Kreiraj suggestion
    suggestion = @location.location_suggestions.build(
      user: current_user,
      change_type: :update_resource,
      **suggestion_params
    )
    suggestion.save!
    redirect_to curator_location_path(@location)
  end
end
```

#### 5. Nema multi-contributor na jednom suggestion-u

Svaki kurator kreira svoj suggestion. Admin vidi sve pending suggestion-e za resurs i odlučuje koji prihvata. Eliminise merge problem potpuno.

### Migracije

```ruby
# Primjer: create_location_suggestions
class CreateLocationSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :location_suggestions do |t|
      t.references :location, foreign_key: true  # nil za create
      t.references :user, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.integer :status, default: 0, null: false
      t.integer :change_type, default: 0, null: false
      t.datetime :reviewed_at
      t.text :admin_notes

      # Typed polja
      t.string :proposed_name
      t.string :proposed_city
      t.text :proposed_description
      t.text :proposed_historical_context
      t.decimal :proposed_lat, precision: 10, scale: 7
      t.decimal :proposed_lng, precision: 10, scale: 7
      t.integer :proposed_budget
      t.string :proposed_phone
      t.string :proposed_email
      t.string :proposed_website
      t.string :proposed_video_url
      t.jsonb :proposed_social_links, default: {}
      t.jsonb :proposed_tags, default: []
      t.jsonb :proposed_category_ids, default: []
      t.jsonb :proposed_experience_type_ids, default: []

      t.timestamps
    end

    add_index :location_suggestions, [:location_id, :status],
              where: "status = 0",
              name: "idx_pending_location_suggestion"
  end
end
```

### Cleanup plan

Kad novi suggestion modeli budu na produkciji i funkcionišu:

1. Migracija: obrisati `content_changes`, `content_change_contributions` tabele
2. Ukloniti modele: `ContentChange`, `ContentChangeContribution`, `CuratorReview`
3. Ukloniti kontrolere: `Curator::ProposalsController`, `Curator::Admin::ContentChangesController`
4. Ukloniti views: `curator/proposals/`
5. Ukloniti feature flag: `curator_edit_delete`
6. Ažurirati `CuratorActivity` action types

## Consequences

### Positive

- **Radi na produkciji** — Typed kolone eliminišu type mismatch. Active Storage drži fajlove uz suggestion.
- **Testabilnost** — Svaki model se testira nezavisno sa pravim tipovima, ne JSONB mockovima.
- **Jasna odgovornost** — `LocationSuggestion` zna sve o lokacijama. Ne treba `safe_attributes_for` whitelist.
- **File support** — Fotografije i cover photo su dio suggestion-a, ne gube se.
- **Jednostavniji merge** — Nema merge-a. Svaki kurator = svoj suggestion. Admin bira.
- **Lakše dodavanje polja** — Novo polje = nova kolona na odgovarajućem suggestion modelu. Migracija dokumentuje promjenu.
- **Admin efikasnost** — Direktan CRUD bez proposal overhead-a.

### Negative

- **Više tabela** — 3 nove tabele umjesto jedne. Više migracija.
- **Dupliciran boilerplate** — Svaki suggestion model ima svoju `apply_changes!` metodu. Concern pokriva samo zajedničko.
- **PhotoSuggestion ostaje odvojen** — Moglo bi se preimenovati u `LocationPhotoSuggestion` za konzistentnost, ali breaking change bez benefita.
- **Migracija podataka** — Existing ContentChange zapisi trebaju cleanup (vjerovatno nema pending na prod jer feature je disabled).

### Neutral

- **Broj modela raste** — Od 3 (ContentChange + 2 pomoćna) na 3 (LocationSuggestion + ExperienceSuggestion + PlanSuggestion) + concern. Neto isti broj fajlova.
- **Testovi se moraju prepisati** — 480+ linija ContentChange testova se zamjenjuju sa testovima per model. Neto sličan obim.

## Alternatives Considered

### Opcija 1: Popraviti ContentChange

Dodati type casting u `approve!()`, Active Storage polje, fix merge logic.

- **Prednosti:** Manje promjena. Jedan model.
- **Mane:** JSONB serialization ostaje fragilan. Svaki novi resurs/polje zahtijeva ručno rukovanje. Root cause se ne rješava.
- **Zašto odbačeno:** Fundamentalni problem je arhitekturni — jedan generički model ne može ispravno pokriti specifičnosti različitih resursa. Popravke bi bile zakrpe.

### Opcija 2: Field-level suggestions

Kurator predlaže promjenu jednog polja (ne cijelog resursa).

- **Prednosti:** Minimalna forma. Lako za review.
- **Mane:** Ne pokriva create workflow. Admin mora odobriti svako polje pojedinačno.
- **Zašto odbačeno:** Može se dodati kao poboljšanje (faza 3+), ali per-resource suggestion je potreban za create i bulk update.

### Opcija 3: Draft system

Kurator kreira "draft" resurs koji admin "publish-a".

- **Prednosti:** Intuitivan za kuratore — vide šta kreiraju.
- **Mane:** Dupli zapisi u bazi (draft + published). Kompleksni query-ji da se izbjegnu draft-ovi na public stranicama. STI ili status kolona na svakom modelu.
- **Zašto odbačeno:** Zahtijeva promjene na svim resursnim modelima. Suggestion model je izolovana promjena.

## References

- RFC-0001: Curator Dashboard v2 (`.claude/planning/rfcs/0001-curator-dashboard-v2.md`)
- Existing `PhotoSuggestion` model (`app/models/photo_suggestion.rb`) — referentna implementacija
- `ContentChange` model (`app/models/content_change.rb`) — model koji se zamjenjuje
