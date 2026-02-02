# /design

Dizajniraj feature ili sistem.

**Agent:** Tech Lead + Product Manager

## Korištenje

```
/design [feature]
/design "User authentication system"
/design --component "Search API"
```

## Proces

### 1. Requirements gathering

**Product perspective:**
- Ko su korisnici?
- Koji problem rješavamo?
- Koji su use cases?
- Koji su acceptance criteria?

**Technical perspective:**
- Koji su constraints?
- Koje integracije su potrebne?
- Koji su performance zahtjevi?

### 2. High-level dizajn

```markdown
## Components

┌─────────────┐     ┌─────────────┐
│   Client    │────▶│   API       │
└─────────────┘     └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Service   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Database  │
                    └─────────────┘
```

### 3. Data model

```ruby
# Models
class Feature < ApplicationRecord
  belongs_to :user
  has_many :items

  validates :name, presence: true
end

# Migrations
create_table :features do |t|
  t.string :name, null: false
  t.references :user, foreign_key: true
  t.timestamps
end
```

### 4. API dizajn

```ruby
# Routes
resources :features do
  member do
    post :activate
  end
end

# Controller
class FeaturesController < ApplicationController
  def index
    @features = Feature.all
  end

  def create
    @feature = Feature.new(feature_params)
    # ...
  end
end
```

### 5. UI/UX (ako relevantno)

```
Wireframe ili opis:
- Lista features sa search
- Detail view sa actions
- Create/Edit form
```

## Output

```markdown
## Design: [Feature Name]

### Overview
[1-2 rečenice opis]

### User Stories
- As a user, I can...
- As an admin, I can...

### Components
- [Component 1]: [opis]
- [Component 2]: [opis]

### Data Model
[ERD ili model definitions]

### API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /features | List all |
| POST | /features | Create new |

### Implementation Plan
1. [ ] Create migration
2. [ ] Create model
3. [ ] Create controller
4. [ ] Create views
5. [ ] Add tests

### Open Questions
- [Pitanje 1]?
- [Pitanje 2]?

---
Proceed to implementation? [y/n]
```
