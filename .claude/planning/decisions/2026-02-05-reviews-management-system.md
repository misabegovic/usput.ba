# ADR-0004: Reviews Management System for Curator Dashboard

## Status
Proposed

## Datum
2026-02-05

## Autori
Product Manager, Tech Lead

## Context

`Review` model već postoji u sistemu — polimorfni model (reviewable: Location, Experience, Plan) sa rating (1-5), comment, author_name. Korisnici mogu ostavljati recenzije na javnim stranicama.

Međutim, **nema nikakvog moderacijskog workflow-a**:

1. **Reviews se ne moderiraju** — Svaki review je odmah vidljiv. Nema zaštite od spama, neprikladnog sadržaja, ili lažnih recenzija.
2. **Kuratori ne vide reviews** — `Curator::ReviewsController` postoji sa `index`, `show`, `destroy` ali nema moderation status, filtriranje, ili flag sistem.
3. **Nema pregleda po resursu** — Admin/kurator ne može vidjeti "sve reviews za ovu lokaciju" u dashboard kontekstu.
4. **Nema bulk akcija** — Svaki review se mora pojedinačno pregledati.

### Trenutno stanje

```ruby
# app/models/review.rb
class Review < ApplicationRecord
  include Identifiable
  belongs_to :reviewable, polymorphic: true
  belongs_to :user, optional: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :comment, length: { maximum: 1000 }
  # Nema moderation_status
  # Nema flag system
end
```

```ruby
# db/schema.rb - reviews tabela
create_table "reviews" do |t|
  t.string "author_name"
  t.text "comment"
  t.integer "rating", null: false
  t.bigint "reviewable_id", null: false
  t.string "reviewable_type", null: false
  t.bigint "user_id"
  t.string "uuid", limit: 36, null: false
  t.timestamps
end
```

### Rute
```ruby
# Trenutno u curator namespace
resources :reviews, only: [ :index, :show, :destroy ]
```

## Decision

Implementirati **dvoslojni reviews management sistem**:

### 1. Review Moderation Status

Dodati `moderation_status` na Review model:

```ruby
# Migration
add_column :reviews, :moderation_status, :integer, default: 0, null: false
add_column :reviews, :moderated_by_id, :bigint
add_column :reviews, :moderated_at, :datetime
add_column :reviews, :moderation_notes, :text
add_foreign_key :reviews, :users, column: :moderated_by_id
add_index :reviews, :moderation_status

# Model
class Review < ApplicationRecord
  enum :moderation_status, {
    unreviewed: 0,   # Default za nove reviews
    approved: 1,     # Pregledano i odobreno
    flagged: 2,      # Označeno za pregled
    removed: 3       # Uklonjeno (soft delete)
  }

  belongs_to :moderated_by, class_name: "User", optional: true

  scope :needs_moderation, -> { where(moderation_status: [:unreviewed, :flagged]) }
  scope :visible, -> { where(moderation_status: [:unreviewed, :approved]) }
  scope :removed, -> { where(moderation_status: :removed) }
end
```

**Odluka o default ponašanju:** Novi reviews su `unreviewed` i **vidljivi na javnim stranicama** (zajedno sa `approved`). Samo `removed` reviews su sakriveni. Ovo izbjegava bottleneck gdje admin mora odobriti svaki review prije nego postane vidljiv.

### 2. Review Flags (kurator flagging)

```ruby
# app/models/review_flag.rb
class ReviewFlag < ApplicationRecord
  belongs_to :review
  belongs_to :user  # Kurator koji flaga

  enum :reason, {
    spam: 0,
    inappropriate: 1,
    inaccurate: 2,
    duplicate: 3,
    other: 4
  }

  validates :reason, presence: true
  validates :review_id, uniqueness: { scope: :user_id,
    message: "already flagged by this user" }

  after_create :auto_flag_review

  private

  def auto_flag_review
    # Automatski promijeni review status na flagged
    # kad dobije prvi flag
    review.flagged! if review.unreviewed?
  end
end
```

```ruby
# Migration
create_table :review_flags do |t|
  t.references :review, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.integer :reason, null: false, default: 0
  t.text :notes
  t.timestamps
end

add_index :review_flags, [:review_id, :user_id], unique: true
```

### 3. Controller struktura

```ruby
# Kurator: pregled + flag
# app/controllers/curator/reviews_controller.rb
class Curator::ReviewsController < Curator::BaseController
  def index
    @reviews = Review.includes(:reviewable, :user)
    @reviews = @reviews.where(reviewable_type: params[:type]) if params[:type]
    @reviews = @reviews.where(moderation_status: params[:status]) if params[:status]
    @reviews = @reviews.where("rating <= ?", params[:max_rating]) if params[:max_rating]
    @reviews = @reviews.order(created_at: :desc).page(params[:page])
  end

  def show
    @review = Review.find(params[:id])
    @flags = @review.review_flags.includes(:user)
  end

  def flag
    @review = Review.find(params[:id])
    flag = @review.review_flags.build(
      user: current_user,
      reason: params[:reason],
      notes: params[:notes]
    )

    if flag.save
      record_activity("review_flagged", recordable: @review)
      redirect_to curator_review_path(@review), notice: "Review flagged."
    else
      redirect_to curator_review_path(@review), alert: flag.errors.full_messages.join(", ")
    end
  end
end

# Admin: moderacija
# app/controllers/curator/admin/reviews_controller.rb
class Curator::Admin::ReviewsController < Curator::Admin::BaseController
  def index
    @reviews = Review.needs_moderation
                     .includes(:reviewable, :user, :review_flags)
                     .order(created_at: :desc)
                     .page(params[:page])
  end

  def approve
    @review = Review.find(params[:id])
    @review.update!(
      moderation_status: :approved,
      moderated_by: current_user,
      moderated_at: Time.current,
      moderation_notes: params[:notes]
    )
    record_activity("review_approved", recordable: @review)
    redirect_to curator_admin_reviews_path, notice: "Review approved."
  end

  def remove
    @review = Review.find(params[:id])
    @review.update!(
      moderation_status: :removed,
      moderated_by: current_user,
      moderated_at: Time.current,
      moderation_notes: params[:notes]
    )
    record_activity("review_removed", recordable: @review)
    redirect_to curator_admin_reviews_path, notice: "Review removed."
  end

  def bulk_action
    review_ids = params[:review_ids]
    action = params[:bulk_action]  # "approve" or "remove"

    Review.where(id: review_ids).find_each do |review|
      review.update!(
        moderation_status: action.to_sym,
        moderated_by: current_user,
        moderated_at: Time.current
      )
    end

    redirect_to curator_admin_reviews_path,
      notice: "#{review_ids.size} reviews #{action}d."
  end
end
```

### 4. Rute

```ruby
namespace :curator do
  resources :reviews, only: [:index, :show] do
    member do
      post :flag
    end
  end

  namespace :admin do
    resources :reviews, only: [:index, :show] do
      member do
        post :approve
        post :remove
      end
      collection do
        post :bulk_action
      end
    end
  end
end
```

### 5. Public scope promjena

Javne stranice trebaju koristiti `.visible` scope umjesto default:

```ruby
# Prije
@reviews = @location.reviews.recent

# Poslije
@reviews = @location.reviews.visible.recent
```

## Consequences

### Positive

- **Zaštita od spama** — Reviews se mogu flaggati i ukloniti
- **Kurator učestvuje** — Kurator može flaggati problematične reviews bez admin pristupa
- **Auto-escalation** — Flag automatski stavlja review u `flagged` status za admin pregled
- **Bulk moderacija** — Admin može brzo obraditi više reviews
- **Soft delete** — `removed` umjesto fizičkog brisanja. Moguć recovery.
- **Audit trail** — `moderated_by`, `moderated_at`, `moderation_notes` za praćenje

### Negative

- **Migracija na postojećoj tabeli** — Sve postojeće reviews dobijaju `unreviewed` status. Ako ih je puno, mogao bi biti backlog za pregled.
- **Public visibility promjena** — Treba ažurirati sve public views da koriste `.visible` scope. Propušteni query može prikazati `removed` review.
- **Još jedna tabela** — `review_flags` je nova tabela.

### Neutral

- **Postojeći destroy ostaje** — `Curator::ReviewsController#destroy` se može zadržati za admin-only hard delete ili zamijeniti sa `remove` (soft delete). Preporučujem zamjenu.
- **Unreviewed su vidljivi** — Namjerna odluka. Alternativa (invisible dok admin ne odobri) bi blokirala UGC tok.

## Alternatives Considered

### Opcija 1: Samo admin delete (bez flag/moderation)

Admin može samo obrisati reviews. Nema statusa, nema flagova.

- **Prednosti:** Minimalna promjena. Radi sad.
- **Mane:** Kurator ne može učestvovati. Admin mora sam pronaći problematične reviews. Nema audit trail.
- **Zašto odbačeno:** Ne skalira. Kad reviews porastu, admin ne može sve pregledati.

### Opcija 2: Pre-moderation (reviews nevidljivi dok admin ne odobri)

Svaki review čeka admin approval prije javnog prikaza.

- **Prednosti:** Potpuna kontrola kvaliteta.
- **Mane:** UGC tok se zaustavlja. Korisnik ostavlja review i ne vidi ga. Loše iskustvo. Admin bottleneck.
- **Zašto odbačeno:** Za turističku platformu sa malim admin timom, pre-moderation bi ugušio UGC.

### Opcija 3: AI auto-moderation

Koristiti AI za automatsku klasifikaciju reviews (spam, sentiment, quality).

- **Prednosti:** Skalira bez admin effort-a.
- **Mane:** Košta. Lažni positivi. Kompleksna implementacija. Overkill za trenutni volumen.
- **Zašto odbačeno:** Može se dodati u budućnosti kao enhancement. Trenutno je flag + admin review dovoljno.

## References

- RFC-0001: Curator Dashboard v2 (`.claude/planning/rfcs/0001-curator-dashboard-v2.md`)
- Existing `Review` model (`app/models/review.rb`)
- Existing `Curator::ReviewsController` (`app/controllers/curator/reviews_controller.rb`)
