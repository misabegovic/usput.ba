# Usput.ba

A tourism platform for Bosnia and Herzegovina featuring AI-generated content, audio tours, and travel planning.

## Tech Stack

- **Framework**: Ruby on Rails 8.1.1
- **Ruby**: 3.3.6
- **Database**: PostgreSQL (dual-database setup)
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS 4
- **Asset Pipeline**: Propshaft + Import Maps
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable
- **Deployment**: Kamal (Docker-based)
- **Web Server**: Puma + Thruster

## Key Features

- **AI Content Generation**: Autonomous pipeline using RubyLLM to generate locations, experiences, and travel plans
- **Audio Tours**: ElevenLabs integration for narrated location tours
- **Geocoding**: Geoapify API for location discovery and geocoding
- **Multi-language Support**: 14 languages via Translatable concern
- **Feature Flags**: Flipper for feature management
- **Error Monitoring**: Rollbar integration
- **Rate Limiting**: Rack::Attack for request throttling

## Prerequisites

- Ruby 3.3.6
- PostgreSQL 14+
- Foreman (installed automatically by `bin/dev`)

## Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd usput.ba
   ```

2. **Configure environment variables**

   Create a `.env` file with required credentials:
   ```bash
   # Database (optional, defaults provided)
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=
   POSTGRES_HOST=localhost
   POSTGRES_PORT=5432

   # AI/External Services
   OPENAI_API_KEY=your_key          # For RubyLLM
   ANTHROPIC_API_KEY=your_key       # For RubyLLM (alternative)
   GEOAPIFY_API_KEY=your_key        # Location discovery
   ELEVENLABS_API_KEY=your_key      # Audio tour generation
   AWS_ACCESS_KEY_ID=your_key       # S3 storage (production)
   AWS_SECRET_ACCESS_KEY=your_key
   AWS_REGION=your_region
   AWS_BUCKET=your_bucket

   # Error Monitoring
   ROLLBAR_ACCESS_TOKEN=your_token
   ```

3. **Run setup**
   ```bash
   bin/setup
   ```

   This will:
   - Install gem dependencies
   - Create and migrate databases
   - Clear logs and temp files
   - Start the development server

4. **Or start manually**
   ```bash
   bin/dev
   ```

   This starts:
   - Rails server on port 3000
   - Tailwind CSS watcher

## Database Architecture

The application uses a dual-database setup:

| Database | Purpose |
|----------|---------|
| `klosaer_development` | Primary application data |
| `klosaer_queue_development` | Solid Queue job storage |

Migrations for the queue database are in `db/queue_migrate/`.

## Running Tests

```bash
# Run all tests
bin/rails test

# Run system tests
bin/rails test:system

# Run full CI pipeline
bin/ci
```

The CI pipeline includes:
- Ruby style checks (RuboCop)
- Security audits (bundler-audit, Brakeman, importmap audit)
- Unit and system tests
- Seed verification

## Background Jobs

Start the job worker:
```bash
bin/jobs
```

Jobs are processed by Solid Queue. In development, jobs run synchronously by default.

## AI Content Generation

The platform includes an autonomous AI content generation pipeline:

```bash
# Generate content via rake task
bin/rails ai:generate

# Check content status
bin/rails ai:status
```

The AI pipeline:
1. Analyzes gaps in content coverage
2. Fetches locations via Geoapify API
3. Enriches locations with AI-generated descriptions
4. Creates experiences linking multiple locations
5. Generates travel plans for tourist profiles

Audio tours are generated separately due to ElevenLabs API costs.

## Key Directories

```
app/
├── models/           # ActiveRecord models
├── services/
│   ├── ai/           # AI content generation services
│   │   ├── content_orchestrator.rb
│   │   ├── experience_creator.rb
│   │   ├── location_enricher.rb
│   │   ├── plan_creator.rb
│   │   └── audio_tour_generator.rb
│   └── geoapify_service.rb
├── jobs/             # Background jobs
└── views/

config/
├── database.yml      # Dual-database configuration
├── deploy.yml        # Kamal deployment config
└── initializers/
    └── ruby_llm.rb   # AI configuration

lib/tasks/
├── ai.rake           # AI generation tasks
├── audio_tours.rake  # Audio generation tasks
└── cities.rake       # City/location management
```

## Deployment

The application deploys via Kamal:

```bash
# Deploy to production
bin/kamal deploy

# Access production console
bin/kamal console

# View logs
bin/kamal logs

# SSH into server
bin/kamal shell
```

### Production Environment Variables

Required secrets in `.kamal/secrets`:
- `RAILS_MASTER_KEY`
- `DATABASE_URL`
- `QUEUE_DATABASE_URL`
- `ROLLBAR_ACCESS_TOKEN`

## Docker

Build and run locally:
```bash
docker build -t usput .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<key> usput
```

The Dockerfile uses:
- Multi-stage build for smaller images
- jemalloc for reduced memory usage
- Thruster for HTTP asset caching/compression

## Code Quality

```bash
# Run RuboCop
bin/rubocop

# Security scan
bin/brakeman

# Audit dependencies
bin/bundler-audit
```

## Core Models

| Model | Description |
|-------|-------------|
| `Location` | Points of interest with translations |
| `Experience` | Curated collections of locations |
| `Plan` | Multi-day travel itineraries |
| `AudioTour` | Narrated audio content for locations |
| `User` | User accounts with bcrypt authentication |
| `Setting` | Key-value configuration storage |

### Relationships

```
Location ←──N:M──→ Experience ←──N:M──→ Plan
              via                 via
       ExperienceLocation    PlanExperience
```

## Rate Limits

- **Geoapify API**: 5 requests/second (enforced in `Ai::RateLimiter`)
- **Rack::Attack**: Configured for abuse prevention

## Contributing

1. Run the full CI pipeline before submitting PRs: `bin/ci`
2. Follow Rails Omakase Ruby style guide
3. Add tests for new functionality
4. Update this README for significant changes

## License

Proprietary - All rights reserved.
