# Review Approval System - Plan implementacije

**Datum:** 2026-02-07
**Status:** Proposed
**Autor:** Claude (po zahtjevu korisnika)

---

## Pregled

Implementacija sistema za odobravanje korisničkih recenzija. Svaki review mora proći moderaciju (approve/reject) prije nego bude vidljiv javnosti. Samo ulogovani korisnici mogu ostaviti review. Korisnik uvijek vidi svoje vlastite reviewove, bez obzira na status.

---

## Ključne odluke

| Pitanje | Odluka |
|---------|--------|
| Ko može ostaviti review? | Samo ulogovani korisnici |
| Username polje na formi? | Ukloniti - ime se uzima iz `user.username` |
| Početni status reviewa? | `pending` - čeka odobrenje |
| Ko vidi pending review? | Samo autor (svoj review) |
| Ko odobrava? | Curatori i admini na curator dashboardu |
| Može li korisnik editovati? | Da, dok god želi |
| Više reviewova po resursu? | Da, korisnik može ostaviti više |
| Average rating kalkulacija? | Samo `approved` reviewovi |
| Average rating za ulogovanog korisnika? | Uključuje i njihove `pending` reviewove |
| Notifikacije? | Ne - korisnik vidi status svog reviewa na stranici |
| Postojeći reviewovi? | Svi idu u `pending` - moraju biti odobreni |
| Rejected review? | Korisnik ga vidi sa statusom, može editovati i ponovo poslati |

---

## Faze implementacije

### Faza 1: Database migracija i model

**Migracija: `AddStatusToReviews`**

```ruby
# db/migrate/XXXXXX_add_status_to_reviews.rb
class AddStatusToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :status, :integer, default: 0, null: false
    add_column :reviews, :reviewed_by_id, :bigint, null: true
    add_column :reviews, :reviewed_at, :datetime, null: true

    add_index :reviews, :status
    add_index :reviews, :reviewed_by_id
    add_foreign_key :reviews, :users, column: :reviewed_by_id

    # Svi postojeći reviewovi idu u pending
    # (default: 0 = pending, tako da ovo nije ni potrebno eksplicitno)
  end
end
```

**Fajlovi za promijeniti:**

- `app/models/review.rb` - Dodati enum, scope-ove, validacije
- `app/models/concerns/reviewable.rb` - Ažurirati average_rating logiku

**Review model promjene:**

```ruby
class Review < ApplicationRecord
  # Dodati:
  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :pending

  belongs_to :user                          # ukloniti optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  # Novi scope-ovi:
  scope :approved, -> { where(status: :approved) }
  scope :pending, -> { where(status: :pending) }
  scope :visible_to, ->(user) {
    if user
      where(status: :approved).or(where(user_id: user.id))
    else
      approved
    end
  }

  # Promijeniti after_save callback da računa samo approved
  def update_reviewable_average_rating
    return unless reviewable
    avg = reviewable.reviews.approved.average(:rating) || 0
    reviewable.update_column(:average_rating, avg.round(2))
  end

  # Novi metodi:
  def approve!(reviewer)
    update!(status: :approved, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def reject!(reviewer)
    update!(status: :rejected, reviewed_by: reviewer, reviewed_at: Time.current)
  end

  def author_display_name
    user&.username || author_name.presence || "Anonimno"
  end

  def owned_by?(u)
    user_id == u&.id
  end

  def editable_by?(u)
    owned_by?(u) && !approved?
  end
end
```

**Reviewable concern promjene:**

```ruby
module Reviewable
  # Ažurirati scope-ove da računaju samo approved reviewove:
  scope :popular, -> { order(average_rating: :desc, reviews_count: :desc) }
  # reviews_count ostaje isti (ukupan), ali average_rating će reflektovati samo approved

  # Dodati metode za prikaz sa user kontekstom:
  def visible_reviews(user = nil)
    reviews.visible_to(user)
  end

  def effective_rating_for(user)
    if user
      relevant = reviews.approved.or(reviews.where(user_id: user.id))
      relevant.average(:rating)&.round(2) || average_rating || 0
    else
      average_rating || 0
    end
  end
end
```

---

### Faza 2: Public ReviewsController + forma

**Fajlovi za promijeniti:**

- `app/controllers/reviews_controller.rb` - Zahtijevati login, ukloniti author_name, dodati edit/update
- `app/views/reviews/_form.html.erb` - Ukloniti author_name polje, dodati login poruku
- `app/views/reviews/_reviews_section.html.erb` - Filtrirati po statusu, prikazati pending badge
- `app/views/reviews/_review_card.html.erb` - Dodati status badge, edit dugme

**ReviewsController promjene:**

```ruby
class ReviewsController < ApplicationController
  before_action :set_reviewable
  before_action :require_login, only: [:create, :edit, :update]
  before_action :set_review, only: [:edit, :update]

  def index
    @page = (params[:page] || 1).to_i
    @per_page = 5
    @reviews = @reviewable.reviews.visible_to(current_user)
                          .recent
                          .offset((@page - 1) * @per_page)
                          .limit(@per_page)
    @total_reviews = @reviewable.reviews.visible_to(current_user).count
    @has_more = (@page * @per_page) < @total_reviews
    # ... respond_to ostaje isto
  end

  def create
    @review = @reviewable.reviews.build(review_params)
    @review.user = current_user
    @review.status = :pending
    # ... respond_to ostaje isto
  end

  def edit
    # Turbo frame ili standalone
  end

  def update
    if @review.update(review_params)
      @review.update!(status: :pending, reviewed_by: nil, reviewed_at: nil) if @review.rejected?
      # redirect nazad na resurs
    else
      # render edit errors
    end
  end

  private

  def set_review
    @review = Review.find(params[:id])
    unless @review.editable_by?(current_user)
      redirect_to polymorphic_path(@reviewable), alert: "Nemaš pristup."
    end
  end

  def review_params
    params.require(:review).permit(:rating, :comment) # bez author_name
  end
end
```

**Rute - dodati `edit` i `update`:**

```ruby
resources :locations, only: [:show] do
  resources :reviews, only: [:index, :create, :edit, :update]
end
# Isto za experiences i plans
```

**Forma (`_form.html.erb`) promjene:**
- Ukloniti `author_name` polje
- Prikazati username ulogovanog korisnika
- Ako korisnik nije ulogovan, prikazati poruku "Prijavi se da ostaviš recenziju" sa linkom na login
- Dodati info tekst: "Tvoja recenzija će biti vidljiva nakon odobrenja"

**Review card (`_review_card.html.erb`) promjene:**
- Koristiti `review.author_display_name` umjesto `review.author_name`
- Ako je review `pending` i pripada current_user-u, prikazati badge "Čeka odobrenje"
- Ako je review `rejected` i pripada current_user-u, prikazati badge "Odbijeno" + edit dugme
- Ostali korisnici nikada ne vide pending/rejected reviewove (query to osigurava)

**Reviews section (`_reviews_section.html.erb`) promjene:**
- Koristiti `visible_to(current_user)` za query
- Ažurirati count da reflektuje vidljive reviewove
- Prikazati formu samo ulogovanim korisnicima

---

### Faza 3: Curator Dashboard - pregled i odobravanje

**Fajlovi za promijeniti:**

- `app/controllers/curator/reviews_controller.rb` - Dodati `approve` i `reject` akcije, status filter
- `app/views/curator/reviews/index.html.erb` - Dodati status badge, approve/reject dugmad, status filter
- `app/views/curator/reviews/show.html.erb` - Dodati approve/reject dugmad, status prikaz

**Curator::ReviewsController promjene:**

```ruby
module Curator
  class ReviewsController < BaseController
    before_action :set_review, only: [:show, :destroy, :approve, :reject]

    def index
      @reviews = Review.includes(:reviewable, :user).order(created_at: :desc)

      # Dodati status filter
      @reviews = @reviews.where(status: params[:status]) if params[:status].present?
      # ... ostali filteri ostaju

      @stats = {
        total: Review.count,
        pending: Review.pending.count,
        approved: Review.approved.count,
        rejected: Review.where(status: :rejected).count,
        average_rating: Review.approved.average(:rating)&.round(2) || 0,
        # ...
      }
    end

    def approve
      @review.approve!(current_user)
      record_activity("review_approved", @review)
      redirect_to curator_reviews_path(status: :pending),
                  notice: "Recenzija odobrena."
    end

    def reject
      @review.reject!(current_user)
      record_activity("review_rejected", @review)
      redirect_to curator_reviews_path(status: :pending),
                  notice: "Recenzija odbijena."
    end
  end
end
```

**Rute:**

```ruby
namespace :curator do
  resources :reviews, only: [:index, :show, :destroy] do
    member do
      post :approve
      post :reject
    end
  end
end
```

**Curator index view promjene:**
- Dodati stats kartice za pending/approved/rejected
- Dodati status filter (dropdown: Svi / Pending / Approved / Rejected)
- Svaki review red prikazuje status badge (žuto=pending, zeleno=approved, crveno=rejected)
- Pending reviewovi imaju Approve/Reject dugmad inline
- Default filter: `pending` (da odmah vide šta treba odobriti)

**Curator show view promjene:**
- Prikazati status badge
- Approve/Reject dugmad (samo za pending)
- Info o tome ko je odobrio/odbio i kada

---

### Faza 4: CuratorActivity integracija

**Fajlovi za promijeniti:**

- `app/models/curator_activity.rb` - Dodati `review_approved` i `review_rejected` u ACTIONS

**Novi action tipovi:**

```ruby
ACTIONS = %w[
  # ... postojeći
  review_approved
  review_rejected
]
```

---

### Faza 5: Testovi

**Novi/ažurirani test fajlovi:**

- `test/models/review_test.rb` - Ažurirati za status enum, approve/reject, visible_to scope
- `test/controllers/reviews_controller_test.rb` - Login required, create sa pending status, edit/update
- `test/controllers/curator/reviews_controller_test.rb` - Approve/reject, filteri

**Ključni test scenariji:**

```ruby
# Model testovi
- review se kreira sa status: pending
- approve! mijenja status i postavlja reviewed_by
- reject! mijenja status i postavlja reviewed_by
- visible_to(nil) vraća samo approved
- visible_to(user) vraća approved + korisnikove reviewove
- average_rating se računa samo iz approved reviewova
- editable_by? vraća true za autora pending/rejected reviewa
- editable_by? vraća false za approved review
- editable_by? vraća false za drugog korisnika

# Controller testovi
- neulogovani korisnik ne može kreirati review
- ulogovani korisnik kreira review sa status pending
- neulogovani korisnik vidi samo approved reviewove
- ulogovani korisnik vidi approved + svoje reviewove
- korisnik može editovati svoj pending/rejected review
- korisnik ne može editovati tuđi review

# Curator controller testovi
- curator može odobriti pending review
- curator može odbiti pending review
- status filter radi
- activity se logira za approve/reject
```

---

## Dijagram toka

```
Korisnik (ulogovan) → Ostavlja review
                           ↓
                    Review kreiran (status: pending)
                           ↓
            ┌──────────────┼──────────────┐
            ↓              ↓              ↓
    Autor vidi svoj    Javnost ne     Curator/Admin
    review odmah       vidi review    vidi u dashboardu
    (pending badge)                        ↓
                                    ┌──────┴──────┐
                                    ↓             ↓
                                 Approve       Reject
                                    ↓             ↓
                              Status →       Status →
                              approved       rejected
                                    ↓             ↓
                              Javnost vidi   Autor vidi
                              review         "Odbijeno"
                                              + može editovati
                                                   ↓
                                             Edit → ponovo
                                             status → pending
```

---

## Fajlovi za kreirati/modificirati (sumarno)

### Novi fajlovi
| Fajl | Opis |
|------|------|
| `db/migrate/XXXXXX_add_status_to_reviews.rb` | Migracija za status, reviewed_by, reviewed_at |

### Modificirani fajlovi
| Fajl | Promjena |
|------|----------|
| `app/models/review.rb` | Enum, scope-ovi, approve!/reject!, user obavezan |
| `app/models/concerns/reviewable.rb` | visible_reviews, effective_rating_for |
| `app/controllers/reviews_controller.rb` | Login required, edit/update, visible_to filter |
| `app/controllers/curator/reviews_controller.rb` | approve/reject akcije, status filter |
| `app/views/reviews/_form.html.erb` | Ukloniti author_name, login check |
| `app/views/reviews/_review_card.html.erb` | Status badge, edit dugme, author_display_name |
| `app/views/reviews/_reviews_section.html.erb` | visible_to filter, login gate za formu |
| `app/views/reviews/index.turbo_stream.erb` | Proslijediti current_user kontekst |
| `app/views/curator/reviews/index.html.erb` | Status filter, approve/reject dugmad, pending stats |
| `app/views/curator/reviews/show.html.erb` | Status badge, approve/reject dugmad |
| `app/models/curator_activity.rb` | Dodati review_approved/review_rejected |
| `config/routes.rb` | Dodati edit/update za reviews, approve/reject member rute |
| `test/models/review_test.rb` | Ažurirati sve testove |

---

## Redoslijed implementacije

1. **Migracija** - `add_status_to_reviews` (5 min)
2. **Review model** - enum, scope-ovi, metode (15 min)
3. **Reviewable concern** - visible_reviews, rating logika (10 min)
4. **Rute** - edit/update, approve/reject (5 min)
5. **ReviewsController** - login, create, edit, update (15 min)
6. **Review forma** - ukloniti author_name, login gate (10 min)
7. **Review card** - status badge, edit dugme (10 min)
8. **Reviews section** - visible_to, login gate (10 min)
9. **Curator ReviewsController** - approve/reject, filteri (15 min)
10. **Curator views** - status badge, approve/reject UI (15 min)
11. **CuratorActivity** - novi action tipovi (5 min)
12. **Testovi** - model, controller, curator (30 min)

---

## Napomene

- `reviews_count` counter cache na reviewable modelima ostaje ukupan broj (svi statusi). Ovo je ok jer se koristi za `popular` scope, a `average_rating` se računa samo iz approved.
- `author_name` kolona ostaje u bazi za backward compatibility sa postojećim reviewovima koji možda nemaju `user_id`. Ne brisati kolonu iz tabele.
- Kad korisnik edituje rejected review, status se vraća na `pending` za re-moderaciju.
- Turbo Stream update nakon kreiranja reviewa treba prikazati review sa pending badge-om.

---

*Zadnje ažuriranje: 2026-02-07*
