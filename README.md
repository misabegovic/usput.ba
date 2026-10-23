# Usput.ba

Discover Bosnia and Herzegovina. A tourism platform featuring curated locations, experiences, audio tours, and AI-powered content generation.

**Discord**: https://discord.gg/kKuc5mnYkc

## Tech Stack

- **Ruby 4.0** / **Rails 8.1**
- **PostgreSQL** with dual-database setup
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS 4**
- **Solid Queue** for background jobs
- **RubyLLM** for AI content generation
- **Kamal** for deployment

## Supported browsers

Usput works on iOS 15.4 and later, and on Android phones whose browser still
updates: Chrome and Android WebView 99, Samsung Internet 18, Firefox 115, and
the desktop versions of the same. Older browsers still get the pages, rendered
on the server, with a notice that the map, plans and check-ins need a newer
browser. Why the floor sits there: `wiki/decisions/support-phones-from-ios-15.md`.

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
├── avo/                      # The admin at /admin (Avo)
├── controllers/              # Public pages
├── models/                   # ActiveRecord models
├── services/
│   └── ai/                   # AI services
│       ├── location_enricher/    # Description & history generation
│       ├── experience_location_syncer.rb
│       ├── audio_tour_generator.rb
│       └── openai_queue.rb       # LLM wrapper
├── prompts/                  # Centralized AI prompts
└── views/
    └── new_design/           # Public UI

lib/
└── platform/                 # Platform DSL
    └── dsl/                  # Query language

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
| `Review` | Travellers' ratings, sorted by Jev and decided by curators |
| `Moment` | Travellers' photos at places they checked in at |
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

## usput CLI and MCP

The usput commands, under the same roles as the admin:

```bash
bin/usput help
bin/usput places list city=Mostar limit=5
bin/usput reviews queue --as curator@usput.local
bin/usput reviews approve <review-uuid> --as curator@usput.local
bin/usput doctor --as admin@usput.local --json
```

`bin/usput mcp` serves them to an agent over stdio (`.mcp.json` points agents
in this repository at it). Remote agents call `POST /mcp` with a token from
`bin/usput tokens issue EMAIL NAME`; in this first release only admins, and
only the reading commands.

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

## Admin

Curators and admins work in the admin at `/admin` (Avo): places, experiences,
plans and audio tours are edited directly, moments and reviews are approved or
rejected from their queues, and admins change roles and block accounts. Every
decision is recorded in Rails Event Store, readable by admins at
`/event-store`.

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
