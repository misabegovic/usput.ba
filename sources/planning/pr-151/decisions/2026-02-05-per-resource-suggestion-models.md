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

- `LocationSuggestion` — za predlaganje promjena na lokacijama (uključujući slike — zamjenjuje i `PhotoSuggestion`)
- `ExperienceSuggestion` — za predlaganje promjena na iskustvima
- `PlanSuggestion` — za predlaganje promjena na planove

**Ukinuti `PhotoSuggestion`** — funkcionalnost slika se apsorbira u `LocationSuggestion` koji podržava Active Storage. Nema razloga za odvojen model kad LocationSuggestion može držati i tekst i slike.

### Ključni principi dizajna

#### 1. Jedan pending suggestion per resurs + multi-contributor

```ruby
# Unique constraint: samo JEDAN pending suggestion po resursu
add_index :location_suggestions, :location_id,
          unique: true,
          where: "status = 0 AND location_id IS NOT NULL",
          name: "idx_one_pending_per_location"

# Više kuratora doprinosi ISTOM suggestion-u
class LocationSuggestionContribution < ApplicationRecord
  belongs_to :location_suggestion
  belongs_to :user

  # Iste typed kolone kao LocationSuggestion
  # Samo popunjena polja = polja koja ovaj kurator mijenja
  t.string :proposed_name          # nil ako ne mijenja name
  t.text :proposed_description     # nil ako ne mijenja opis
  t.text :notes                    # Komentar kuratora

  validates :user_id, uniqueness: {
    scope: :location_suggestion_id,
    message: "already contributed"
  }
end
```

**Kako radi merge:** Suggestion drži "finalno stanje" prijedloga. Kad kurator B doprinese, njegovi non-nil values se upisuju u suggestion polja, a stari values (od kuratora A) se čuvaju u contribution-u kuratora A. Admin vidi finalno stanje + historiju ko je šta mijenjao.

```ruby
# Primjer toka:
# 1. Kurator A predlaže: name="Stari Most", description="..."
suggestion = LocationSuggestion.find_or_create_pending!(location, user: kurator_a)
# → suggestion.proposed_name = "Stari Most"
# → suggestion.proposed_description = "..."

# 2. Kurator B doprinosi: description="bolja verzija", city="Mostar"
suggestion.add_contribution(user: kurator_b,
  proposed_description: "bolja verzija",
  proposed_city: "Mostar")
# → Kreira contribution za kuratora A sa starim description
# → Ažurira suggestion: description="bolja verzija", city="Mostar"
# → Kreira contribution za kuratora B sa novim vrijednostima

# 3. Admin vidi finalno stanje + diff + ko je šta mijenjao
```

**Zašto ne odvojeni suggestion-i po kuratoru:** Korisnik je rekao da želi jedan suggestion per resurs sa višestrukim kontributorima. Ovo sprečava konflikte (dva kuratora rade na istom resursu nezavisno, admin mora da bira). Umjesto toga, kuratori kolaboriraju na jednom prijedlogu.

#### 2. Typed kolone umjesto JSONB

```ruby
# LOŠE (ContentChange)
t.jsonb :proposed_data  # {"name": "Stari Most", "category_ids": ["1","2"]}

# DOBRO (LocationSuggestion)
t.string :proposed_name
t.string :proposed_city
t.text :proposed_description
t.json :proposed_category_ids    # Typed kao Array<Integer>
```

**Zašto:** Rails zna tip svake kolone. Nema type mismatch pri approve. Validacije rade normalno.

**Ključna razlika od ContentChange:** Contribution model ima **iste typed kolone** kao suggestion model. Nema JSONB. Merge je per-kolona i type-safe.

#### 3. Active Storage za fajlove (zamjenjuje PhotoSuggestion)

```ruby
class LocationSuggestion < ApplicationRecord
  has_many_attached :proposed_photos

  validate :acceptable_photos

  def acceptable_photos
    return unless proposed_photos.attached?
    proposed_photos.each do |photo|
      errors.add(:proposed_photos, "max 10MB") if photo.blob.byte_size > 10.megabytes
      unless %w[image/jpeg image/png image/gif image/webp].include?(photo.blob.content_type)
        errors.add(:proposed_photos, "must be JPEG, PNG, GIF, or WebP")
      end
    end
    errors.add(:proposed_photos, "max 10") if proposed_photos.size > 10
  end
end

class ExperienceSuggestion < ApplicationRecord
  has_one_attached :proposed_cover_photo
end
```

**Zašto apsorbirati PhotoSuggestion:** Kurator predlaže promjene na lokaciji — ime, opis, koordinate, I slike. Razdvajanje teksta i slika u odvojene modele znači dva proposal workflow-a za isti resurs. Sa LocationSuggestion, jedan prijedlog pokriva sve.

**Migracija sa PhotoSuggestion:** Pending photo suggestion-e migrirati u LocationSuggestion zapise (samo sa proposed_photos). Odobrene/odbijene ostaviti kao historiju.

#### 4. Suggestable concern za zajedničku logiku

```ruby
# app/models/concerns/suggestable.rb
module Suggestable
  extend ActiveSupport::Concern

  included do
    belongs_to :user                      # Kurator/admin ili system_user za AI
    belongs_to :reviewed_by, class_name: "User", optional: true

    enum :status, { pending: 0, approved: 1, rejected: 2 }
    enum :change_type, { create_resource: 0, update_resource: 1, delete_resource: 2 }
    enum :origin, { human: 0, ai_generated: 1 }, prefix: :origin  # ADR-0007

    validates :user, presence: true

    scope :pending_review, -> { where(status: :pending) }
    scope :recent, -> { order(created_at: :desc) }
    scope :human_suggestions, -> { where(origin: :human) }
    scope :ai_suggestions, -> { where(origin: :ai_generated) }
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

  # Dodaj contribution od drugog kuratora
  def add_contribution(user:, notes: nil, **proposed_fields)
    non_nil_fields = proposed_fields.compact

    transaction do
      # Sačuvaj contribution za audit trail
      contribution = contributions.create!(
        user: user,
        notes: notes,
        **non_nil_fields
      )

      # Ažuriraj suggestion sa novim vrijednostima
      non_nil_fields.each do |field, value|
        self[field] = value if respond_to?("#{field}=")
      end
      save!
    end
  end

  # Svaki model implementira
  def apply_changes!
    raise NotImplementedError
  end

  # Polja koja su popunjena (non-nil proposed_* kolone)
  def proposed_changes
    attributes.select { |k, v| k.start_with?("proposed_") && v.present? }
  end
end
```

#### 5. Admin = direktan CRUD, Kurator = suggestion

```ruby
# app/controllers/curator/locations_controller.rb
def update
  if current_user.admin?
    # Direktno ažuriranje
    LocationUpdater.new(@location, location_params).call
    redirect_to curator_location_path(@location)
  else
    # Find or create pending suggestion za ovaj resurs
    suggestion = LocationSuggestion.find_or_create_pending!(
      @location, user: current_user
    )
    suggestion.add_contribution(
      user: current_user,
      **suggestion_params
    )
    redirect_to curator_location_path(@location),
      notice: "Promjene predložene za pregled."
  end
end
```

### Migracije

```ruby
# Primjer: create_location_suggestions
class CreateLocationSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :location_suggestions do |t|
      t.references :location, foreign_key: true  # nil za create_resource
      t.references :user, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.integer :status, default: 0, null: false
      t.integer :change_type, default: 0, null: false
      t.integer :origin, default: 0, null: false   # 0=human, 1=ai_generated (ADR-0007)
      t.string :ai_service                          # Koji AI servis (ADR-0007)
      t.datetime :reviewed_at
      t.text :admin_notes

      # Typed polja — ista kao Location atributi
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
      t.jsonb :proposed_video_urls, default: []    # Array URL-ova (ADR-0006)
      t.jsonb :proposed_social_links, default: {}
      t.jsonb :proposed_tags, default: []
      t.jsonb :proposed_category_ids, default: []
      t.jsonb :proposed_experience_type_ids, default: []
      # Slike idu kroz Active Storage (has_many_attached :proposed_photos)

      t.timestamps
    end

    # Jedan pending suggestion per lokacija
    add_index :location_suggestions, :location_id,
              unique: true,
              where: "status = 0 AND location_id IS NOT NULL",
              name: "idx_one_pending_per_location"
  end
end

# Contribution tabela — ISTE typed kolone za audit trail
class CreateLocationSuggestionContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :location_suggestion_contributions do |t|
      t.references :location_suggestion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :notes

      # Typed polja — kopija suggestion kolona
      # Samo non-nil polja = polja koja ovaj kurator mijenja
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
      t.jsonb :proposed_video_urls                  # Array URL-ova (ADR-0006)
      t.jsonb :proposed_social_links
      t.jsonb :proposed_tags
      t.jsonb :proposed_category_ids
      t.jsonb :proposed_experience_type_ids

      t.timestamps
    end

    # Jedan contribution per kurator per suggestion
    add_index :location_suggestion_contributions,
              [:location_suggestion_id, :user_id],
              unique: true,
              name: "idx_loc_suggestion_contrib_unique_user"
  end
end
```

**ExperienceSuggestion** — typed kolone:
- `proposed_title`, `proposed_description`, `proposed_category_id`, `proposed_duration`
- `proposed_seasons` (jsonb), `proposed_location_uuids` (jsonb)
- `proposed_contact_name`, `proposed_contact_email`, `proposed_contact_phone`, `proposed_contact_website`
- `proposed_video_urls` (jsonb, ADR-0006)
- `has_one_attached :proposed_cover_photo`

**PlanSuggestion** — typed kolone:
- `proposed_title`, `proposed_city_name`, `proposed_notes`, `proposed_visibility`
- `proposed_start_date`, `proposed_end_date`
- `proposed_preferences` (jsonb), `proposed_experience_days` (jsonb)
- `has_one_attached :proposed_cover_photo` (ADR-0006)

Svaki sa odgovarajućom contribution tabelom (iste typed kolone).

### Cleanup plan

Kad novi suggestion modeli budu na produkciji i funkcionišu:

1. Migrirati pending PhotoSuggestion zapise u LocationSuggestion
2. Obrisati tabele: `content_changes`, `content_change_contributions`, `photo_suggestions`
3. Ukloniti modele: `ContentChange`, `ContentChangeContribution`, `CuratorReview`, `PhotoSuggestion`
4. Ukloniti kontrolere: `Curator::ProposalsController`, `Curator::Admin::ContentChangesController`, `Curator::PhotoSuggestionsController`, `Curator::Admin::PhotoSuggestionsController`
5. Ukloniti views: `curator/proposals/`, `curator/photo_suggestions/`, `curator/admin/photo_suggestions/`
6. Ukloniti feature flag: `curator_edit_delete`
7. Ažurirati `CuratorActivity` action types

## Consequences

### Positive

- **Radi na produkciji** — Typed kolone eliminišu type mismatch. Active Storage drži fajlove uz suggestion.
- **Testabilnost** — Svaki model se testira nezavisno sa pravim tipovima, ne JSONB mockovima.
- **Jasna odgovornost** — `LocationSuggestion` zna sve o lokacijama. Ne treba `safe_attributes_for` whitelist.
- **Unified prijedlozi** — Tekst + slike u jednom suggestion-u. Nema odvojenog PhotoSuggestion. Jedan workflow za sve.
- **Type-safe merge** — Contribution model ima iste typed kolone. Merge je per-kolona, ne JSONB. Admin vidi ko je šta mijenjao.
- **Kolaboracija** — Više kuratora radi na istom prijedlogu. Unique constraint sprečava konflikte.
- **Lakše dodavanje polja** — Novo polje = nova kolona na suggestion + contribution modelu. Migracija dokumentuje promjenu.
- **Admin efikasnost** — Direktan CRUD bez proposal overhead-a.

### Negative

- **Više tabela** — 3 suggestion tabele + 3 contribution tabele = 6 novih tabela. Značajno više od jednog ContentChange.
- **Duplicirane kolone** — Suggestion i Contribution imaju iste kolone. Kad se doda polje, treba dodati na oba mjesta.
- **Kompleksniji merge** — Iako je type-safe, logika "ažuriraj suggestion polja + sačuvaj contribution" je više koda nego jednostavan `Hash#merge!`.
- **Migracija PhotoSuggestion** — Pending photo suggestion-e treba migrirati. Approved/rejected su historija.
- **Migracija ContentChange** — Existing zapisi trebaju cleanup.

### Neutral

- **Neto broj modela** — Od 4 (ContentChange + Contribution + CuratorReview + PhotoSuggestion) na 6 (3 suggestion + 3 contribution) + concern. Više fajlova ali svaki je jednostavniji.
- **Testovi se moraju prepisati** — Ali testovi per model su fokusiraniji i lakši za održavanje.

## Alternatives Considered

### Opcija 1: Popraviti ContentChange

Dodati type casting u `approve!()`, Active Storage polje, fix merge logic.

- **Prednosti:** Manje promjena. Jedan model.
- **Mane:** JSONB serialization ostaje fragilan. Svaki novi resurs/polje zahtijeva ručno rukovanje. Root cause se ne rješava.
- **Zašto odbačeno:** Fundamentalni problem je arhitekturni — jedan generički model ne može ispravno pokriti specifičnosti različitih resursa. Popravke bi bile zakrpe.

### Opcija 2: Odvojeni suggestion-i per kurator (bez multi-contributor)

Svaki kurator kreira svoj suggestion. Admin bira koji prihvata.

- **Prednosti:** Nema merge logike. Jednostavnije.
- **Mane:** Dva kuratora rade na istoj lokaciji nezavisno. Dupli posao. Admin mora uporediti i birati. Ne skalira.
- **Zašto odbačeno:** Korisnik eksplicitno želi kolaboraciju na jednom prijedlogu per resurs.

### Opcija 3: Field-level suggestions

Kurator predlaže promjenu jednog polja (ne cijelog resursa).

- **Prednosti:** Minimalna forma. Lako za review.
- **Mane:** Ne pokriva create workflow. Admin mora odobriti svako polje pojedinačno.
- **Zašto odbačeno:** Može se dodati kao poboljšanje u budućnosti, ali per-resource suggestion je potreban za create i bulk update.

### Opcija 4: Zadržati PhotoSuggestion odvojeno

Ostaviti PhotoSuggestion kakav jeste, novi suggestion modeli samo za tekst.

- **Prednosti:** PhotoSuggestion radi, ne dirati.
- **Mane:** Dva odvojena workflow-a za isti resurs (tekst vs slike). Kurator mora koristiti dva različita formulara. Admin mora pregledati dva tipa prijedloga za istu lokaciju.
- **Zašto odbačeno:** Unified prijedlog (tekst + slike) je bolji UX i za kuratora i za admina.

## References

- RFC-0001: Curator Dashboard v2 (`.claude/planning/rfcs/0001-curator-dashboard-v2.md`)
- Existing `PhotoSuggestion` model (`app/models/photo_suggestion.rb`) — referentna implementacija
- `ContentChange` model (`app/models/content_change.rb`) — model koji se zamjenjuje
