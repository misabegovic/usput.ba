# Platform Implementation Plan

Plan za implementaciju Platform-a kao centralnog mozga Usput.ba aplikacije.

**ARHITEKTURA:** DSL-First, AI-Native (ADR: 2025-01-15)

---

## Pregled arhitekture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PLATFORM                                        │
│                                                                              │
│  User Input → LLM (Claude) → Generates DSL Query                            │
│                                   ↓                                          │
│                            DSL Parser                                        │
│                                   ↓                                          │
│                           Query Executor                                     │
│                                   ↓                                          │
│                    ┌─────────────────────────────┐                          │
│                    │   LAYERED KNOWLEDGE         │                          │
│                    │                             │                          │
│                    │  L0: Stats (~2K tokens)     │  ← Always in context     │
│                    │  L1: Summaries (~10K each)  │  ← On-demand load        │
│                    │  L2: Clusters (pgvector)    │  ← Semantic search       │
│                    │  L3: Raw records            │  ← Indexed access only   │
│                    └─────────────────────────────┘                          │
│                                   ↓                                          │
│                    Structured Results → LLM → Response                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Zašto DSL-First?

| Pristup | Scale | Problem |
|---------|-------|---------|
| Tools-only | ~1K records | AI ne može rezonovati nad milionima |
| pgvector-only | ~100K records | "Glup" - samo matematička sličnost |
| **DSL-First** | **1M+ records** | AI generiše queries, sistem izvršava |

---

## DSL Grammar (LogQL-inspired)

```
# Layer 0 - Schema i statistike
schema | describe <table>
schema | stats
schema | health

# Layer 1 - AI-generated summaries
summaries { <filters> } | <operations>
summaries { region: "mostar" } | show
summaries { type: "restaurant", period: "30d" } | issues
summaries { category: "heritage" } | trends

# Layer 2 - Semantic clusters
clusters | semantic "<concept>" | top <n>
clusters { id: "<cluster_id>" } | show
clusters | list

# Layer 3 - Raw records (indexed access ONLY)
<table> { <filters> } | <operations>
locations { region: "sarajevo", type: "restaurant" } | sample 10
locations { cluster_id: "ottoman-heritage" } | aggregate count() by city
experiences { city: "mostar" } | where rating > 4 | limit 20

# Operations
| show                      # display result
| issues                    # show problems/gaps
| trends                    # show changes over time
| compare <other>           # compare two entities
| where <condition>         # additional filtering
| select <fields>           # projection
| sample <n>                # random sample
| aggregate <fn> by <field> # GROUP BY
| sort <field> <dir>        # ORDER BY
| limit <n>                 # LIMIT
| explain                   # show query plan, don't execute

# Content mutations (special DSL commands)
create location { name: "...", city: "...", lat: ..., lng: ... }
update location { id: 123 } set { description: "..." }
delete location { id: 123 }
generate description for location { id: 123 }
generate translations for location { id: 123 } to [en, de, fr]
synthesize audio for location { id: 123 } voice "bosnian"
```

---

## Faze implementacije

### Faza 1: Core Infrastructure + DSL Foundation
**Cilj:** Platform CLI radi, DSL parser funkcionalan

```
lib/
  platform/
    cli.rb                    # Thor CLI entry point
    conversation.rb           # Session management
    brain.rb                  # RubyLLM integration + DSL generation

    dsl/
      grammar.rb              # DSL grammar definition
      parser.rb               # DSL parser (Parslet or Treetop)
      executor.rb             # Query execution engine
      validator.rb            # Query validation

    tools/
      base.rb                 # Base tool class (for mutations)
      registry.rb             # Tool registration

bin/
  platform                    # Executable

app/models/
  platform_conversation.rb    # Conversation persistence
```

**Tasks:**
- [ ] Kreirati `bin/platform` executable
- [ ] Implementirati `Platform::CLI` sa Thor
- [ ] Implementirati `Platform::Conversation` za session management
- [ ] Implementirati `Platform::Brain` wrapper za RubyLLM
- [ ] **Implementirati `Platform::DSL::Grammar`** - definicija DSL sintakse
- [ ] **Implementirati `Platform::DSL::Parser`** - parsing DSL queries
- [ ] **Implementirati `Platform::DSL::Executor`** - izvršavanje queries
- [ ] **Implementirati `Platform::DSL::Validator`** - validacija i cost estimation
- [ ] Kreirati `platform_conversations` migraciju
- [ ] Napisati system prompt sa DSL dokumentacijom
- [ ] Testirati basic DSL execution

**Deliverables:**
```bash
$ bin/platform chat

🏔️ Usput.ba Platform

Usput: Zdravo! Ja sam Usput.ba platforma. Kako ti mogu pomoći?

Ti: Koliko imam lokacija u Mostaru?

Usput: [DSL: schema | stats]
       [DSL: locations { city: "Mostar" } | aggregate count()]

       Imaš 47 lokacija u Mostaru:
       - 12 restorana
       - 8 historijskih spomenika
       - 15 kafića
       ...
```

---

### Faza 2: Knowledge Layer 0 (Stats)
**Cilj:** Real-time statistike always-in-context

```
lib/
  platform/
    knowledge/
      layer_zero.rb           # Stats builder and loader

app/models/
  platform_statistic.rb       # Cached statistics

app/jobs/
  platform/
    statistics_job.rb         # Refresh every 5 min
```

**Tasks:**
- [ ] Kreirati `platform_statistics` migraciju
- [ ] Implementirati `Platform::Knowledge::LayerZero`
- [ ] Kreirati `Platform::StatisticsJob` (Solid Queue, every 5 min)
- [ ] Dodati Layer 0 automatski u system prompt
- [ ] Implementirati DSL command: `schema | stats`
- [ ] Implementirati DSL command: `schema | health`

**Layer 0 struktura (~2K tokena, always in context):**
```yaml
schema:
  tables: [locations, experiences, plans, audio_tours, ...]
  relationships: {...}

stats:
  content:
    locations: 523
    experiences: 248
    plans: 156
    audio_tours: 342
  by_city:
    Sarajevo: { locations: 89, experiences: 42 }
    Mostar: { locations: 47, experiences: 18 }
    # ... top 10
  coverage:
    well_covered: ["Sarajevo", "Mostar"]
    sparse: ["Bihać", "Livno"]
    empty: ["Cazin"]
  health:
    api_status: { geoapify: ok, elevenlabs: ok }
    failed_jobs_24h: 3

available_summaries:
  - { dimension: "region", values: ["sarajevo", "mostar", ...] }
  - { dimension: "category", values: ["restaurant", "heritage", ...] }

available_clusters:
  - { id: "ottoman-heritage", count: 145 }
  - { id: "adventure-sports", count: 67 }
```

---

### Faza 3: Knowledge Layer 1 (Summaries)
**Cilj:** AI-generated summaries per region/category

```
app/models/
  knowledge_summary.rb

app/jobs/
  platform/
    summary_generation_job.rb   # Hourly or on-demand

lib/
  platform/
    knowledge/
      layer_one.rb              # Summary generation and loading
```

**Tasks:**
- [ ] Kreirati `knowledge_summaries` migraciju
- [ ] Implementirati `Platform::Knowledge::LayerOne`
- [ ] Implementirati `SummaryGenerationJob`
  - Stratified sampling (ne čitaj sve rekorde)
  - AI generiše summary iz uzorka + statistika
- [ ] Implementirati DSL commands:
  - `summaries { region: "mostar" } | show`
  - `summaries { category: "restaurant" } | issues`
  - `summaries | list`

**Summary struktura (~10K tokena po summary):**
```yaml
dimension: region
dimension_value: mostar
generated_at: 2025-01-15T10:00:00Z
source_count: 47

summary: |
  Mostar je turistički centar Hercegovine sa 47 lokacija u bazi.
  Dominiraju historijski spomenici (35%) i ugostiteljski objekti (40%).

  Snage:
  - Odlična pokrivenost Starog grada
  - Kvalitetni opisi za UNESCO lokacije

  Slabosti:
  - Nedostaju lokacije u širem području (Blagaj, Počitelj)
  - Samo 23/47 ima audio ture

  Preporuke:
  - Dodati 15-20 lokacija za Blagaj
  - Generisati audio za preostalih 24 lokacije

stats:
  by_type: { restaurant: 19, heritage: 16, cafe: 8, ... }
  with_audio: 23
  avg_description_length: 450

issues:
  - { type: "missing_audio", count: 24 }
  - { type: "short_description", count: 8, threshold: 100 }

patterns:
  - "Većina restorana nema prijevod na njemački"
  - "Heritage lokacije imaju najbolje opise"
```

---

### Faza 4: Knowledge Layer 2 (Clusters)
**Cilj:** Semantic clusters za konceptualno pretraživanje

```
app/models/
  knowledge_cluster.rb
  cluster_membership.rb

app/jobs/
  platform/
    cluster_generation_job.rb   # Daily

lib/
  platform/
    knowledge/
      layer_two.rb              # Cluster management
```

**Tasks:**
- [ ] Omogućiti pgvector extension
- [ ] Kreirati `knowledge_clusters` migraciju (sa vector kolonom)
- [ ] Kreirati `cluster_memberships` migraciju
- [ ] Implementirati `Platform::Knowledge::LayerTwo`
- [ ] Implementirati `ClusterGenerationJob`
  - AI predlaže konceptualne grupe
  - Generisanje embeddings za cluster summary
  - Dodjela rekorda clusterima
- [ ] Implementirati DSL commands:
  - `clusters | semantic "ottoman heritage" | top 5`
  - `clusters { id: "adventure-sports" } | show`
  - `locations { cluster_id: "..." } | sample 10`

**Cluster primjeri:**
```yaml
clusters:
  - id: "ottoman-heritage"
    name: "Osmansko nasljeđe"
    summary: "Lokacije vezane za osmansku arhitekturu i historiju..."
    count: 145
    representative_locations: [12, 45, 78, 123]

  - id: "adventure-sports"
    name: "Avanturistički sportovi"
    summary: "Rafting, hiking, paragliding i druge aktivnosti..."
    count: 67
    representative_locations: [34, 56, 89]

  - id: "gastronomic-experiences"
    name: "Gastronomska iskustva"
    summary: "Tradicionalna kuhinja, restorani, kafane..."
    count: 203
```

---

### Faza 5: External Data Integration
**Cilj:** Geoapify i geocoding kroz DSL

```
lib/
  platform/
    dsl/
      external_commands.rb      # External API commands

    services/
      geoapify_client.rb        # API wrapper with rate limiting
```

**Tasks:**
- [ ] Implementirati `GeoapifyClient` sa rate limiting (5 req/sec)
- [ ] Dodati DSL commands:
  - `external | search_pois { city: "Bihać", categories: [...] }`
  - `external | geocode { address: "..." }`
  - `external | validate_location { lat: ..., lng: ... }`
- [ ] Implementirati deduplication (provjera da lokacija ne postoji)
- [ ] Implementirati BiH boundary check

---

### Faza 6: Content Mutations
**Cilj:** CRUD operacije kroz DSL

```
lib/
  platform/
    dsl/
      mutation_commands.rb      # Create, update, delete

app/models/
  platform_audit_log.rb         # Audit trail
```

**Tasks:**
- [ ] Kreirati `platform_audit_logs` migraciju
- [ ] Implementirati mutation DSL commands:
  - `create location { name: "...", city: "...", lat: ..., lng: ... }`
  - `update location { id: 123 } set { description: "..." }`
  - `delete location { id: 123 }` (soft delete)
  - `add translation to location { id: 123 } locale "de" text "..."`
- [ ] Implementirati audit logging za sve mutacije
- [ ] Implementirati validacije (BiH boundary, duplikati, required fields)

---

### Faza 7: AI Content Generation
**Cilj:** AI generisanje opisa, prijevoda kroz DSL

```
lib/
  platform/
    dsl/
      generation_commands.rb    # AI generation commands

    generators/
      description_generator.rb
      translation_generator.rb
```

**Tasks:**
- [ ] Implementirati generation DSL commands:
  - `generate description for location { id: 123 } style "vivid"`
  - `generate translations for location { id: 123 } to [en, de, fr, ...]`
  - `generate experience from locations [1, 2, 3, 4]`
- [ ] Implementirati batch generation:
  - `generate descriptions for locations { city: "Bihać", missing_description: true }`
- [ ] Implementirati jezička pravila (ijekavica za BS, etc.)

---

### Faza 8: Audio Synthesis
**Cilj:** ElevenLabs integracija kroz DSL

```
lib/
  platform/
    dsl/
      audio_commands.rb         # Audio synthesis commands

    services/
      elevenlabs_client.rb      # API wrapper
```

**Tasks:**
- [ ] Implementirati `ElevenlabsClient`
- [ ] Implementirati audio DSL commands:
  - `synthesize audio for location { id: 123 } voice "bosnian"`
  - `estimate audio cost for locations { city: "Mostar", missing_audio: true }`
- [ ] Implementirati voice mapping po jeziku
- [ ] Implementirati chunking za duge tekstove

---

### Faza 9: Full Generation Workflow
**Cilj:** End-to-end generisanje sadržaja za grad

Ovo nije nova funkcionalnost, već demonstracija kako Platform koristi DSL:

```
Ti: Generiši sadržaj za Bihać

Platform:
  [DSL: summaries { region: "bihać" } | show]
  → Bihać ima samo 8 lokacija, treba više sadržaja

  [DSL: external | search_pois { city: "Bihać", radius: 30, categories: [...] }]
  → Pronađeno 45 POI-a iz Geoapify

  [DSL: create location { name: "...", ... }]  (x28 za nove lokacije)

  [DSL: generate descriptions for locations { city: "Bihać", missing_description: true }]

  [DSL: generate translations for locations { city: "Bihać" } to [en, de, hr, sr, ...]]

  [DSL: generate experience from locations [101, 102, 103, 104]]  (x4 iskustva)

  [DSL: synthesize audio for locations { city: "Bihać", top: 10 }]

  Završeno! Kreirano:
  - 28 novih lokacija
  - 4 nova iskustva
  - 10 audio tura
  - Bihać coverage: 8 → 36 lokacija
```

---

### Faza 10: Approval Workflow
**Cilj:** Odobravanje kurator prijedloga kroz DSL

```
lib/
  platform/
    dsl/
      approval_commands.rb
```

**Tasks:**
- [ ] Implementirati approval DSL commands:
  - `proposals | list { status: "pending" }`
  - `proposals { id: 456 } | show`
  - `approve proposal { id: 456 }`
  - `reject proposal { id: 456 } reason "..."`
  - `applications | list { status: "pending" }`
  - `approve application { id: 789 }`

---

### Faza 11: Curator Management
**Cilj:** Automatski spam management

```
lib/
  platform/
    dsl/
      curator_commands.rb

    services/
      spam_detector.rb
```

**Tasks:**
- [ ] Implementirati `SpamDetector` service
- [ ] Implementirati curator DSL commands:
  - `curators | list`
  - `curators { id: 123 } | activity`
  - `curators | check_spam`
  - `block curator { id: 123 } reason "spam"`
- [ ] Automatski spam check u `StatisticsJob`

---

### Faza 12: Introspection
**Cilj:** Platform čita svoj kod i infrastrukturu

```
lib/
  platform/
    dsl/
      introspection_commands.rb
```

**Tasks:**
- [ ] Implementirati introspection DSL commands:
  - `code | read_file "app/models/location.rb"`
  - `code | search "def generate"`
  - `logs | errors { last: "24h" }`
  - `logs | slow_queries { threshold: 1000 }`
  - `infrastructure | queue_status`

---

### Faza 13: Self-Improvement
**Cilj:** Platform priprema prompte za popravke

```
app/models/
  prepared_prompt.rb

lib/
  platform/
    dsl/
      improvement_commands.rb
```

**Tasks:**
- [ ] Kreirati `prepared_prompts` migraciju
- [ ] Implementirati improvement DSL commands:
  - `prepare fix for "N+1 query in LocationsController"`
  - `prepare feature "Add rating to locations"`
  - `prompts | list { status: "pending" }`

---

### Faza 14: Remote Access
**Cilj:** API i MCP pristup

```
app/controllers/
  api/
    platform/
      chat_controller.rb
      status_controller.rb

lib/
  platform/
    mcp_server.rb

bin/
  platform-mcp
```

**Tasks:**
- [ ] Implementirati REST API
- [ ] Implementirati MCP server
- [ ] Testirati sa Claude Desktop

---

### Faza 15: Curator Dashboard Admin Mode
**Cilj:** Photo approval i user management na curator dashboard

**Tasks:**
- [ ] Dodati `admin_mode` flipper flag
- [ ] Implementirati admin middleware
- [ ] Premjestiti photo approval
- [ ] Premjestiti user management

---

### Faza 16: Remove Admin Dashboard
**Cilj:** Ukloniti stari admin dashboard

**Tasks:**
- [ ] Ukloniti admin routes
- [ ] Obrisati admin controllers/views
- [ ] Cleanup

---

### Faza 17: Polish & Documentation
**Cilj:** Production-ready

**Tasks:**
- [ ] Streaming responses
- [ ] Rich terminal output
- [ ] Error handling
- [ ] Rate limiting
- [ ] Test coverage
- [ ] Documentation

---

## Database Migracije

```ruby
# 1. Platform conversations
create_table :platform_conversations, id: :uuid do |t|
  t.jsonb :messages, default: [], null: false
  t.jsonb :context, default: {}
  t.string :status, default: "active"
  t.timestamps
end

# 2. Platform statistics
create_table :platform_statistics do |t|
  t.string :key, null: false
  t.jsonb :value, default: {}, null: false
  t.datetime :computed_at
  t.timestamps
  t.index :key, unique: true
end

# 3. Knowledge summaries
create_table :knowledge_summaries do |t|
  t.string :dimension, null: false
  t.string :dimension_value, null: false
  t.text :summary, null: false
  t.jsonb :stats, default: {}
  t.jsonb :issues, default: []
  t.jsonb :patterns, default: []
  t.integer :source_count
  t.datetime :generated_at
  t.timestamps
  t.index [:dimension, :dimension_value], unique: true
end

# 4. Enable pgvector
enable_extension 'vector'

# 5. Knowledge clusters
create_table :knowledge_clusters do |t|
  t.string :name, null: false
  t.text :summary
  t.jsonb :stats, default: {}
  t.column :embedding, :vector, limit: 1536
  t.jsonb :representative_ids, default: []
  t.timestamps
end
add_index :knowledge_clusters, :embedding, using: :hnsw, opclass: :vector_cosine_ops

# 6. Cluster memberships
create_table :cluster_memberships do |t|
  t.references :knowledge_cluster, null: false, foreign_key: true
  t.string :record_type, null: false
  t.bigint :record_id, null: false
  t.float :similarity_score
  t.timestamps
  t.index [:record_type, :record_id]
end

# 7. Platform audit logs
create_table :platform_audit_logs do |t|
  t.string :action, null: false
  t.string :record_type
  t.bigint :record_id
  t.jsonb :changes, default: {}
  t.string :triggered_by, null: false
  t.uuid :conversation_id
  t.timestamps
  t.index [:record_type, :record_id]
end

# 8. Prepared prompts
create_table :prepared_prompts do |t|
  t.string :prompt_type, null: false
  t.string :title, null: false
  t.text :content, null: false
  t.string :status, default: "pending"
  t.string :severity
  t.jsonb :metadata, default: {}
  t.uuid :conversation_id
  t.timestamps
  t.index :status
end
```

---

## File Structure (Final)

```
lib/
  platform/
    cli.rb
    conversation.rb
    brain.rb

    dsl/
      grammar.rb
      parser.rb
      executor.rb
      validator.rb
      external_commands.rb
      mutation_commands.rb
      generation_commands.rb
      audio_commands.rb
      approval_commands.rb
      curator_commands.rb
      introspection_commands.rb
      improvement_commands.rb

    knowledge/
      layer_zero.rb
      layer_one.rb
      layer_two.rb

    generators/
      description_generator.rb
      translation_generator.rb

    services/
      geoapify_client.rb
      elevenlabs_client.rb
      spam_detector.rb

    mcp_server.rb

app/
  models/
    platform_conversation.rb
    platform_statistic.rb
    platform_audit_log.rb
    knowledge_summary.rb
    knowledge_cluster.rb
    cluster_membership.rb
    prepared_prompt.rb

  jobs/
    platform/
      statistics_job.rb
      summary_generation_job.rb
      cluster_generation_job.rb

  controllers/
    api/
      platform/
        chat_controller.rb
        status_controller.rb

bin/
  platform
  platform-mcp
```

---

## Prioriteti

### P0 - Critical Path (Faze 1-13)
- DSL infrastructure + Knowledge Layer + Content operations + Audio
- **Introspection + Self-Improvement** (pomjereno iz P2)
- **Rezultat:** Platform može generisati sadržaj I razumije sebe

### P1 - Important (Faze 14-15)
- Approval workflow + Curator management
- **Rezultat:** Platform može upravljati kurator prijedlozima

### P2 - Nice to Have (Faza 16)
- Remote access (API, MCP)
- **Rezultat:** Pristup sa Claude Desktop, mobilnih uređaja

### P3 - Cleanup (Faze 17-19)
- Admin mode + Remove old admin + Polish
- **Rezultat:** Production-ready

**ADR:** `decisions/2025-01-15-full-introspection-p0.md`

---

## Ključne odluke

| Odluka | Izbor | Razlog |
|--------|-------|--------|
| Arhitektura | DSL-First | Scale do 1M+ rekorda |
| Knowledge Layer | 4 layera | Optimalno korištenje context window |
| pgvector | Samo za Layer 2 | AI reasoning > similarity search |
| DSL parser | **Parslet** | Pure Ruby, lakše održavanje |
| Embedding model | **OpenAI ada-002** | Provjereno, jednostavno, jeftino |
| Summary refresh | **On-demand + cache** | Lazy approach, Platform odlučuje |
| DSL jezik | **Engleski DSL, bosanska komunikacija** | Standardno + user-friendly |
| Error handling | **User-friendly + tehnički na zahtjev** | Best of both worlds |
| Rollback | **Partial commit** | Ne gubiti uspješan posao |
| Testiranje | **Unit + Integration, Fixtures** | Brzi feedback + sigurnost |
| Introspection | **P0 prioritet** | Platform mora razumjeti sebe |
| Background jobs | Solid Queue | Već konfigurisano |

**ADR:** `decisions/2025-01-15-implementation-decisions.md`

---

## Reference

- ADR: `.claude/planning/decisions/2025-01-15-dsl-first-architecture.md`
- Originalni plan: `.claude/planning/archive/AI_ARCHITECTURE_PROMPT.md`
- LogQL: https://grafana.com/docs/loki/latest/query/
