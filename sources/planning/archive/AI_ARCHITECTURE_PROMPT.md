# Usput.ba AI-Native Data Architecture

## Project Context

**Product:** Usput.ba — tourism platform for Bosnia and Herzegovina
**Stack:** Ruby on Rails, PostgreSQL, RubyLLM
**Scale:** Millions of records (locations, tours, events, user activity)
**Goal:** Build an admin CLI where an LLM can reason against the entire dataset without context window limitations

---

## Core Problem

Traditional RAG fails at this scale:
- Can't dump millions of records into context
- Naive vector search returns too much or irrelevant data
- "Lost in the middle" problem kills reasoning quality
- Round-trip tool calling is too slow for exploration

---

## Architectural Decision: Layered Knowledge Architecture

The LLM should "inhabit" a pre-digested knowledge structure, not query raw data.

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 0: Schema + Meta (always in context, ~2K tokens)         │
│  - Table schemas, relationships, enums                          │
│  - Live statistics: counts, distributions, health metrics       │
│  - Known issues, data quality flags                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: Summaries (loadable on-demand, ~10K tokens each)      │
│  - Per-region summaries                                         │
│  - Per-category summaries                                       │
│  - Temporal summaries (this week, this month, trends)           │
│  - AI-generated insights, patterns, anomalies                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: Semantic Clusters (~1000s of embedded summaries)      │
│  - Conceptual groupings: "Ottoman heritage", "adventure sports" │
│  - Each cluster has: summary, stats, representative examples    │
│  - Searchable via embeddings                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: Raw Records (drill-down only)                         │
│  - Individual locations, tours, events                          │
│  - Only accessed for specific examples or edge cases            │
│  - Always filtered/indexed access, never scans                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Query Interface: LogQL-Inspired DSL

The LLM generates queries in a constrained DSL, not raw SQL or natural language.

### DSL Grammar (Draft)

```
# Layer 0 - Schema exploration
schema | describe <table>
schema | stats
schema | health

# Layer 1 - Summary access
summaries { <filters> } | <operations>

# Filter syntax
summaries { region: "mostar" }
summaries { type: "landmark", period: "30d" }
summaries { category: "accommodation" }

# Operations
| show                     # display summary
| issues                   # show problems/gaps
| trends                   # show changes over time
| compare <other>          # compare two summaries

# Layer 2 - Semantic exploration  
clusters | semantic "<concept>" | top <n>
clusters | list { <filters> }
clusters { id: "<cluster_id>" } | show

# Layer 3 - Drill-down
<table> { <filters> } | <operations>

# Table filters (translated to indexed queries)
locations { region: "sarajevo", type: "restaurant" }
locations { cluster_id: "ottoman-heritage" }
locations { created_at: "> now() - 7d" }
tours { status: "published", region: "mostar" }

# Table operations
| where <condition>        # additional filtering
| select <fields>          # projection
| sample <n>               # random sample (TABLESAMPLE)
| aggregate <fn> by <field> # GROUP BY
| sort <field> <dir>       # ORDER BY
| limit <n>                # LIMIT
| explain                  # show query plan, don't execute

# Chaining
locations { region: "mostar" } 
  | where images_count < 2 
  | aggregate count() by type 
  | sort count desc
```

### DSL Execution Engine

The DSL parser should:
1. Validate syntax before execution
2. Translate to optimized backend queries (ActiveRecord, ClickHouse, Elasticsearch)
3. Enforce limits (max rows, timeout)
4. Return structured results + metadata (row count, execution time)

---

## Data Models

### Core Tables (PostgreSQL)

```ruby
# Existing/assumed tables
locations     # POIs: landmarks, restaurants, hotels, etc.
tours         # Curated routes/treasure hunts
tour_stops    # Join: tours <-> locations with ordering
events        # User activity: views, completions, favorites
users         # End users
media         # Self-hosted images/videos

# Required fields on locations (adjust as needed)
# - region: string (indexed)
# - location_type: enum (indexed)  
# - coordinates: point (PostGIS)
# - description: text
# - created_at, updated_at
# - images_count: integer (counter cache)
# - views_count: integer (counter cache)
# - data_quality_score: float (computed)
```

### Knowledge Layer Tables (New)

```ruby
# Layer 0: Live statistics
create_table :data_statistics do |t|
  t.string :key, null: false, index: { unique: true }
  t.jsonb :value, null: false
  t.datetime :computed_at, null: false
end

# Layer 1: AI-generated summaries
create_table :knowledge_summaries do |t|
  t.string :dimension, null: false      # 'region', 'category', 'temporal'
  t.string :dimension_value, null: false # 'mostar', 'landmark', '2024-w03'
  t.text :summary, null: false           # AI-generated prose
  t.jsonb :stats, null: false            # structured metrics
  t.jsonb :issues, default: []           # detected problems
  t.jsonb :patterns, default: []         # detected patterns
  t.datetime :generated_at, null: false
  t.integer :source_count, null: false   # records summarized
  
  t.index [:dimension, :dimension_value], unique: true
end

# Layer 2: Semantic clusters
create_table :knowledge_clusters do |t|
  t.string :name, null: false
  t.text :description, null: false
  t.text :summary, null: false           # AI-generated
  t.jsonb :stats, null: false
  t.vector :embedding, limit: 1536       # pgvector
  t.jsonb :representative_ids, default: [] # sample record IDs
  t.datetime :generated_at, null: false
  
  t.index :embedding, using: :hnsw
end

# Cluster membership (for drill-down)
create_table :cluster_memberships do |t|
  t.references :knowledge_cluster, null: false
  t.string :record_type, null: false     # 'Location', 'Tour'
  t.bigint :record_id, null: false
  t.float :similarity_score
  
  t.index [:record_type, :record_id]
  t.index [:knowledge_cluster_id, :similarity_score]
end
```

---

## Background Jobs Architecture

### Job Hierarchy

```
DataStatisticsJob (runs: every 5 min)
└── Updates Layer 0 live statistics

SummaryGenerationJob (runs: hourly)
├── RegionSummaryJob (per region)
├── CategorySummaryJob (per location_type)  
└── TemporalSummaryJob (daily/weekly rollups)

ClusterGenerationJob (runs: daily)
├── ClusterDiscoveryJob (find natural groupings)
├── ClusterSummaryJob (generate summaries)
└── ClusterMembershipJob (assign records)

DataQualityJob (runs: daily)
└── Scores records, flags issues
```

### Summary Generation Strategy

For millions of records, we can't pass everything to the LLM. Strategy:

1. **Stratified sampling**: Sample across distributions (type, date, quality)
2. **Statistical aggregation**: Pre-compute metrics, pass those to LLM
3. **Incremental updates**: Only re-summarize changed segments
4. **Human-in-the-loop**: Flag low-confidence summaries for review

```ruby
class RegionSummaryJob < ApplicationJob
  def perform(region_name)
    locations = Location.where(region: region_name)
    
    # Pre-compute statistics
    stats = {
      total_count: locations.count,
      by_type: locations.group(:location_type).count,
      avg_quality_score: locations.average(:data_quality_score),
      missing_images: locations.where(images_count: 0).count,
      missing_description: locations.where(description: [nil, '']).count,
      created_last_30d: locations.where('created_at > ?', 30.days.ago).count,
      # ... more metrics
    }
    
    # Stratified sample for qualitative analysis
    sample = stratified_sample(locations, n: 200)
    
    # Generate summary via LLM
    summary = RubyLLM.chat(
      model: "claude-sonnet-4-5-20250929",
      messages: [{
        role: "user", 
        content: build_summary_prompt(region_name, stats, sample)
      }]
    )
    
    KnowledgeSummary.upsert({
      dimension: 'region',
      dimension_value: region_name,
      summary: summary.content,
      stats: stats,
      issues: extract_issues(summary.content),
      patterns: extract_patterns(summary.content),
      generated_at: Time.current,
      source_count: locations.count
    }, unique_by: [:dimension, :dimension_value])
  end
  
  private
  
  def stratified_sample(scope, n:)
    # Sample proportionally across types, quality scores, dates
    # Implementation depends on data distribution
  end
  
  def build_summary_prompt(region, stats, sample)
    <<~PROMPT
      Analyze the #{region} region of the Usput.ba tourism database.
      
      ## Statistics
      #{stats.to_yaml}
      
      ## Sample Records (#{sample.size} of #{stats[:total_count]})
      #{sample.map { |l| format_location(l) }.join("\n\n")}
      
      ## Task
      Generate a comprehensive summary including:
      1. Overall characterization of this region's tourism offerings
      2. Data quality issues and gaps
      3. Notable patterns or anomalies  
      4. Underrepresented categories or opportunities
      5. Comparison to expected coverage for a region of this type
      
      Format as structured prose. Be specific and actionable.
    PROMPT
  end
end
```

---

## Admin CLI Interface

### Basic Structure

```ruby
# lib/usput/admin_cli.rb
module Usput
  class AdminCLI
    def initialize
      @llm = RubyLLM.client(model: "claude-sonnet-4-5-20250929")
      @parser = DSLParser.new
      @executor = QueryExecutor.new
      @context = build_base_context
    end
    
    def chat(user_input)
      response = @llm.chat(
        system: system_prompt,
        messages: @history + [{ role: "user", content: user_input }],
        tools: available_tools
      )
      
      # Handle tool calls (DSL execution)
      while response.tool_calls.any?
        results = execute_tool_calls(response.tool_calls)
        response = @llm.chat(
          messages: @history + [
            { role: "assistant", content: response },
            { role: "user", content: format_tool_results(results) }
          ],
          tools: available_tools
        )
      end
      
      @history << { role: "user", content: user_input }
      @history << { role: "assistant", content: response.content }
      
      response.content
    end
    
    private
    
    def system_prompt
      <<~PROMPT
        You are an AI assistant with deep knowledge of the Usput.ba tourism database.
        
        ## Your Knowledge
        #{@context}
        
        ## Query Interface
        You can query the database using the Usput DSL. Generate DSL queries to answer questions.
        
        Available DSL commands:
        #{DSL_DOCUMENTATION}
        
        ## Guidelines
        - Start with Layer 0/1 (summaries) before drilling into raw data
        - Use `| explain` to check query cost before executing expensive queries
        - Prefer aggregations over fetching individual records
        - When exploring, use `| sample` to get representative examples
        - Always cite specific data when making claims
      PROMPT
    end
    
    def available_tools
      [
        {
          name: "execute_dsl",
          description: "Execute a Usput DSL query against the database",
          parameters: {
            type: "object",
            properties: {
              query: { type: "string", description: "The DSL query to execute" }
            },
            required: ["query"]
          }
        }
      ]
    end
    
    def execute_tool_calls(tool_calls)
      tool_calls.map do |call|
        case call.name
        when "execute_dsl"
          execute_dsl(call.arguments[:query])
        end
      end
    end
    
    def execute_dsl(query)
      parsed = @parser.parse(query)
      return { error: parsed.errors } if parsed.errors.any?
      
      @executor.execute(parsed)
    rescue QueryExecutor::TooExpensiveError => e
      { error: "Query too expensive: #{e.message}. Add filters or use sampling." }
    rescue QueryExecutor::TimeoutError
      { error: "Query timed out. Try a more specific query." }
    end
    
    def build_base_context
      # Load Layer 0 into context
      stats = DataStatistic.pluck(:key, :value).to_h
      schema = generate_schema_description
      
      <<~CONTEXT
        ## Database Schema
        #{schema}
        
        ## Current Statistics (as of #{stats['computed_at']})
        #{format_stats(stats)}
        
        ## Available Summaries
        #{KnowledgeSummary.pluck(:dimension, :dimension_value).group_by(&:first).transform_values { |v| v.map(&:last) }.to_yaml}
        
        ## Available Clusters
        #{KnowledgeCluster.pluck(:name, :stats).map { |n, s| "- #{n}: #{s['count']} records" }.join("\n")}
      CONTEXT
    end
  end
end
```

### CLI Runner

```ruby
# bin/usput-admin
#!/usr/bin/env ruby
require_relative '../config/environment'

cli = Usput::AdminCLI.new

puts "Usput.ba Admin CLI"
puts "Type 'exit' to quit, 'reset' to clear history"
puts "-" * 50

loop do
  print "\n> "
  input = gets&.chomp
  
  break if input.nil? || input == 'exit'
  next cli.reset_history if input == 'reset'
  next if input.empty?
  
  response = cli.chat(input)
  puts "\n#{response}"
end
```

---

## DSL Parser Implementation

```ruby
# lib/usput/dsl/parser.rb
module Usput
  module DSL
    class Parser
      LAYER_0_COMMANDS = %w[schema]
      LAYER_1_TABLES = %w[summaries]
      LAYER_2_TABLES = %w[clusters]
      LAYER_3_TABLES = %w[locations tours events users]
      
      OPERATIONS = %w[
        show describe stats health issues trends compare
        where select sample aggregate sort limit explain
        semantic list top
      ]
      
      def parse(query)
        tokens = tokenize(query)
        build_ast(tokens)
      rescue ParseError => e
        ParseResult.new(nil, [e.message])
      end
      
      private
      
      def tokenize(query)
        # Split on pipes, preserving quoted strings and braces
        # Returns array of tokens
      end
      
      def build_ast(tokens)
        # Build abstract syntax tree
        # Validate table names, operations, filter syntax
        # Return ParseResult with AST or errors
      end
    end
    
    class ParseResult
      attr_reader :ast, :errors
      
      def initialize(ast, errors = [])
        @ast = ast
        @errors = errors
      end
      
      def valid?
        errors.empty?
      end
    end
  end
end
```

---

## Query Executor Implementation

```ruby
# lib/usput/dsl/executor.rb
module Usput
  module DSL
    class QueryExecutor
      MAX_ROWS = 10_000
      TIMEOUT_SECONDS = 30
      
      def execute(parse_result)
        return { error: parse_result.errors } unless parse_result.valid?
        
        ast = parse_result.ast
        
        case ast.layer
        when 0 then execute_schema(ast)
        when 1 then execute_summary(ast)
        when 2 then execute_cluster(ast)
        when 3 then execute_records(ast)
        end
      end
      
      private
      
      def execute_schema(ast)
        case ast.operation
        when 'describe'
          describe_table(ast.table)
        when 'stats'
          DataStatistic.pluck(:key, :value).to_h
        when 'health'
          compute_health_metrics
        end
      end
      
      def execute_summary(ast)
        scope = KnowledgeSummary.all
        scope = apply_filters(scope, ast.filters)
        
        case ast.operation
        when 'show' then scope.first&.attributes
        when 'issues' then scope.flat_map { |s| s.issues }
        when 'trends' then compute_trends(scope)
        when 'compare' then compare_summaries(scope, ast.compare_target)
        else scope.limit(10).map(&:attributes)
        end
      end
      
      def execute_cluster(ast)
        if ast.operation == 'semantic'
          # Vector similarity search
          embedding = generate_embedding(ast.semantic_query)
          KnowledgeCluster
            .nearest_neighbors(:embedding, embedding, distance: 'cosine')
            .limit(ast.top_n || 5)
            .map(&:attributes)
        else
          scope = KnowledgeCluster.all
          scope = apply_filters(scope, ast.filters)
          scope.limit(10).map(&:attributes)
        end
      end
      
      def execute_records(ast)
        model = ast.table.classify.constantize
        scope = model.all
        
        # Apply filters (must use indexes)
        scope = apply_filters(scope, ast.filters)
        
        # Check query cost
        if ast.operation != 'explain'
          cost = estimate_cost(scope)
          raise TooExpensiveError, "Estimated #{cost} rows" if cost > MAX_ROWS
        end
        
        # Apply operations
        ast.operations.each do |op|
          scope = apply_operation(scope, op)
        end
        
        # Execute with timeout
        Timeout.timeout(TIMEOUT_SECONDS) do
          if ast.operation == 'explain'
            { explain: scope.explain, estimated_rows: estimate_cost(scope) }
          else
            scope.to_a.map(&:attributes)
          end
        end
      end
      
      def apply_operation(scope, operation)
        case operation.type
        when 'where'
          scope.where(operation.condition)
        when 'select'
          scope.select(operation.fields)
        when 'sample'
          # PostgreSQL TABLESAMPLE for true random sampling
          scope.from("#{scope.table_name} TABLESAMPLE SYSTEM(#{calculate_sample_percent(scope, operation.n)})")
        when 'aggregate'
          scope.group(operation.group_by).send(operation.function)
        when 'sort'
          scope.order(operation.field => operation.direction)
        when 'limit'
          scope.limit(operation.n)
        else
          scope
        end
      end
      
      def estimate_cost(scope)
        # Use EXPLAIN to estimate row count
        explain = scope.explain
        # Parse row estimate from explain output
        # This is database-specific
      end
      
      class TooExpensiveError < StandardError; end
      class TimeoutError < StandardError; end
    end
  end
end
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Set up knowledge layer tables and migrations
- [ ] Implement DataStatisticsJob for Layer 0
- [ ] Build basic DSL parser (filters, simple operations)
- [ ] Create minimal CLI with direct DSL execution (no LLM yet)

### Phase 2: Knowledge Generation (Week 3-4)
- [ ] Implement RegionSummaryJob with LLM integration
- [ ] Implement CategorySummaryJob
- [ ] Build stratified sampling utilities
- [ ] Test summary quality, iterate on prompts

### Phase 3: Semantic Layer (Week 5-6)
- [ ] Implement ClusterDiscoveryJob (clustering algorithm TBD)
- [ ] Add pgvector embeddings for clusters
- [ ] Implement semantic search in DSL
- [ ] Build cluster membership assignment

### Phase 4: LLM Integration (Week 7-8)
- [ ] Integrate RubyLLM into CLI
- [ ] Implement tool-calling loop
- [ ] Build system prompt with Layer 0 context
- [ ] Test end-to-end query flows

### Phase 5: Production Hardening (Week 9-10)
- [ ] Add query cost estimation and limits
- [ ] Implement caching for expensive queries
- [ ] Add audit logging
- [ ] Performance tuning for million-record scale
- [ ] Documentation and runbooks

---

## Open Questions

1. **Clustering algorithm**: K-means on embeddings? Topic modeling? Manual curation?
2. **Summary update strategy**: Full regeneration vs incremental? Staleness threshold?
3. **Embedding model**: OpenAI, Anthropic, local model?
4. **Analytics backend**: Stay with PostgreSQL or add ClickHouse for events?
5. **Multi-tenancy**: Is this admin-only or will users get personalized knowledge layers?
6. **Bosnian/Croatian language**: Embeddings and summaries in which language(s)?

---

## Key Constraints

- **Self-hosted preference**: Avoid per-API-call costs where possible
- **PostgreSQL primary**: Prefer PostgreSQL extensions (pgvector, PostGIS) over external services
- **RubyLLM**: Use RubyLLM gem for all LLM interactions
- **Mobile-friendly**: CLI should work via GitHub + Claude mobile workflow
- **Cost-conscious**: Batch LLM calls, cache aggressively, use smaller models where sufficient

---

## Reference Links

- [RubyLLM Documentation](https://github.com/crmne/ruby_llm)
- [pgvector](https://github.com/pgvector/pgvector)
- [PostgreSQL TABLESAMPLE](https://www.postgresql.org/docs/current/sql-select.html#SQL-FROM)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/query/)
