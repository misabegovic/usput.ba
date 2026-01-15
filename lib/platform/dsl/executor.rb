# frozen_string_literal: true

module Platform
  module DSL
    # Executor - Izvršava DSL AST
    #
    # Mapira DSL queries na ActiveRecord operacije.
    #
    # Primjer:
    #   ast = { type: :table_query, table: "locations", filters: { city: "Mostar" }, operations: [{ name: :count }] }
    #   result = Executor.execute(ast)
    #   # => 47
    #
    class Executor
      # Mapiranje DSL table names na Rails modele
      TABLE_MAP = {
        "locations" => "Location",
        "experiences" => "Experience",
        "plans" => "Plan",
        "audio_tours" => "AudioTour",
        "users" => "User",
        "reviews" => "Review",
        "translations" => "Translation",
        "browse" => "Browse",
        "curator_applications" => "CuratorApplication",
        "content_changes" => "ContentChange"
      }.freeze

      class << self
        def execute(ast)
          case ast[:type]
          when :schema_query
            execute_schema_query(ast)
          when :table_query
            execute_table_query(ast)
          when :summaries_query
            execute_summaries_query(ast)
          when :clusters_query
            execute_clusters_query(ast)
          else
            raise ExecutionError, "Nepoznat tip query-ja: #{ast[:type]}"
          end
        end

        private

        # Schema queries
        def execute_schema_query(ast)
          operation = ast[:operations].first
          case operation[:name]
          when :stats
            build_stats
          when :describe
            table = operation[:args]&.first
            describe_table(table)
          when :health
            build_health
          else
            raise ExecutionError, "Nepoznata schema operacija: #{operation[:name]}"
          end
        end

        def build_stats
          # Koristi cached statistike ako su dostupne
          cached = PlatformStatistic.find_by(key: "layer_zero")
          if cached&.fresh?(5.minutes)
            return format_cached_stats(cached.value)
          end

          # Fallback na direktne upite
          build_stats_directly
        end

        def format_cached_stats(data)
          {
            content: data["stats"] || data[:stats] || {},
            by_city: data["by_city"] || data[:by_city] || {},
            coverage: data["coverage"] || data[:coverage] || {},
            users: {
              total: (data.dig("stats", "users") || data.dig(:stats, :users)) || 0,
              curators: (data.dig("stats", "curators") || data.dig(:stats, :curators)) || 0
            },
            last_updated: data["computed_at"] || data[:computed_at],
            source: :cached
          }
        end

        def build_stats_directly
          {
            content: {
              locations: Location.count,
              experiences: Experience.count,
              plans: Plan.count,
              audio_tours: AudioTour.count,
              reviews: Review.count
            },
            by_city: Location.group(:city).count.sort_by { |_, v| -v }.first(10).to_h,
            coverage: {
              cities_with_content: Location.distinct.pluck(:city).compact.size,
              locations_with_audio: Location.with_audio.count,
              locations_with_description: Location.where.not(description: [nil, ""]).count
            },
            users: {
              total: User.count,
              curators: User.curator.count,
              admins: User.admin.count
            },
            last_updated: [
              Location.maximum(:updated_at),
              Experience.maximum(:updated_at)
            ].compact.max,
            source: :live
          }
        end

        def describe_table(table_name)
          model = resolve_model(table_name.to_s)
          {
            table: table_name,
            columns: model.column_names,
            count: model.count,
            associations: model.reflect_on_all_associations.map do |assoc|
              { name: assoc.name, type: assoc.macro }
            end
          }
        end

        def build_health
          {
            database: check_database_health,
            api_keys: check_api_keys,
            queues: check_queue_health,
            storage: check_storage_health
          }
        end

        def check_database_health
          ActiveRecord::Base.connection.execute("SELECT 1")
          { status: "ok", adapter: ActiveRecord::Base.connection.adapter_name }
        rescue => e
          { status: "error", message: e.message }
        end

        def check_api_keys
          {
            anthropic: ENV["ANTHROPIC_API_KEY"].present? ? "configured" : "missing",
            geoapify: ENV["GEOAPIFY_API_KEY"].present? ? "configured" : "missing",
            elevenlabs: ENV["ELEVENLABS_API_KEY"].present? ? "configured" : "missing"
          }
        end

        def check_queue_health
          {
            pending: SolidQueue::Job.where(finished_at: nil).count,
            failed: SolidQueue::Job.where.not(finished_at: nil).where("finished_at < created_at + interval '1 second'").count
          }
        rescue => e
          { status: "error", message: e.message }
        end

        def check_storage_health
          {
            service: ActiveStorage::Blob.service.class.name
          }
        rescue => e
          { status: "error", message: e.message }
        end

        # Table queries
        def execute_table_query(ast)
          model = resolve_model(ast[:table])
          scope = apply_filters(model, ast[:filters])
          apply_operations(scope, ast[:operations])
        end

        def resolve_model(table_name)
          class_name = TABLE_MAP[table_name.to_s.downcase]
          raise ExecutionError, "Nepoznata tabela: #{table_name}" unless class_name

          class_name.constantize
        rescue NameError
          raise ExecutionError, "Model #{class_name} nije pronađen"
        end

        def apply_filters(model, filters)
          return model.all if filters.nil? || filters.empty?

          scope = model.all

          filters.each do |key, value|
            scope = apply_filter(scope, key, value)
          end

          scope
        end

        def apply_filter(scope, key, value)
          column = key.to_s

          # Special filters
          case column
          when "has_audio"
            return value ? scope.with_audio : scope
          when "missing_description"
            return scope.where(description: [nil, ""]) if value
            return scope.where.not(description: [nil, ""])
          when "ai_generated"
            return scope.where(ai_generated: value)
          end

          # Check if column exists
          unless scope.model.column_names.include?(column)
            # Try as scope name
            if scope.model.respond_to?(:"by_#{column}")
              return scope.send(:"by_#{column}", value)
            end
            raise ExecutionError, "Nepoznata kolona ili filter: #{column}"
          end

          # Apply based on value type
          case value
          when Array
            scope.where(column => value)
          when Range
            scope.where(column => value)
          when Hash
            # Nested conditions (for JSONB)
            scope.where("#{column} @> ?", value.to_json)
          else
            scope.where(column => value)
          end
        end

        def apply_operations(scope, operations)
          return scope.limit(100).to_a if operations.nil? || operations.empty?

          operations.each do |op|
            scope = apply_operation(scope, op)
          end

          scope
        end

        def apply_operation(scope, operation)
          case operation[:name]
          when :count
            return scope.count
          when :sample
            limit = operation[:args]&.first || 10
            return scope.order("RANDOM()").limit(limit).to_a.map { |r| format_record(r) }
          when :limit
            limit = operation[:args]&.first || 10
            return scope.limit(limit).to_a.map { |r| format_record(r) }
          when :aggregate
            return apply_aggregate(scope, operation)
          when :where
            condition = operation[:args]&.first
            return apply_where_condition(scope, condition)
          when :select
            fields = operation[:args] || []
            return scope.select(*fields)
          when :sort, :order
            field = operation[:args]&.first || :id
            direction = operation[:args]&.[](1) || :asc
            return scope.order(field => direction)
          when :show
            return scope.limit(100).to_a.map { |r| format_record(r) }
          else
            raise ExecutionError, "Nepoznata operacija: #{operation[:name]}"
          end
        end

        def apply_aggregate(scope, operation)
          func = operation[:args]&.first || :count
          group_by = operation[:group_by]

          case func.to_s
          when "count", "count()"
            if group_by
              scope.group(group_by).count
            else
              scope.count
            end
          when "sum"
            field = operation[:args]&.[](1)
            if group_by
              scope.group(group_by).sum(field)
            else
              scope.sum(field)
            end
          when "avg"
            field = operation[:args]&.[](1)
            if group_by
              scope.group(group_by).average(field)
            else
              scope.average(field)
            end
          else
            raise ExecutionError, "Nepoznata agregacijska funkcija: #{func}"
          end
        end

        def apply_where_condition(scope, condition)
          # Parse simple conditions like "rating > 4"
          if condition =~ /(\w+)\s*(>|<|>=|<=|=|!=)\s*(\d+(?:\.\d+)?)/
            field, op, value = $1, $2, $3.to_f
            case op
            when ">"  then scope.where("#{field} > ?", value)
            when "<"  then scope.where("#{field} < ?", value)
            when ">=" then scope.where("#{field} >= ?", value)
            when "<=" then scope.where("#{field} <= ?", value)
            when "="  then scope.where(field => value)
            when "!=" then scope.where.not(field => value)
            end
          else
            scope
          end
        end

        def format_record(record)
          case record
          when Location
            {
              id: record.id,
              name: record.name,
              city: record.city,
              type: record.category_key,
              has_audio: record.has_audio_tours?,
              rating: record.average_rating
            }
          when Experience
            {
              id: record.id,
              title: record.title,
              duration: record.estimated_duration,
              locations_count: record.locations.count,
              rating: record.average_rating
            }
          when Plan
            {
              id: record.id,
              title: record.title,
              experiences_count: record.experiences.count
            }
          when User
            {
              id: record.id,
              username: record.username,
              user_type: record.user_type
            }
          else
            record.attributes.slice("id", "name", "title", "created_at")
          end
        end

        # Summaries queries (Knowledge Layer 1)
        def execute_summaries_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :list
            list_summaries(filters)
          when :show
            show_summary(filters)
          when :issues
            show_issues(filters)
          when :refresh
            refresh_summaries(filters)
          else
            raise ExecutionError, "Nepoznata summaries operacija: #{operation&.dig(:name)}"
          end
        end

        def list_summaries(filters)
          dimension = filters[:dimension] || filters[:city] && "city" || filters[:category] && "category"

          if dimension
            KnowledgeSummary.for_dimension(dimension).map(&:to_short_format)
          else
            {
              cities: KnowledgeSummary.cities,
              categories: KnowledgeSummary.categories,
              total: KnowledgeSummary.count,
              with_issues: KnowledgeSummary.with_issues.count
            }
          end
        end

        def show_summary(filters)
          dimension, value = extract_dimension_and_value(filters)

          unless dimension && value
            raise ExecutionError, "Potreban filter: city, category, ili region"
          end

          summary = Knowledge::LayerOne.get_summary(dimension, value)

          if summary
            {
              dimension: summary.dimension,
              value: summary.dimension_value,
              summary: summary.summary,
              stats: summary.stats,
              issues: summary.issues,
              patterns: summary.patterns,
              source_count: summary.source_count,
              generated_at: summary.generated_at&.iso8601
            }
          else
            raise ExecutionError, "Summary za #{dimension}=#{value} ne postoji"
          end
        end

        def show_issues(filters)
          dimension, value = extract_dimension_and_value(filters)

          if dimension && value
            # Issues za specifičan summary
            summary = KnowledgeSummary.for_dimension_value(dimension, value)
            return [] unless summary

            summary.issues || []
          else
            # Sve issues
            KnowledgeSummary.with_issues.map do |s|
              {
                dimension: s.dimension,
                value: s.dimension_value,
                issues: s.issues,
                issues_count: s.issues_count
              }
            end
          end
        end

        def refresh_summaries(filters)
          dimension, value = extract_dimension_and_value(filters)

          if dimension && value
            summary = Knowledge::LayerOne.generate_summary(dimension, value)
            "Refreshed: #{summary&.to_short_format || 'failed'}"
          elsif dimension
            Knowledge::LayerOne.refresh_dimension(dimension)
            "Refreshed all #{dimension} summaries"
          else
            Platform::SummaryGenerationJob.perform_later
            "Queued full summary refresh"
          end
        end

        def extract_dimension_and_value(filters)
          if filters[:city]
            ["city", filters[:city]]
          elsif filters[:category]
            ["category", filters[:category]]
          elsif filters[:region]
            ["region", filters[:region]]
          elsif filters[:dimension] && filters[:value]
            [filters[:dimension], filters[:value]]
          else
            [nil, nil]
          end
        end

        # Clusters queries (Knowledge Layer 2)
        def execute_clusters_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :list
            list_clusters(filters)
          when :show
            show_cluster(filters)
          when :semantic
            semantic_search_clusters(operation[:args]&.first)
          when :members
            show_cluster_members(filters)
          when :refresh
            refresh_clusters(filters)
          else
            raise ExecutionError, "Nepoznata clusters operacija: #{operation&.dig(:name)}"
          end
        end

        def list_clusters(filters)
          clusters = KnowledgeCluster.by_member_count

          if filters[:min_members]
            clusters = clusters.where("member_count >= ?", filters[:min_members])
          end

          {
            clusters: clusters.map do |c|
              {
                slug: c.slug,
                name: c.name,
                member_count: c.member_count,
                summary: c.summary&.truncate(100)
              }
            end,
            total: clusters.count,
            semantic_search_available: KnowledgeCluster.semantic_search_available?
          }
        end

        def show_cluster(filters)
          slug = filters[:id] || filters[:slug]
          raise ExecutionError, "Potreban filter: id ili slug" unless slug

          cluster = Knowledge::LayerTwo.get_cluster(slug)
          raise ExecutionError, "Cluster '#{slug}' ne postoji" unless cluster

          {
            slug: cluster.slug,
            name: cluster.name,
            summary: cluster.summary,
            member_count: cluster.member_count,
            stats: cluster.stats,
            representative_ids: cluster.representative_ids,
            created_at: cluster.created_at.iso8601
          }
        end

        def semantic_search_clusters(query)
          raise ExecutionError, "Semantic search zahtijeva upit" unless query

          unless KnowledgeCluster.semantic_search_available?
            return {
              error: "Semantic search nije dostupan (pgvector nije instaliran)",
              fallback: list_clusters({})
            }
          end

          results = Knowledge::LayerTwo.semantic_search(query, limit: 5)

          {
            query: query,
            results: results.map do |c|
              {
                slug: c.slug,
                name: c.name,
                member_count: c.member_count,
                summary: c.summary&.truncate(100)
              }
            end
          }
        end

        def show_cluster_members(filters)
          slug = filters[:id] || filters[:slug]
          raise ExecutionError, "Potreban filter: id ili slug" unless slug

          cluster = KnowledgeCluster.find_by(slug: slug)
          raise ExecutionError, "Cluster '#{slug}' ne postoji" unless cluster

          limit = filters[:limit] || 10

          memberships = cluster.cluster_memberships
                               .by_similarity
                               .limit(limit)
                               .includes(:record)

          {
            cluster: cluster.name,
            members: memberships.map do |m|
              {
                type: m.record_type,
                id: m.record_id,
                name: m.record.respond_to?(:name) ? m.record.name : m.record.try(:title),
                similarity: m.similarity_score&.round(3)
              }
            end
          }
        end

        def refresh_clusters(filters)
          if filters[:regenerate]
            Platform::ClusterGenerationJob.perform_later(regenerate: true)
            "Queued full cluster regeneration"
          else
            Platform::ClusterGenerationJob.perform_later
            "Queued cluster membership refresh"
          end
        end
      end
    end
  end
end
