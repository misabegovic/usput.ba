---
captured: 2026-10-14
source: "/home/muhamed/projects/phone-brain/sources/github/2026-07-30--misabegovic-usput.ba.md"
digest: fnv1a:b7ba623df67253285fc43a284d393970
agent_directed: 0
kind: snapshot
---
---
kind: source
source_kind: github
source_url: https://github.com/misabegovic/usput.ba
ingested_at: 2026-07-30
owner: misabegovic
repo: usput.ba
---

# misabegovic/usput.ba

> No description

## Metadata

- **default branch:** main
- **language:** Ruby
- **stars:** 6
- **forks:** 4
- **open issues:** 20
- **updated:** 2026-07-30T10:02:04Z

## README

```markdown
# Usput.ba

Discover Bosnia and Herzegovina. A tourism platform featuring curated locations, experiences, audio tours, and AI-powered content generation.

**Discord**: https://discord.gg/kKuc5mnYkc

## Tech Stack

- **Ruby 3.3** / **Rails 8**
- **PostgreSQL** with dual-database setup
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS 4**
- **Solid Queue** for background jobs
- **RubyLLM** for AI content generation
- **Kamal** for deployment

## Quick Start

```bash
# Clone and setup
git clone <repository-url>
cd usput.ba
bin/setup

# Start development server
bin/dev
```

Visit `http://localhost:3000`

## Environment Variables

Create a `.env` file:

```bash
# Database (optional - has defaults)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=
POSTGRES_HOST=localhost

# AI Services
ANTHROPIC_API_KEY=your_key      # Required for AI features
OPENAI_API_KEY=your_key         # Alternative LLM
ELEVENLABS_API_KEY=your_key     # Audio tour generation

# External APIs
GEOAPIFY_API_KEY=your_key       # Geocoding & location discovery

# Production only
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_key
AWS_REGION=eu-central-1
AWS_BUCKET=your_bucket
ROLLBAR_ACCESS_TOKEN=your_token
```

## Project Structure

```
app/
├── controllers/
│   ├── curator/              # Curator dashboard
│   └── new_design/           # Public pages
├── models/                   # ActiveRecord models
├── services/
│   └── ai/                   # AI services
│       ├── location_enricher/    # Description & history generation
│       ├── experience_location_syncer.rb
│       ├── audio_tour_generator.rb
│       └── openai_queue.rb       # LLM wrapper
├── prompts/                  # Centralized AI prompts
└── views/
    ├── curator/              # Curator UI
    └── new_design/           # Public UI

lib/
└── platform/                 # Platform DSL
    ├── dsl/                  # Query language
    └── mcp_server.rb         # MCP integration

config/
├── database.yml              # Dual-database config
└── deploy.yml                # Kamal deployment
```

## Core Models

| Model | Description |
|-------|-------------|
| `Location` | Points of interest with categories, translations, photos |
| `Experience` | Curated collections of locations (tours, activities) |
| `Plan` | Multi-day travel itineraries |
| `AudioTour` | Narrated audio content for locations |
| `ContentChange` | Proposal system for curator contributions |
| `User` | User accounts with curator/admin roles |

### Relationships

```
Location ←─N:M─→ Experience ←─N:M─→ Plan
           via                via
    ExperienceLocation    PlanExperience

Location ←─N:M─→ LocationCategory
           via
  LocationCategoryAssignment
```

## Platform CLI

Query the database using the Platform DSL:

```bash
# Basic queries
bin/platform exec 'locations | count'
bin/platform exec 'experiences | where(city: "Sarajevo") | limit(5)'

# Schema inspection
bin/platform exec 'schema | stats'

# Production database
bin/platform-prod exec 'locations | count'
```

## Curator Dashboard

The curator dashboard (`/curator`) allows content management:

- **Locations** - CRUD with proposal workflow
- **Experiences** - Multi-location collections
- **Plans** - Travel itineraries
- **Audio Tours** - Narrated content
- **Photo Suggestions** - Community photo uploads
- **Proposals** - Review and approval system

Curators submit changes as proposals. Admins review and approve/reject.

## Testing

```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/location_test.rb

# Run CI pipeline (lint + security + tests)
bin/ci
```

## Deployment

Deploy with Kamal:

```bash
bin/kamal deploy          # Deploy to production
bin/kamal console         # Production Rails console
bin/kamal logs            # View logs
```

## Database

Dual-database architecture:

| Database | Purpose |
|----------|---------|
| `klosaer_development` | Primary application data |
| `klosaer_queue_development` | Solid Queue jobs |

```bash
bin/rails db:migrate                    # Primary database
bin/rails db:migrate:queue              # Queue database
```

## Code Quality

```bash
bin/rubocop                # Ruby style
bin/brakeman               # Security scan
bin/bundler-audit          # Dependency audit
```

## License

OSassy License

Copyright © 2026, Muhamed Isabegovic.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

No licensee or downstream recipient may use the Software (including any modified or derivative versions) to directly compete with the original Licensor by offering it to third parties as a hosted, managed, or Software-as-a-Service (SaaS) product or cloud service where the primary value of the service is the functionality of the Software itself.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

```

## File tree

```
  .better_html.yml
  .claude/CLAUDE.md
  .claude/agents/audio-producer.md
  .claude/agents/content-director.md
  .claude/agents/curator.md
  .claude/agents/developer.md
  .claude/agents/guide.md
  .claude/agents/historian.md
  .claude/agents/product-manager.md
  .claude/agents/robert.md
  .claude/agents/tech-lead.md
  .claude/commands/README.md
  .claude/commands/add-experience.md
  .claude/commands/add-location.md
  .claude/commands/adr.md
  .claude/commands/cleanup.md
  .claude/commands/commit.md
  .claude/commands/compact-docs.md
  .claude/commands/design.md
  .claude/commands/implement.md
  .claude/commands/pr.md
  .claude/commands/quality-audit.md
  .claude/commands/rfc.md
  .claude/commands/simplify.md
  .claude/commands/stats.md
  .claude/commands/test.md
  .claude/commands/translate.md
  .claude/commands/verify.md
  .claude/planning/DEVELOPER_ONBOARDING.md
  .claude/planning/IMPLEMENTATION.md
  .claude/planning/LEARNINGS.md
  .claude/planning/README.md
  .claude/planning/TAILWIND_GUIDE.md
  .claude/planning/VISION.md
  .claude/planning/adr/2025-01-15-full-introspection-p0.md
  .claude/planning/adr/ADR-2026-01-16-restore-all-executor-functionality.md
  .claude/planning/architecture/2025-01-15-dsl-first-architecture.md
  .claude/planning/architecture/2025-01-15-implementation-decisions.md
  .claude/planning/archive/ADR-2026-01-16-executor-simplification.md
  .claude/planning/archive/AI_ARCHITECTURE_PROMPT.md
  .claude/planning/archive/DSL_VALIDATION_PLAN.md
  .claude/planning/archive/NEW_OLD_PLAN.md
  .claude/planning/archive/PLAN_CONTENT_ORCHESTRATOR.md
  .claude/planning/archive/PLATFORM_V1.md
  .claude/planning/archive/TECH_DEBT_REVIEW_2026_01_15.md
  .claude/planning/archive/TEST_COVERAGE_70_PLAN.md
  .claude/planning/decisions/2026-02-03-remove-platform-database.md
  .claude/planning/decisions/2026-02-04-ai-services-dsl-migration.md
  .claude/planning/testing/BRAIN_TEST_SCENARIOS.md
  .erb_lint.yml
  .example-env
  .github/FUNDING.yml
  .github/workflows/ci.yml
  .gitignore
  .rubocop.yml
  .ruby-version
  AGENTS.md
  CLAUDE.md
  Dockerfile
  Gemfile
  Gemfile.lock
  PLATFORM.md
  Procfile.dev
  README.md
  Rakefile
  app/assets/audio/usput-home.mp3
  app/assets/builds/.keep
  app/assets/builds/tailwind.css
  app/assets/images/.keep
  app/assets/images/hero_backgrounds/.keep
  app/assets/images/hero_backgrounds/1b.jpg
  app/assets/images/hero_backgrounds/7b41bae7d5aeb4e6dc879b9a07aada16.jpeg
  app/assets/images/hero_backgrounds/9ed41c_e5f03da7eae2457e9632933b7486d13c~mv2.jpg
  app/assets/images/hero_backgrounds/DSC_0232.jpg
  app/assets/images/hero_backgrounds/Hunger-in-Bosnia-and-Herzegovina-2.jpg
  app/assets/images/hero_backgrounds/IMG_7316.jpg
  app/assets/images/hero_backgrounds/PXL_20220925_155452658~2.jpg
  app/assets/images/hero_backgrounds/Sarajevo-BiH_frantic00.jpg
  app/assets/images/hero_backgrounds/Trnovacko-Lake-break.jpg
  app/assets/images/hero_backgrounds/Tuzla,_Kapija_place.jpg
  app/assets/images/hero_backgrounds/Tuzla-Lakes-shutterstock_2005374749.jpg
  app/assets/images/hero_backgrounds/Tuzla-Trg-Slobode-Freedom-Squere-Bosnia-Herzegovina-lll.ba-@tuzlatourism-1.jpg
  app/assets/images/hero_backgrounds/Visit_Tuzla_Tourism.jpeg
  app/assets/images/hero_backgrounds/adobestock-269384202-konjic-tg-1280x800.jpeg
  app/assets/images/hero_backgrounds/aerial-view-of-the-picturesque-town-of-travnik-bosnia-and-herzegovina_5lM7xt4qx.jpg
  app/assets/images/hero_backgrounds/beauty-of-bosnia-herzegovina.jpg
  app/assets/images/hero_backgrounds/bosna-hersek-sehirleri.jpg
  app/assets/images/hero_backgrounds/bosnia-herzegovina-mostar-old-bridge-river-neretva-1250250601-1920x1080.webp
  app/assets/images/hero_backgrounds/caption.jpg
  app/assets/images/hero_backgrounds/images-1.jpeg
  app/assets/images/hero_backgrounds/images-2.jpeg
  app/assets/images/hero_backgrounds/images.jpeg
  app/assets/images/hero_backgrounds/inUacv7LTLsZJi5mJsMzZB.jpg
  app/assets/images/hero_backgrounds/istock-pliva-waterfall-682382146.jpg
  app/assets/images/hero_backgrounds/kravica-waterfalls-bosnia-and-herzegovina-istock.jpg
  app/assets/images/hero_backgrounds/medium_europe-s-biggest-sea-secret-bosnia-and-herzegovina-has-beaches-g0hy_image.jpg
  app/assets/images/hero_backgrounds/shutterstock-1108220324_main_1575276597794.jpeg
  app/assets/images/hero_backgrounds/shutterstock-574540984.webp
  app/assets/images/hero_backgrounds/view-of-the-historic-centre-of-sarajevo-bosnia-and-herzegovina-1132770889.webp
  app/assets/images/seasons/fall/.keep
  app/assets/images/seasons/fall/171021061.4_xxl.webp
  app/assets/images/seasons/fall/AA-20241030-36055319-36055302-MAGICNE_BOJE_JESENI_NA_SJEVERU_HERCEGOVINE.jpg
  app/assets/images/seasons/fall/AA-20241030-36055319-36055307-MAGICNE_BOJE_JESENI_NA_SJEVERU_HERCEGOVINE.jpg
  app/assets/images/seasons/fall/Stara-Majevica_staza.jpg
  app/assets/images/seasons/fall/aa-20241202-36354410-36354406-biser-prirode-vrelo-bosne-u-bojama-jeseni-1733129652.jpg
  app/assets/images/seasons/fall/aa-20241202-36354410-36354407-biser-prirode-vrelo-bosne-u-bojama-jeseni-1733129652.jpg
  app/assets/images/seasons/fall/aa-picture-20151107-6738312-high-.format-webp.width-500.webp
  app/assets/images/seasons/fall/bobovac_azimuth135.jpg
  app/assets/images/seasons/fall/images.jpeg
  app/assets/images/seasons/fall/j13.webp
  app/assets/images/seasons/fall/orasi.webp
  app/assets/images/seasons/fall/pexels-pixabay-33109-scaled.jpg
  app/assets/images/seasons/fall/sadrzaj_2018_2018_01_Tuzla_1911_drvo_jesen.jpeg
  app/assets/images/seasons/fall/viber-image-2025-10-23-14-48-19-877_68fa2af9ac20e.jpg
  app/assets/images/seasons/spring/.keep
  app/assets/images/seasons/spring/6399be35d192b.jpg
  app/assets/images/seasons/spring/Jajce-vodopadi.webp
  app/assets/images/seasons/spring/Strbacki-buk-.jpg
  app/assets/images/seasons/spring/Vodopad-Blihe1.jpg
  app/assets/images/seasons/spring/blagaj-izletiste-1200x900.jpg
  app/assets/images/seasons/spring/gal-lukomir-102.jpg
  app/assets/images/seasons/spring/hajducka-svitanje-scaled-e1607671253649.jpg
  app/assets/images/seasons/spring/maxresdefault.jpg
  app/assets/images/seasons/spring/vodopad-strbacki-buk.jpg
  app/assets/images/seasons/summer/.keep
  app/assets/images/seasons/summer/Ljetna-avantura-RAFTING-U-BOSNI-I-HERCEGOVINI3.jpg
  app/assets/images/seasons/summer/Ljetna-avantura-RAFTING-U-BOSNI-I-HERCEGOVINI6.jpg
  app/assets/images/seasons/summer/Pannonian-Lakes-Panonska-Jezera-Tuzla-Bosnia-Herzegovina-lll.ba-@zigagfx-2-1024x1024.jpg
  app/assets/images/seasons/summer/Una-1.jpg
  app/assets/images/seasons/summer/maxresdefault.jpg
  app/assets/images/seasons/summer/neum-3.jpg
  app/assets/images/seasons/summer/rafting_084-1024x768.jpg
  app/assets/images/seasons/summer/skok.jpg
  app/assets/images/seasons/winter/.keep
  app/assets/images/seasons/winter/glavna-pozadina-1.jpg
  app/assets/images/seasons/winter/jahorina1-960x639-1.jpg
  app/assets/images/seasons/winter/pagebg-mobile.jpg
  app/assets/images/seasons/winter/skijanje-kupres2.jpg
  app/assets/images/seasons/winter/vlasic-bih.jpg
  app/assets/stylesheets/application.css
  app/assets/stylesheets/application.tailwind.css
  app/assets/stylesheets/leaflet.css
  app/assets/tailwind/application.css
  app/controllers/application_controller.rb
  app/controllers/concerns/.keep
  app/controllers/concerns/authenticatable.rb
  app/controllers/concerns/localizable.rb
  app/controllers/curator/admin/base_controller.rb
  app/controllers/curator/admin/content_changes_controller.rb
  app/controllers/curator/admin/curator_applications_controller.rb
  app/controllers/curator/admin/photo_suggestions_controller.rb
  app/controllers/curator/admin/users_controller.rb
  app/controllers/curator/audio_tours_controller.rb
  app/controllers/curator/base_controller.rb
  app/controllers/curator/dashboard_controller.rb
  app/controllers/curator/experiences_controller.rb
  app/controllers/curator/locations_controller.rb
  app/controllers/curator/photo_suggestions_controller.rb
  app/controllers/curator/plans_controller.rb
  app/controllers/curator/proposals_controller.rb
  app/controllers/curator/reviews_controller.rb
  app/controllers/curator_applications_controller.rb
  app/controllers/experiences_controller.rb
  app/controllers/locations_controller.rb
  app/controllers/mine_check_public_controller.rb
  app/controllers/minesweeper_controller.rb
  app/controllers/new_design_controller.rb
  app/controllers/pages_controller.rb
  app/controllers/plans_controller.rb
  app/controllers/reviews_controller.rb
  app/controllers/sessions_controller.rb
  app/controllers/travel_profiles_controller.rb
  app/controllers/user_plans_controller.rb
  app/controllers/users_controller.rb
  app/helpers/application_helper.rb
  app/helpers/curator_helper.rb
  app/helpers/plans_helper.rb
  app/helpers/prompt_helper.rb
  app/javascript/application.js
  app/javascript/controllers/add_to_plan_controller.js
  app/javascript/controllers/application.js
  app/javascript/controllers/audio_tour_controller.js
  app/javascript/controllers/audio_tours_generator_controller.js
  app/javascript/controllers/avatar_upload_controller.js
  app/javascript/controllers/confirm_delete_controller.js
  app/javascript/controllers/cookie_consent_controller.js
  app/javascript/controllers/curator_filters_controller.js
  app/javascript/controllers/curator_menu_controller.js
  app/javascript/controllers/dropdown_controller.js
  app/javascript/controllers/explore_controller.js
  app/javascript/controllers/flash_controller.js
  app/javascript/controllers/generation_status_controller.js
  app/javascript/controllers/home_audio_controller.js
  app/javascript/controllers/index.js
  app/javascript/controllers/listing_filters_controller.js
  app/javascript/controllers/load_more_controller.js
  app/javascript/controllers/mine_check_controller.js
  app/javascript/controllers/minesweeper_controller.js
  app/javascript/controllers/mobile_slider_controller.js
  app/javascript/controllers/multi_photo_upload_controller.js
```
