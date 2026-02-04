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
