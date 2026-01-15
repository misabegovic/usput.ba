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
      # Includes both singular and plural forms for mutations
      TABLE_MAP = {
        "locations" => "Location",
        "location" => "Location",
        "experiences" => "Experience",
        "experience" => "Experience",
        "plans" => "Plan",
        "plan" => "Plan",
        "audio_tours" => "AudioTour",
        "audio_tour" => "AudioTour",
        "users" => "User",
        "user" => "User",
        "reviews" => "Review",
        "review" => "Review",
        "translations" => "Translation",
        "translation" => "Translation",
        "browse" => "Browse",
        "curator_applications" => "CuratorApplication",
        "curator_application" => "CuratorApplication",
        "content_changes" => "ContentChange",
        "content_change" => "ContentChange"
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
          when :external_query
            execute_external_query(ast)
          when :mutation
            execute_mutation(ast)
          when :generation
            execute_generation(ast)
          when :audio
            execute_audio(ast)
          when :proposals_query
            execute_proposals_query(ast)
          when :applications_query
            execute_applications_query(ast)
          when :approval
            execute_approval(ast)
          when :curators_query
            execute_curators_query(ast)
          when :curator_management
            execute_curator_management(ast)
          when :code_query
            execute_code_query(ast)
          when :logs_query
            execute_logs_query(ast)
          when :infrastructure_query
            execute_infrastructure_query(ast)
          when :prompts_query
            execute_prompts_query(ast)
          when :improvement
            execute_improvement(ast)
          when :prompt_action
            execute_prompt_action(ast)
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

        # External queries (Geoapify, geocoding, etc.)
        def execute_external_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :search_pois
            search_pois(filters, operation[:args])
          when :geocode
            geocode_address(filters)
          when :reverse_geocode
            reverse_geocode_coords(filters)
          when :validate_location, :validate
            validate_location(filters)
          when :check_duplicate, :dedupe
            check_duplicate(filters)
          else
            raise ExecutionError, "Nepoznata external operacija: #{operation&.dig(:name)}"
          end
        end

        # Search for POIs using Geoapify
        def search_pois(filters, args)
          city = filters[:city]
          raise ExecutionError, "search_pois zahtijeva filter: city" unless city

          # Get coordinates for the city
          coords = get_city_coordinates(city)
          raise ExecutionError, "Nije moguće pronaći koordinate za grad: #{city}" unless coords

          radius = filters[:radius] || 15_000 # default 15km
          max_results = filters[:limit] || 50
          categories = filters[:categories] || args&.first

          # Use rate limiting
          results = Ai::RateLimiter.with_delay(delay: 0.25) do
            geoapify_service.search_nearby(
              lat: coords[:lat],
              lng: coords[:lng],
              radius: radius,
              types: Array(categories).map(&:to_s),
              max_results: max_results
            )
          end

          # Filter to only BiH locations
          bih_results = results.select do |place|
            Geo::BihBoundaryValidator.inside_bih?(place[:lat], place[:lng])
          end

          {
            city: city,
            center: coords,
            radius: radius,
            total_found: results.size,
            in_bih: bih_results.size,
            filtered_out: results.size - bih_results.size,
            results: bih_results.map { |p| format_poi_result(p) }
          }
        end

        # Geocode an address to coordinates
        def geocode_address(filters)
          address = filters[:address] || filters[:query]
          raise ExecutionError, "geocode zahtijeva filter: address" unless address

          results = Ai::RateLimiter.with_delay(delay: 0.25) do
            geoapify_service.text_search(query: address)
          end

          return { address: address, found: false, results: [] } if results.empty?

          # Filter and format results
          formatted = results.map do |r|
            in_bih = Geo::BihBoundaryValidator.inside_bih?(r[:lat], r[:lng])
            {
              name: r[:name],
              address: r[:address],
              lat: r[:lat],
              lng: r[:lng],
              in_bih: in_bih,
              type: r[:primary_type]
            }
          end

          {
            query: address,
            found: true,
            count: formatted.size,
            in_bih_count: formatted.count { |r| r[:in_bih] },
            results: formatted
          }
        end

        # Reverse geocode coordinates to address
        def reverse_geocode_coords(filters)
          lat = filters[:lat]
          lng = filters[:lng]
          raise ExecutionError, "reverse_geocode zahtijeva filtere: lat, lng" unless lat && lng

          result = Ai::RateLimiter.with_delay(delay: 0.25) do
            geoapify_service.reverse_geocode(lat: lat.to_f, lng: lng.to_f)
          end

          in_bih = Geo::BihBoundaryValidator.inside_bih?(lat, lng)

          {
            lat: lat.to_f,
            lng: lng.to_f,
            in_bih: in_bih,
            address: result[:formatted],
            city: result[:city] || result[:town] || result[:village],
            country: result[:country],
            country_code: result[:country_code]
          }
        end

        # Validate if location is in BiH
        def validate_location(filters)
          lat = filters[:lat]
          lng = filters[:lng]
          raise ExecutionError, "validate_location zahtijeva filtere: lat, lng" unless lat && lng

          lat_f = lat.to_f
          lng_f = lng.to_f
          in_bih = Geo::BihBoundaryValidator.inside_bih?(lat_f, lng_f)

          result = {
            lat: lat_f,
            lng: lng_f,
            in_bih: in_bih,
            valid: in_bih
          }

          unless in_bih
            result[:distance_to_border_km] = Geo::BihBoundaryValidator.distance_to_border(lat_f, lng_f).round(2)
            result[:message] = "Lokacija je van granica Bosne i Hercegovine"
          end

          result
        end

        # Check for duplicate locations
        def check_duplicate(filters)
          name = filters[:name]
          lat = filters[:lat]
          lng = filters[:lng]

          raise ExecutionError, "check_duplicate zahtijeva filter: name ili (lat, lng)" unless name || (lat && lng)

          duplicates = []

          # Check by name similarity
          if name
            similar = Location.where("LOWER(name) LIKE ?", "%#{name.downcase}%").limit(10)
            duplicates += similar.map do |loc|
              {
                id: loc.id,
                name: loc.name,
                city: loc.city,
                match_type: :name,
                lat: loc.lat,
                lng: loc.lng
              }
            end
          end

          # Check by proximity (within 100m) using haversine distance
          # Note: PostGIS would be faster for large datasets but requires extension
          if lat && lng
            target_lat = lat.to_f
            target_lng = lng.to_f

            nearby = Location.all.select do |loc|
              next false unless loc.lat && loc.lng
              distance = haversine_distance(target_lat, target_lng, loc.lat, loc.lng)
              distance < 0.1 # 100m = 0.1km
            end.first(10)

            duplicates += nearby.map do |loc|
              {
                id: loc.id,
                name: loc.name,
                city: loc.city,
                match_type: :proximity,
                lat: loc.lat,
                lng: loc.lng,
                distance_m: (haversine_distance(lat.to_f, lng.to_f, loc.lat, loc.lng) * 1000).round
              }
            end
          end

          {
            query: { name: name, lat: lat, lng: lng }.compact,
            has_duplicates: duplicates.any?,
            count: duplicates.uniq { |d| d[:id] }.size,
            duplicates: duplicates.uniq { |d| d[:id] }
          }
        end

        # Helper methods for external queries

        def geoapify_service
          @geoapify_service ||= GeoapifyService.new
        end

        def get_city_coordinates(city)
          # Try to find from existing locations first
          location = Location.where(city: city).first
          return { lat: location.lat, lng: location.lng } if location&.lat && location&.lng

          # Fallback to geocoding
          results = geoapify_service.text_search(query: "#{city}, Bosnia and Herzegovina")
          return nil if results.empty?

          bih_result = results.find { |r| Geo::BihBoundaryValidator.inside_bih?(r[:lat], r[:lng]) }
          return nil unless bih_result

          { lat: bih_result[:lat], lng: bih_result[:lng] }
        end

        def format_poi_result(place)
          {
            place_id: place[:place_id],
            name: place[:name],
            address: place[:address],
            lat: place[:lat],
            lng: place[:lng],
            type: place[:primary_type],
            types: place[:types],
            rating: place[:rating],
            website: place[:website]
          }
        end

        def haversine_distance(lat1, lng1, lat2, lng2)
          r = 6371 # Earth's radius in kilometers
          dlat = to_radians(lat2 - lat1)
          dlng = to_radians(lng2 - lng1)
          a = Math.sin(dlat / 2)**2 +
              Math.cos(to_radians(lat1)) * Math.cos(to_radians(lat2)) *
              Math.sin(dlng / 2)**2
          c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
          r * c
        end

        def to_radians(degrees)
          degrees * Math::PI / 180
        end

        # Mutation queries (create, update, delete)
        def execute_mutation(ast)
          action = ast[:action]
          table = ast[:table]

          case action
          when :create
            execute_create(table, ast[:data])
          when :update
            execute_update(table, ast[:filters], ast[:data])
          when :delete
            execute_delete(table, ast[:filters] || ast[:data])
          else
            raise ExecutionError, "Nepoznata mutacija: #{action}"
          end
        end

        # Create a new record
        def execute_create(table, data)
          model = resolve_model(table)
          validate_mutation_data!(table, data, :create)

          # For locations, validate BiH boundary
          if is_location_table?(table) && data[:lat] && data[:lng]
            unless Geo::BihBoundaryValidator.inside_bih?(data[:lat], data[:lng])
              raise ExecutionError, "Lokacija mora biti unutar granica BiH (lat: #{data[:lat]}, lng: #{data[:lng]})"
            end
          end

          record = model.new(data)

          unless record.save
            raise ExecutionError, "Kreiranje nije uspjelo: #{record.errors.full_messages.join(', ')}"
          end

          # Log the action
          PlatformAuditLog.log_create(record, triggered_by: "platform_dsl")

          {
            success: true,
            action: :create,
            record_type: model.name,
            record_id: record.id,
            data: format_created_record(record)
          }
        end

        # Update an existing record
        def execute_update(table, filters, data)
          model = resolve_model(table)

          # Find the record
          record = find_record_for_mutation(model, filters)

          # For locations, validate BiH boundary if coordinates are being updated
          if is_location_table?(table) && (data[:lat] || data[:lng])
            new_lat = data[:lat] || record.lat
            new_lng = data[:lng] || record.lng
            unless Geo::BihBoundaryValidator.inside_bih?(new_lat, new_lng)
              raise ExecutionError, "Lokacija mora biti unutar granica BiH (lat: #{new_lat}, lng: #{new_lng})"
            end
          end

          # Capture changes before update
          old_values = data.keys.each_with_object({}) do |key, hash|
            hash[key] = record.send(key) if record.respond_to?(key)
          end

          unless record.update(data)
            raise ExecutionError, "Ažuriranje nije uspjelo: #{record.errors.full_messages.join(', ')}"
          end

          # Build changes hash
          changes = data.keys.each_with_object({}) do |key, hash|
            hash[key.to_s] = [old_values[key], record.send(key)]
          end

          # Log the action
          PlatformAuditLog.log_update(record, changes: changes, triggered_by: "platform_dsl")

          {
            success: true,
            action: :update,
            record_type: model.name,
            record_id: record.id,
            changes: changes
          }
        end

        # Delete a record (soft delete if supported)
        def execute_delete(table, filters)
          model = resolve_model(table)
          record = find_record_for_mutation(model, filters)

          # Log before delete
          PlatformAuditLog.log_delete(record, triggered_by: "platform_dsl")

          # Try soft delete first, fall back to hard delete
          if record.respond_to?(:discard)
            record.discard
          elsif record.respond_to?(:soft_delete)
            record.soft_delete
          else
            record.destroy
          end

          {
            success: true,
            action: :delete,
            record_type: model.name,
            record_id: record.id,
            message: "Record deleted"
          }
        end

        # Find a single record for mutation
        def find_record_for_mutation(model, filters)
          raise ExecutionError, "Potreban filter za identifikaciju zapisa (npr. id)" if filters.nil? || filters.empty?

          if filters[:id]
            record = model.find_by(id: filters[:id])
            raise ExecutionError, "#{model.name} sa id=#{filters[:id]} nije pronađen" unless record
            record
          else
            records = apply_filters(model, filters)
            raise ExecutionError, "Nijedan #{model.name} nije pronađen sa zadanim filterima" if records.empty?
            raise ExecutionError, "Pronađeno više zapisa (#{records.count}). Koristi id za preciznu selekciju." if records.count > 1
            records.first
          end
        end

        # Validate mutation data
        def validate_mutation_data!(table, data, action)
          if is_location_table?(table) && action == :create
            required = [:name, :city]
            missing = required.select { |f| data[f].blank? }
            raise ExecutionError, "Nedostaju obavezna polja: #{missing.join(', ')}" if missing.any?
          elsif is_experience_table?(table) && action == :create
            required = [:title]
            missing = required.select { |f| data[f].blank? }
            raise ExecutionError, "Nedostaju obavezna polja: #{missing.join(', ')}" if missing.any?
          end
        end

        # Table type helpers
        def is_location_table?(table)
          %w[location locations].include?(table.to_s.downcase)
        end

        def is_experience_table?(table)
          %w[experience experiences].include?(table.to_s.downcase)
        end

        # Format created record for response
        def format_created_record(record)
          case record
          when Location
            {
              id: record.id,
              name: record.name,
              city: record.city,
              lat: record.lat,
              lng: record.lng,
              description: record.description&.truncate(100)
            }
          when Experience
            {
              id: record.id,
              title: record.title,
              description: record.description&.truncate(100)
            }
          else
            record.attributes.slice("id", "name", "title", "created_at")
          end
        end

        # Generation queries
        def execute_generation(ast)
          case ast[:gen_type]
          when :description
            generate_description(ast)
          when :translations
            generate_translations(ast)
          when :experience
            generate_experience(ast)
          else
            raise ExecutionError, "Nepoznat tip generacije: #{ast[:gen_type]}"
          end
        end

        # Generate description for a record
        def generate_description(ast)
          model = resolve_model(ast[:table])
          record = find_record_for_mutation(model, ast[:filters])
          style = ast[:style] || "informative"

          unless record.respond_to?(:description)
            raise ExecutionError, "#{model.name} nema polje 'description'"
          end

          # Use RubyLLM for generation
          prompt = build_description_prompt(record, style)
          description = generate_with_llm(prompt)

          # Update the record
          old_description = record.description
          record.update!(description: description)

          # Log the change
          PlatformAuditLog.log_update(
            record,
            changes: { "description" => [old_description, description] },
            triggered_by: "platform_dsl_generation"
          )

          {
            success: true,
            action: :generate_description,
            record_type: model.name,
            record_id: record.id,
            style: style,
            description: description.truncate(200)
          }
        end

        # Generate translations for a record
        def generate_translations(ast)
          model = resolve_model(ast[:table])
          record = find_record_for_mutation(model, ast[:filters])
          locales = ast[:locales]

          unless record.respond_to?(:set_translation)
            raise ExecutionError, "#{model.name} ne podržava prijevode"
          end

          # Validate locales
          valid_locales = Translation::SUPPORTED_LOCALES
          invalid = locales - valid_locales
          raise ExecutionError, "Nepodržani jezici: #{invalid.join(', ')}" if invalid.any?

          # Get translatable fields
          translatable_fields = if record.class.respond_to?(:translatable_fields)
            record.class.translatable_fields
          else
            [:name, :description].select { |f| record.respond_to?(f) }
          end

          translations_created = []

          locales.each do |locale|
            translatable_fields.each do |field|
              source_text = record.send(field)
              next if source_text.blank?

              prompt = build_translation_prompt(source_text, locale, field)
              translated = generate_with_llm(prompt)

              record.set_translation(field, translated, locale)
              translations_created << { locale: locale, field: field }
            end
          end

          # Log
          PlatformAuditLog.create!(
            action: "update",
            record_type: model.name,
            record_id: record.id,
            change_data: { translations_added: translations_created },
            triggered_by: "platform_dsl_generation"
          )

          {
            success: true,
            action: :generate_translations,
            record_type: model.name,
            record_id: record.id,
            locales: locales,
            fields_translated: translatable_fields,
            translations_count: translations_created.size
          }
        end

        # Generate experience from locations
        def generate_experience(ast)
          location_ids = ast[:location_ids]
          raise ExecutionError, "Potrebne su bar 2 lokacije za generisanje iskustva" if location_ids.size < 2

          locations = Location.where(id: location_ids)
          missing = location_ids - locations.pluck(:id)
          raise ExecutionError, "Lokacije nisu pronađene: #{missing.join(', ')}" if missing.any?

          # Build experience prompt
          prompt = build_experience_prompt(locations)
          experience_data = generate_experience_with_llm(prompt, locations)

          # Create experience
          # estimated_duration is in minutes
          duration_minutes = (experience_data[:duration_hours] || locations.size) * 60
          experience = Experience.new(
            title: experience_data[:title],
            description: experience_data[:description],
            estimated_duration: duration_minutes,
            ai_generated: true
          )

          unless experience.save
            raise ExecutionError, "Kreiranje iskustva nije uspjelo: #{experience.errors.full_messages.join(', ')}"
          end

          # Link locations
          locations.each_with_index do |loc, idx|
            experience.experience_locations.create!(location: loc, position: idx + 1)
          end

          # Log
          PlatformAuditLog.log_create(experience, triggered_by: "platform_dsl_generation")

          {
            success: true,
            action: :generate_experience,
            experience_id: experience.id,
            title: experience.title,
            locations_count: locations.size,
            description: experience.description&.truncate(150)
          }
        end

        # LLM helpers
        def generate_with_llm(prompt)
          chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")
          response = chat.ask(prompt)
          response.content.strip
        rescue => e
          raise ExecutionError, "LLM greška: #{e.message}"
        end

        def build_description_prompt(record, style)
          context = case record
          when Location
            "lokacija u Bosni i Hercegovini: #{record.name}, grad: #{record.city}"
          when Experience
            "turističko iskustvo: #{record.title}"
          else
            "#{record.class.name}: #{record.try(:name) || record.try(:title)}"
          end

          style_instruction = case style.to_s.downcase
          when "vivid"
            "Koristi živopisan, emotivan jezik koji inspiriše posjetioce."
          when "formal"
            "Koristi formalan, informativan ton pogodan za vodiče."
          when "casual"
            "Koristi opušten, prijateljski ton."
          else
            "Koristi informativan, ali privlačan ton."
          end

          <<~PROMPT
            Napiši opis za #{context}.

            #{style_instruction}

            Pravila:
            - Piši na bosanskom jeziku (ijekavica)
            - Opis treba biti 2-3 paragrafa (150-250 riječi)
            - Uključi historijski kontekst ako je relevantan
            - Fokusiraj se na ono što čini ovo mjesto posebnim
            - Ne koristi klišeje poput "raj na zemlji" ili "must-see"

            Vrati SAMO tekst opisa, bez naslova ili dodatnih komentara.
          PROMPT
        end

        def build_translation_prompt(text, locale, field)
          locale_name = {
            "en" => "engleski",
            "de" => "njemački",
            "fr" => "francuski",
            "es" => "španski",
            "it" => "italijanski",
            "hr" => "hrvatski",
            "sr" => "srpski",
            "sl" => "slovenski",
            "cs" => "češki",
            "sk" => "slovački",
            "pl" => "poljski",
            "nl" => "holandski",
            "pt" => "portugalski",
            "tr" => "turski",
            "ar" => "arapski"
          }[locale.to_s] || locale

          <<~PROMPT
            Prevedi sljedeći tekst na #{locale_name} jezik.

            Originalni tekst (#{field}):
            #{text}

            Pravila:
            - Zadrži ton i stil originala
            - Zadrži nazive mjesta i lokacija nepromijenjene
            - Za hrvatski koristi ijekavicu
            - Za srpski koristi ćirilicu samo ako je to standardno

            Vrati SAMO preveden tekst, bez dodatnih komentara.
          PROMPT
        end

        def build_experience_prompt(locations)
          location_list = locations.map do |loc|
            "- #{loc.name} (#{loc.city}): #{loc.description&.truncate(100) || 'bez opisa'}"
          end.join("\n")

          <<~PROMPT
            Kreiraj turističko iskustvo koje povezuje sljedeće lokacije:

            #{location_list}

            Vrati JSON format:
            {
              "title": "Naslov iskustva (kreativan, privlačan)",
              "description": "Opis iskustva (2-3 paragrafa, opisuje put i šta posjetilac može očekivati)",
              "duration_hours": broj_sati_potrebnih
            }

            Pravila:
            - Piši na bosanskom jeziku (ijekavica)
            - Naslov treba biti kratak i pamtljiv
            - Opis treba logično povezati lokacije u priču
            - Procijeni realno trajanje bazirano na broju lokacija

            Vrati SAMO JSON, bez dodatnog teksta.
          PROMPT
        end

        def generate_experience_with_llm(prompt, locations)
          response = generate_with_llm(prompt)

          # Parse JSON response
          begin
            data = JSON.parse(response, symbolize_names: true)
            {
              title: data[:title] || "Iskustvo: #{locations.first.city}",
              description: data[:description] || "Iskustvo koje uključuje #{locations.size} lokacija.",
              duration_hours: data[:duration_hours] || locations.size
            }
          rescue JSON::ParserError
            # Fallback if JSON parsing fails
            {
              title: "Iskustvo: #{locations.map(&:city).uniq.join(' - ')}",
              description: response.truncate(500),
              duration_hours: locations.size
            }
          end
        end

        # Audio queries
        def execute_audio(ast)
          case ast[:action]
          when :synthesize
            synthesize_audio(ast)
          when :estimate
            estimate_audio_cost(ast)
          else
            raise ExecutionError, "Nepoznata audio akcija: #{ast[:action]}"
          end
        end

        # Synthesize audio for a location
        def synthesize_audio(ast)
          model = resolve_model(ast[:table])
          raise ExecutionError, "Audio sinteza je dostupna samo za lokacije" unless model == Location

          record = find_record_for_mutation(model, ast[:filters])
          locale = ast[:locale] || "bs"
          voice = ast[:voice]

          # Configure voice if specified
          if voice.present?
            voice_id = find_voice_id(voice)
            Setting.set("tts.elevenlabs_voice_id", voice_id) if voice_id
          end

          # Use the existing AudioTourGenerator
          generator = Ai::AudioTourGenerator.new(record)
          result = generator.generate(locale: locale, force: false)

          # Log the action
          PlatformAuditLog.create!(
            action: "create",
            record_type: "AudioTour",
            record_id: record.audio_tours.find_by(locale: locale)&.id,
            change_data: { location_id: record.id, locale: locale },
            triggered_by: "platform_dsl_audio"
          )

          {
            success: true,
            action: :synthesize_audio,
            location_id: record.id,
            location_name: record.name,
            locale: locale,
            status: result[:status],
            duration: result[:duration_estimate],
            audio_info: result[:audio_info]
          }
        rescue Ai::AudioTourGenerator::GenerationError => e
          raise ExecutionError, "Audio sinteza nije uspjela: #{e.message}"
        end

        # Estimate audio cost for multiple locations
        def estimate_audio_cost(ast)
          model = resolve_model(ast[:table])
          raise ExecutionError, "Procjena troškova je dostupna samo za lokacije" unless model == Location

          records = apply_filters(model, ast[:filters])

          # Filter to only those missing audio
          if ast[:filters][:missing_audio]
            records = records.select { |loc| !loc.audio_tours.with_audio.exists? }
          end

          # ElevenLabs pricing (approximate)
          # ~$0.30 per 1000 characters for standard voices
          # Average tour script: ~800 words = ~4000 characters
          chars_per_tour = 4000
          cost_per_1000_chars = 0.30

          total_locations = records.count
          total_chars = total_locations * chars_per_tour
          estimated_cost = (total_chars / 1000.0) * cost_per_1000_chars

          # Break down by city
          by_city = records.group_by(&:city).transform_values(&:count)

          {
            action: :estimate_audio_cost,
            total_locations: total_locations,
            estimated_characters: total_chars,
            estimated_cost_usd: estimated_cost.round(2),
            cost_per_location: (estimated_cost / [total_locations, 1].max).round(2),
            by_city: by_city,
            notes: [
              "Procjena bazirana na prosječnom skriptu od #{chars_per_tour} karaktera",
              "ElevenLabs cijena: ~$#{cost_per_1000_chars}/1000 karaktera",
              "Stvarni troškovi mogu varirati ovisno o dužini opisa"
            ]
          }
        end

        # Find voice ID by name
        def find_voice_id(voice_name)
          voices = Ai::AudioTourGenerator::ELEVENLABS_VOICES
          match = voices.find { |id, info| info[:name].downcase == voice_name.downcase }
          match&.first
        end

        # Proposals queries (ContentChange)
        def execute_proposals_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :list, nil
            list_proposals(filters)
          when :show
            show_proposal(filters)
          when :count
            count_proposals(filters)
          else
            list_proposals(filters)
          end
        end

        def list_proposals(filters)
          scope = ContentChange.all

          # Apply status filter
          if filters[:status]
            status = filters[:status].to_s
            scope = scope.where(status: status) if ContentChange.statuses.key?(status)
          else
            # Default to pending if no status specified
            scope = scope.pending
          end

          # Apply type filter
          if filters[:change_type] || filters[:type]
            change_type = (filters[:change_type] || filters[:type]).to_s
            scope = scope.where(change_type: change_type) if ContentChange.change_types.key?(change_type)
          end

          # Apply content type filter
          if filters[:content_type]
            scope = scope.where(changeable_type: filters[:content_type].to_s.classify)
          end

          proposals = scope.order(created_at: :desc).limit(50)

          {
            action: :list_proposals,
            count: proposals.size,
            total_pending: ContentChange.pending.count,
            proposals: proposals.map { |p| format_proposal(p) }
          }
        end

        def show_proposal(filters)
          proposal = find_proposal(filters)

          {
            action: :show_proposal,
            id: proposal.id,
            status: proposal.status,
            change_type: proposal.change_type,
            changeable_type: proposal.changeable_type || proposal.changeable_class,
            changeable_id: proposal.changeable_id,
            description: proposal.description,
            proposed_data: proposal.proposed_data,
            original_data: proposal.original_data,
            changes_diff: proposal.changes_diff,
            proposer: {
              id: proposal.user_id,
              username: proposal.user.username
            },
            contributors: proposal.all_contributors.map { |u| { id: u.id, username: u.username } },
            reviews: proposal.curator_reviews.map do |r|
              {
                user: r.user.username,
                recommendation: r.recommendation,
                comment: r.comment.truncate(100)
              }
            end,
            recommendation_summary: proposal.recommendation_summary,
            created_at: proposal.created_at.iso8601,
            reviewed_at: proposal.reviewed_at&.iso8601,
            reviewed_by: proposal.reviewed_by&.username
          }
        end

        def count_proposals(filters)
          scope = ContentChange.all

          if filters[:status]
            status = filters[:status].to_s
            scope = scope.where(status: status) if ContentChange.statuses.key?(status)
          end

          {
            pending: ContentChange.pending.count,
            approved: ContentChange.approved.count,
            rejected: ContentChange.rejected.count,
            total: ContentChange.count,
            by_type: ContentChange.group(:change_type).count,
            by_content_type: ContentChange.group(:changeable_type).count
          }
        end

        def find_proposal(filters)
          raise ExecutionError, "Potreban filter: id" unless filters[:id]

          proposal = ContentChange.find_by(id: filters[:id])
          raise ExecutionError, "Proposal sa id=#{filters[:id]} nije pronađen" unless proposal

          proposal
        end

        def format_proposal(proposal)
          {
            id: proposal.id,
            status: proposal.status,
            change_type: proposal.change_type,
            description: proposal.description,
            content_type: proposal.changeable_type || proposal.changeable_class,
            proposer: proposal.user.username,
            contributors_count: proposal.all_contributors.size,
            reviews_count: proposal.curator_reviews.count,
            recommendation_summary: proposal.recommendation_summary,
            created_at: proposal.created_at.iso8601
          }
        end

        # Applications queries (CuratorApplication)
        def execute_applications_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :list, nil
            list_applications(filters)
          when :show
            show_application(filters)
          when :count
            count_applications(filters)
          else
            list_applications(filters)
          end
        end

        def list_applications(filters)
          scope = CuratorApplication.all

          # Apply status filter
          if filters[:status]
            status = filters[:status].to_s
            scope = scope.where(status: status) if CuratorApplication.statuses.key?(status)
          else
            # Default to pending
            scope = scope.pending
          end

          applications = scope.recent.limit(50)

          {
            action: :list_applications,
            count: applications.size,
            total_pending: CuratorApplication.pending.count,
            applications: applications.map { |a| format_application(a) }
          }
        end

        def show_application(filters)
          application = find_application(filters)

          {
            action: :show_application,
            id: application.id,
            status: application.status,
            user: {
              id: application.user_id,
              username: application.user.username
            },
            motivation: application.motivation,
            experience: application.experience,
            created_at: application.created_at.iso8601,
            reviewed_at: application.reviewed_at&.iso8601,
            reviewed_by: application.reviewed_by&.username,
            admin_notes: application.admin_notes
          }
        end

        def count_applications(filters)
          {
            pending: CuratorApplication.pending.count,
            approved: CuratorApplication.approved.count,
            rejected: CuratorApplication.rejected.count,
            total: CuratorApplication.count
          }
        end

        def find_application(filters)
          raise ExecutionError, "Potreban filter: id" unless filters[:id]

          application = CuratorApplication.find_by(id: filters[:id])
          raise ExecutionError, "Application sa id=#{filters[:id]} nije pronađena" unless application

          application
        end

        def format_application(application)
          {
            id: application.id,
            status: application.status,
            user: {
              id: application.user_id,
              username: application.user.username
            },
            motivation_preview: application.motivation.truncate(100),
            created_at: application.created_at.iso8601
          }
        end

        # Approval commands (approve/reject)
        def execute_approval(ast)
          action = ast[:action]
          type = ast[:approval_type]
          filters = ast[:filters]

          case action
          when :approve
            if type == :proposal
              approve_proposal(filters, ast[:notes])
            else
              approve_application(filters, ast[:notes])
            end
          when :reject
            if type == :proposal
              reject_proposal(filters, ast[:reason])
            else
              reject_application(filters, ast[:reason])
            end
          else
            raise ExecutionError, "Nepoznata approval akcija: #{action}"
          end
        end

        def approve_proposal(filters, notes)
          proposal = find_proposal(filters)

          unless proposal.pending?
            raise ExecutionError, "Proposal nije u pending statusu (trenutni status: #{proposal.status})"
          end

          # Create a platform admin user for approval
          admin = platform_admin_user

          success = proposal.approve!(admin, notes: notes)

          unless success
            raise ExecutionError, "Odobravanje prijedloga nije uspjelo"
          end

          # Log the action
          PlatformAuditLog.create!(
            action: "approve",
            record_type: "ContentChange",
            record_id: proposal.id,
            change_data: { notes: notes, approved_by: "platform_dsl" },
            triggered_by: "platform_dsl_approval"
          )

          {
            success: true,
            action: :approve_proposal,
            proposal_id: proposal.id,
            change_type: proposal.change_type,
            content_type: proposal.changeable_type || proposal.changeable_class,
            notes: notes,
            message: "Prijedlog je odobren i promjene su primijenjene"
          }
        end

        def reject_proposal(filters, reason)
          proposal = find_proposal(filters)

          unless proposal.pending?
            raise ExecutionError, "Proposal nije u pending statusu (trenutni status: #{proposal.status})"
          end

          raise ExecutionError, "Potreban razlog za odbijanje" if reason.blank?

          admin = platform_admin_user
          proposal.reject!(admin, notes: reason)

          # Log the action
          PlatformAuditLog.create!(
            action: "reject",
            record_type: "ContentChange",
            record_id: proposal.id,
            change_data: { reason: reason, rejected_by: "platform_dsl" },
            triggered_by: "platform_dsl_approval"
          )

          {
            success: true,
            action: :reject_proposal,
            proposal_id: proposal.id,
            reason: reason,
            message: "Prijedlog je odbijen"
          }
        end

        def approve_application(filters, notes)
          application = find_application(filters)

          unless application.pending?
            raise ExecutionError, "Application nije u pending statusu (trenutni status: #{application.status})"
          end

          admin = platform_admin_user
          application.approve!(admin)

          # Log the action
          PlatformAuditLog.create!(
            action: "approve",
            record_type: "CuratorApplication",
            record_id: application.id,
            change_data: { notes: notes, approved_by: "platform_dsl", user_id: application.user_id },
            triggered_by: "platform_dsl_approval"
          )

          {
            success: true,
            action: :approve_application,
            application_id: application.id,
            user: {
              id: application.user_id,
              username: application.user.username
            },
            message: "Prijava za kuratora je odobrena. Korisnik je sada kurator."
          }
        end

        def reject_application(filters, reason)
          application = find_application(filters)

          unless application.pending?
            raise ExecutionError, "Application nije u pending statusu (trenutni status: #{application.status})"
          end

          raise ExecutionError, "Potreban razlog za odbijanje" if reason.blank?

          admin = platform_admin_user
          application.reject!(admin, reason)

          # Log the action
          PlatformAuditLog.create!(
            action: "reject",
            record_type: "CuratorApplication",
            record_id: application.id,
            change_data: { reason: reason, rejected_by: "platform_dsl" },
            triggered_by: "platform_dsl_approval"
          )

          {
            success: true,
            action: :reject_application,
            application_id: application.id,
            reason: reason,
            message: "Prijava za kuratora je odbijena"
          }
        end

        # Get or create platform admin user for approvals
        def platform_admin_user
          User.find_by(user_type: :admin) || User.find_by(username: "platform_system") || create_platform_user
        end

        def create_platform_user
          # Try to find any admin, or create a minimal platform user record
          admin = User.admin.first
          return admin if admin

          # Fallback: create a platform system user
          User.create!(
            username: "platform_system",
            user_type: :admin,
            password: SecureRandom.hex(32)
          )
        rescue => e
          Rails.logger.error "Failed to create platform user: #{e.message}"
          raise ExecutionError, "Nije moguće pronaći admin korisnika za odobravanje"
        end

        # Curators queries
        def execute_curators_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :list, nil
            list_curators(filters)
          when :show
            show_curator(filters)
          when :activity
            show_curator_activity(filters)
          when :check_spam
            check_spam(filters)
          when :count
            count_curators(filters)
          when :stats
            curator_stats
          else
            list_curators(filters)
          end
        end

        def list_curators(filters)
          scope = User.curator

          # Filter by blocked status
          if filters[:status] == "blocked"
            scope = scope.where("spam_blocked_until > ?", Time.current)
          elsif filters[:status] == "active"
            scope = scope.where(spam_blocked_until: nil)
          end

          # Filter by activity level
          if filters[:high_activity]
            scope = scope.where("activity_count_today > ?", (User::MAX_ACTIVITIES_PER_DAY * 0.5).to_i)
          end

          curators = scope.order(created_at: :desc).limit(50)

          {
            action: :list_curators,
            count: curators.size,
            total_curators: User.curator.count,
            total_blocked: User.curator.where("spam_blocked_until > ?", Time.current).count,
            curators: curators.map { |c| format_curator(c) }
          }
        end

        def show_curator(filters)
          curator = find_curator(filters)

          {
            action: :show_curator,
            id: curator.id,
            username: curator.username,
            user_type: curator.user_type,
            created_at: curator.created_at.iso8601,
            spam_blocked: curator.spam_blocked?,
            spam_block_reason: curator.spam_block_reason,
            spam_blocked_until: curator.spam_blocked_until&.iso8601,
            activity_count_today: curator.activity_count_today,
            total_activities: curator.curator_activities.count,
            proposals_count: curator.content_changes.count,
            reviews_count: curator.curator_reviews.count
          }
        end

        def show_curator_activity(filters)
          curator = find_curator(filters)
          limit = filters[:limit] || 20

          activities = curator.curator_activities.recent.limit(limit)

          {
            action: :curator_activity,
            curator_id: curator.id,
            username: curator.username,
            activity_count_today: curator.activity_count_today,
            activities: activities.map do |a|
              {
                action: a.action,
                description: a.description,
                recordable_type: a.recordable_type,
                recordable_id: a.recordable_id,
                created_at: a.created_at.iso8601
              }
            end,
            summary: {
              by_action: curator.curator_activities.today.group(:action).count,
              total_today: curator.curator_activities.today.count,
              total_this_hour: curator.curator_activities.this_hour.count
            }
          }
        end

        def check_spam(filters)
          if filters[:id]
            # Check specific curator
            curator = find_curator(filters)
            result = Services::SpamDetector.check_curator(curator, auto_block: false)

            {
              action: :check_spam,
              curator_id: curator.id,
              username: curator.username,
              result: result
            }
          else
            # Check all curators
            result = Services::SpamDetector.check_all

            {
              action: :check_spam_all,
              result: result,
              statistics: Services::SpamDetector.statistics
            }
          end
        end

        def count_curators(filters)
          {
            total: User.curator.count,
            active: User.curator.where(spam_blocked_until: nil).count,
            blocked: User.curator.where("spam_blocked_until > ?", Time.current).count,
            high_activity: User.curator.where("activity_count_today > ?", (User::MAX_ACTIVITIES_PER_DAY * 0.5).to_i).count
          }
        end

        def curator_stats
          Services::SpamDetector.statistics
        end

        def find_curator(filters)
          raise ExecutionError, "Potreban filter: id ili username" unless filters[:id] || filters[:username]

          curator = if filters[:id]
                      User.find_by(id: filters[:id])
                    else
                      User.find_by(username: filters[:username])
                    end

          raise ExecutionError, "Kurator nije pronađen" unless curator
          raise ExecutionError, "Korisnik nije kurator" unless curator.curator? || curator.admin?

          curator
        end

        def format_curator(curator)
          {
            id: curator.id,
            username: curator.username,
            spam_blocked: curator.spam_blocked?,
            activity_count_today: curator.activity_count_today,
            created_at: curator.created_at.iso8601
          }
        end

        # Curator management commands (block/unblock)
        def execute_curator_management(ast)
          action = ast[:action]
          filters = ast[:filters]

          case action
          when :block
            block_curator(filters, ast[:reason])
          when :unblock
            unblock_curator(filters)
          else
            raise ExecutionError, "Nepoznata curator management akcija: #{action}"
          end
        end

        def block_curator(filters, reason)
          curator = find_curator(filters)

          if curator.spam_blocked?
            raise ExecutionError, "Kurator je već blokiran (do #{curator.spam_blocked_until})"
          end

          raise ExecutionError, "Potreban razlog za blokiranje" if reason.blank?

          curator.block_for_spam!(reason)

          # Log the action
          PlatformAuditLog.create!(
            action: "update",
            record_type: "User",
            record_id: curator.id,
            change_data: {
              spam_blocked: true,
              reason: reason,
              blocked_by: "platform_dsl"
            },
            triggered_by: "platform_dsl_curator"
          )

          {
            success: true,
            action: :block_curator,
            curator_id: curator.id,
            username: curator.username,
            reason: reason,
            blocked_until: curator.spam_blocked_until.iso8601,
            message: "Kurator je blokiran do #{curator.spam_blocked_until}"
          }
        end

        def unblock_curator(filters)
          curator = find_curator(filters)

          unless curator.spam_blocked?
            raise ExecutionError, "Kurator nije blokiran"
          end

          old_reason = curator.spam_block_reason
          curator.admin_unblock!

          # Log the action
          PlatformAuditLog.create!(
            action: "update",
            record_type: "User",
            record_id: curator.id,
            change_data: {
              spam_unblocked: true,
              previous_reason: old_reason,
              unblocked_by: "platform_dsl"
            },
            triggered_by: "platform_dsl_curator"
          )

          {
            success: true,
            action: :unblock_curator,
            curator_id: curator.id,
            username: curator.username,
            message: "Kurator je odblokiran"
          }
        end

        # Code introspection queries
        def execute_code_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :read_file
            read_file(filters)
          when :search
            search_code(filters, operation[:args]&.first)
          when :grep
            grep_code(filters, operation[:args]&.first)
          when :structure
            show_code_structure(filters)
          when :models
            list_models
          when :routes
            list_routes
          else
            # Default: show code structure overview
            code_overview
          end
        end

        def read_file(filters)
          file_path = filters[:file] || filters[:path]
          raise ExecutionError, "Potreban filter: file ili path" unless file_path

          # Security: Only allow reading files within the Rails root
          full_path = Rails.root.join(file_path).to_s
          unless full_path.start_with?(Rails.root.to_s)
            raise ExecutionError, "Pristup fajlovima izvan projekta nije dozvoljen"
          end

          unless File.exist?(full_path)
            raise ExecutionError, "Fajl nije pronađen: #{file_path}"
          end

          content = File.read(full_path)
          lines = content.lines

          # Apply line limits if specified
          start_line = (filters[:from] || 1).to_i - 1
          end_line = filters[:to] ? filters[:to].to_i : lines.size
          selected_lines = lines[start_line...end_line]

          {
            action: :read_file,
            path: file_path,
            total_lines: lines.size,
            showing: "#{start_line + 1}-#{[end_line, lines.size].min}",
            content: selected_lines&.join || "",
            file_type: File.extname(file_path).delete(".")
          }
        end

        def search_code(filters, pattern)
          raise ExecutionError, "Potreban search pattern" unless pattern

          # Search using grep in the project
          search_path = filters[:path] || "app lib"
          file_type = filters[:type] || "rb"

          results = []
          search_path.split.each do |path|
            full_path = Rails.root.join(path)
            next unless Dir.exist?(full_path)

            Dir.glob(full_path.join("**/*.#{file_type}")).each do |file|
              File.readlines(file).each_with_index do |line, idx|
                if line.include?(pattern)
                  results << {
                    file: file.sub("#{Rails.root}/", ""),
                    line: idx + 1,
                    content: line.strip.truncate(100)
                  }
                end
              end
            end
          end

          {
            action: :search_code,
            pattern: pattern,
            file_type: file_type,
            matches: results.size,
            results: results.first(50)
          }
        end

        def grep_code(filters, pattern)
          search_code(filters, pattern)
        end

        def show_code_structure(filters)
          path = filters[:path] || "app"
          full_path = Rails.root.join(path)

          unless Dir.exist?(full_path)
            raise ExecutionError, "Direktorij nije pronađen: #{path}"
          end

          structure = {}
          Dir.glob(full_path.join("**/*")).each do |item|
            next if File.directory?(item)

            relative = item.sub("#{full_path}/", "")
            parts = relative.split("/")
            current = structure

            parts[0...-1].each do |dir|
              current[dir] ||= {}
              current = current[dir]
            end

            current[parts.last] = File.size(item)
          end

          {
            action: :code_structure,
            path: path,
            structure: structure,
            total_files: Dir.glob(full_path.join("**/*")).count { |f| File.file?(f) }
          }
        end

        def list_models
          models = Dir.glob(Rails.root.join("app/models/**/*.rb")).map do |file|
            model_name = File.basename(file, ".rb").camelize
            begin
              model = model_name.constantize
              next unless model < ApplicationRecord

              {
                name: model_name,
                table: model.table_name,
                columns: model.column_names.size,
                associations: model.reflect_on_all_associations.map(&:name)
              }
            rescue => e
              nil
            end
          end.compact

          {
            action: :list_models,
            count: models.size,
            models: models
          }
        end

        def list_routes
          routes = Rails.application.routes.routes.map do |route|
            {
              verb: route.verb,
              path: route.path.spec.to_s.gsub("(.:format)", ""),
              controller: route.defaults[:controller],
              action: route.defaults[:action]
            }
          end.reject { |r| r[:controller].nil? }

          {
            action: :list_routes,
            count: routes.size,
            routes: routes.first(100)
          }
        end

        def code_overview
          {
            action: :code_overview,
            app: {
              models: Dir.glob(Rails.root.join("app/models/**/*.rb")).size,
              controllers: Dir.glob(Rails.root.join("app/controllers/**/*.rb")).size,
              views: Dir.glob(Rails.root.join("app/views/**/*.erb")).size,
              jobs: Dir.glob(Rails.root.join("app/jobs/**/*.rb")).size,
              mailers: Dir.glob(Rails.root.join("app/mailers/**/*.rb")).size
            },
            lib: {
              platform: Dir.glob(Rails.root.join("lib/platform/**/*.rb")).size,
              services: Dir.glob(Rails.root.join("app/services/**/*.rb")).size
            },
            test: {
              total: Dir.glob(Rails.root.join("test/**/*_test.rb")).size
            },
            config: {
              routes: Rails.application.routes.routes.size,
              initializers: Dir.glob(Rails.root.join("config/initializers/*.rb")).size
            }
          }
        end

        # Logs introspection queries
        def execute_logs_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :errors
            show_errors(filters)
          when :slow_queries
            show_slow_queries(filters)
          when :recent
            show_recent_logs(filters)
          when :audit
            show_audit_logs(filters)
          when :dsl
            show_dsl_logs(filters)
          else
            # Default: log summary
            logs_summary(filters)
          end
        end

        def show_errors(filters)
          # Parse time filter
          time_range = parse_time_range(filters[:last] || "24h")

          # Get Rails logs errors (if accessible)
          errors = []

          # Check PlatformAuditLog for errors
          audit_errors = PlatformAuditLog.where("created_at >= ?", time_range)
                                         .where("change_data->>'error' IS NOT NULL")
                                         .order(created_at: :desc)
                                         .limit(50)

          errors += audit_errors.map do |log|
            {
              type: "audit_error",
              action: log.action,
              record_type: log.record_type,
              error: log.change_data["error"],
              created_at: log.created_at.iso8601
            }
          end

          # Check SolidQueue failed jobs
          begin
            if defined?(SolidQueue::Job) && SolidQueue::Job.table_exists?
              failed_jobs = SolidQueue::Job.where("finished_at IS NOT NULL")
                                           .where("created_at >= ?", time_range)
                                           .order(created_at: :desc)
                                           .limit(20)

              errors += failed_jobs.map do |job|
                {
                  type: "failed_job",
                  job_class: job.class_name,
                  queue: job.queue_name,
                  created_at: job.created_at.iso8601
                }
              end
            end
          rescue => e
            # SolidQueue may not be set up
          end

          {
            action: :show_errors,
            time_range: filters[:last] || "24h",
            count: errors.size,
            errors: errors
          }
        end

        def show_slow_queries(filters)
          threshold_ms = (filters[:threshold] || 1000).to_i

          # This would require ActiveRecord query logging to be enabled
          # For now, return a placeholder that can be enhanced
          {
            action: :slow_queries,
            threshold_ms: threshold_ms,
            note: "Slow query logging requires ActiveRecord instrumentation",
            suggestion: "Enable config.active_record.query_log_tags for query tracking",
            recent_complex_queries: {
              locations_with_audio: estimate_query_time("Location.with_audio.count"),
              experience_aggregations: estimate_query_time("Experience.includes(:locations).count"),
              knowledge_searches: estimate_query_time("KnowledgeCluster.semantic_search")
            }
          }
        end

        def show_recent_logs(filters)
          limit = (filters[:limit] || 50).to_i

          # Get recent audit logs
          logs = PlatformAuditLog.order(created_at: :desc).limit(limit)

          {
            action: :recent_logs,
            count: logs.size,
            logs: logs.map do |log|
              {
                id: log.id,
                action: log.action,
                record_type: log.record_type,
                record_id: log.record_id,
                triggered_by: log.triggered_by,
                created_at: log.created_at.iso8601
              }
            end
          }
        end

        def show_audit_logs(filters)
          scope = PlatformAuditLog.all

          # Apply filters
          scope = scope.where(action: filters[:action]) if filters[:action]
          scope = scope.where(record_type: filters[:record_type]) if filters[:record_type]
          scope = scope.where(triggered_by: filters[:triggered_by]) if filters[:triggered_by]

          if filters[:last]
            time_range = parse_time_range(filters[:last])
            scope = scope.where("created_at >= ?", time_range)
          end

          logs = scope.order(created_at: :desc).limit(100)

          {
            action: :audit_logs,
            count: logs.size,
            total: scope.count,
            by_action: PlatformAuditLog.group(:action).count,
            by_record_type: PlatformAuditLog.group(:record_type).count,
            logs: logs.map do |log|
              {
                id: log.id,
                action: log.action,
                record_type: log.record_type,
                record_id: log.record_id,
                changes: log.change_data&.keys,
                triggered_by: log.triggered_by,
                created_at: log.created_at.iso8601
              }
            end
          }
        end

        def show_dsl_logs(filters)
          # DSL-triggered actions
          scope = PlatformAuditLog.where("triggered_by LIKE ?", "platform_dsl%")

          if filters[:last]
            time_range = parse_time_range(filters[:last])
            scope = scope.where("created_at >= ?", time_range)
          end

          logs = scope.order(created_at: :desc).limit(50)

          {
            action: :dsl_logs,
            count: logs.size,
            by_trigger: scope.group(:triggered_by).count,
            logs: logs.map do |log|
              {
                id: log.id,
                action: log.action,
                record_type: log.record_type,
                record_id: log.record_id,
                triggered_by: log.triggered_by,
                created_at: log.created_at.iso8601
              }
            end
          }
        end

        def logs_summary(filters)
          time_range = parse_time_range(filters[:last] || "24h")

          {
            action: :logs_summary,
            time_range: filters[:last] || "24h",
            audit_logs: {
              total: PlatformAuditLog.where("created_at >= ?", time_range).count,
              by_action: PlatformAuditLog.where("created_at >= ?", time_range).group(:action).count,
              by_record_type: PlatformAuditLog.where("created_at >= ?", time_range).group(:record_type).count,
              dsl_triggered: PlatformAuditLog.where("created_at >= ? AND triggered_by LIKE ?", time_range, "platform_dsl%").count
            },
            queue: queue_summary
          }
        end

        def parse_time_range(range_str)
          case range_str.to_s.downcase
          when /(\d+)h/
            $1.to_i.hours.ago
          when /(\d+)d/
            $1.to_i.days.ago
          when /(\d+)w/
            $1.to_i.weeks.ago
          when /(\d+)m/
            $1.to_i.months.ago
          else
            24.hours.ago
          end
        end

        def estimate_query_time(query_description)
          # Placeholder for query time estimation
          {
            query: query_description,
            estimated: "< 100ms",
            note: "Actual timing requires profiling"
          }
        end

        # Infrastructure introspection queries
        def execute_infrastructure_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :queue_status
            queue_status
          when :health
            infrastructure_health
          when :processes
            show_processes
          when :storage
            storage_status
          when :database
            database_status
          when :cache
            cache_status
          else
            # Default: full infrastructure status
            infrastructure_overview
          end
        end

        def queue_status
          return { error: "SolidQueue not available" } unless defined?(SolidQueue::Job)

          {
            action: :queue_status,
            jobs: {
              pending: SolidQueue::Job.where(finished_at: nil).count,
              scheduled: SolidQueue::ScheduledExecution.count,
              failed: SolidQueue::FailedExecution.count
            },
            by_queue: SolidQueue::Job.where(finished_at: nil).group(:queue_name).count,
            by_class: SolidQueue::Job.where(finished_at: nil).group(:class_name).count.first(10).to_h,
            recent_failures: SolidQueue::FailedExecution.order(created_at: :desc).limit(5).map do |f|
              {
                job_class: f.job.class_name,
                error: f.error&.truncate(100),
                created_at: f.created_at.iso8601
              }
            end
          }
        rescue => e
          { action: :queue_status, error: e.message }
        end

        def queue_summary
          return {} unless defined?(SolidQueue::Job)

          {
            pending: SolidQueue::Job.where(finished_at: nil).count,
            failed: SolidQueue::FailedExecution.count
          }
        rescue
          {}
        end

        def infrastructure_health
          {
            action: :infrastructure_health,
            database: check_database_health,
            storage: check_storage_health,
            queue: check_queue_health,
            api_keys: check_api_keys,
            memory: memory_status,
            disk: disk_status
          }
        end

        def show_processes
          # Show Rails processes info
          {
            action: :processes,
            ruby_version: RUBY_VERSION,
            rails_version: Rails.version,
            environment: Rails.env,
            pid: Process.pid,
            memory_mb: (`ps -o rss= -p #{Process.pid}`.to_i / 1024.0).round(2),
            uptime: process_uptime
          }
        rescue => e
          { action: :processes, error: e.message }
        end

        def storage_status
          {
            action: :storage_status,
            service: ActiveStorage::Blob.service.class.name,
            attachments_count: ActiveStorage::Attachment.count,
            blobs_count: ActiveStorage::Blob.count,
            total_size_mb: (ActiveStorage::Blob.sum(:byte_size) / 1_000_000.0).round(2),
            by_content_type: ActiveStorage::Blob.group(:content_type).count.first(10).to_h
          }
        rescue => e
          { action: :storage_status, error: e.message }
        end

        def database_status
          conn = ActiveRecord::Base.connection

          result = {
            action: :database_status,
            adapter: conn.adapter_name,
            database: conn.current_database,
            tables: conn.tables.size,
            table_sizes: get_table_sizes
          }

          # Try to get migration info (may not be available in all environments)
          begin
            migrations = ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate"))
            result[:schema_version] = migrations.current_version
            result[:pending_migrations] = migrations.needs_migration?
          rescue => e
            result[:schema_version] = "unavailable"
            result[:pending_migrations] = "unavailable"
          end

          result
        rescue => e
          { action: :database_status, error: e.message }
        end

        def get_table_sizes
          tables = %w[locations experiences plans users reviews content_changes knowledge_summaries]
          tables.each_with_object({}) do |table, hash|
            begin
              hash[table] = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first["count"]
            rescue
              hash[table] = "N/A"
            end
          end
        end

        def cache_status
          {
            action: :cache_status,
            store: Rails.cache.class.name,
            statistics: PlatformStatistic.count,
            fresh_statistics: PlatformStatistic.where("updated_at >= ?", 5.minutes.ago).count
          }
        rescue => e
          { action: :cache_status, error: e.message }
        end

        def memory_status
          rss = `ps -o rss= -p #{Process.pid}`.to_i
          {
            rss_mb: (rss / 1024.0).round(2),
            status: rss > 500_000 ? "high" : "normal"
          }
        rescue
          { status: "unknown" }
        end

        def disk_status
          df_output = `df -h #{Rails.root} 2>/dev/null`.lines.last&.split
          if df_output && df_output.size >= 5
            {
              filesystem: df_output[0],
              size: df_output[1],
              used: df_output[2],
              available: df_output[3],
              use_percent: df_output[4]
            }
          else
            { status: "unknown" }
          end
        rescue
          { status: "unknown" }
        end

        def process_uptime
          # Try to get process start time
          start_time = File.stat("/proc/#{Process.pid}").ctime rescue nil
          return "unknown" unless start_time

          seconds = Time.now - start_time
          if seconds < 3600
            "#{(seconds / 60).to_i} minutes"
          elsif seconds < 86400
            "#{(seconds / 3600).to_i} hours"
          else
            "#{(seconds / 86400).to_i} days"
          end
        rescue
          "unknown"
        end

        def infrastructure_overview
          {
            action: :infrastructure_overview,
            environment: Rails.env,
            ruby: RUBY_VERSION,
            rails: Rails.version,
            database: {
              adapter: ActiveRecord::Base.connection.adapter_name,
              tables: ActiveRecord::Base.connection.tables.size
            },
            storage: {
              service: ActiveStorage::Blob.service.class.name,
              attachments: ActiveStorage::Attachment.count
            },
            queue: queue_summary,
            health: {
              database: check_database_health[:status],
              api_keys: check_api_keys.values.count("configured"),
              total_api_keys: check_api_keys.size
            }
          }
        end

        # Prompts queries
        def execute_prompts_query(ast)
          filters = ast[:filters] || {}
          operation = ast[:operations]&.first

          case operation&.dig(:name)
          when :list, nil
            list_prompts(filters)
          when :show
            show_prompt(filters)
          when :count
            count_prompts(filters)
          when :pending
            list_prompts(filters.merge(status: "pending"))
          when :export
            export_prompt(filters)
          else
            list_prompts(filters)
          end
        end

        def list_prompts(filters)
          scope = PreparedPrompt.all

          # Apply status filter
          if filters[:status]
            status = filters[:status].to_s
            scope = scope.where(status: status) if PreparedPrompt.statuses.key?(status)
          end

          # Apply type filter
          if filters[:type] || filters[:prompt_type]
            prompt_type = (filters[:type] || filters[:prompt_type]).to_s
            scope = scope.where(prompt_type: prompt_type) if PreparedPrompt.prompt_types.key?(prompt_type)
          end

          # Apply severity filter
          if filters[:severity]
            scope = scope.where(severity: filters[:severity]) if PreparedPrompt.severities.key?(filters[:severity].to_s)
          end

          prompts = scope.by_severity.recent.limit(50)

          {
            action: :list_prompts,
            count: prompts.size,
            total_pending: PreparedPrompt.status_pending.count,
            prompts: prompts.map(&:to_short_format)
          }
        end

        def show_prompt(filters)
          prompt = find_prompt(filters)

          {
            action: :show_prompt,
            prompt: prompt.to_full_format
          }
        end

        def count_prompts(filters)
          {
            total: PreparedPrompt.count,
            pending: PreparedPrompt.status_pending.count,
            in_progress: PreparedPrompt.status_in_progress.count,
            applied: PreparedPrompt.status_applied.count,
            rejected: PreparedPrompt.status_rejected.count,
            by_type: PreparedPrompt.group(:prompt_type).count,
            by_severity: PreparedPrompt.group(:severity).count
          }
        end

        def export_prompt(filters)
          prompt = find_prompt(filters)

          {
            action: :export_prompt,
            prompt_id: prompt.id,
            title: prompt.title,
            claude_prompt: prompt.to_claude_prompt
          }
        end

        def find_prompt(filters)
          raise ExecutionError, "Potreban filter: id" unless filters[:id]

          prompt = PreparedPrompt.find_by(id: filters[:id])
          raise ExecutionError, "Prompt sa id=#{filters[:id]} nije pronađen" unless prompt

          prompt
        end

        # Improvement commands (prepare fix, prepare feature, etc.)
        def execute_improvement(ast)
          improvement_type = ast[:improvement_type]
          description = ast[:description]
          severity = ast[:severity]
          target_file = ast[:target_file]

          raise ExecutionError, "Potreban opis za pripremu prompta" if description.blank?

          # Map improvement type to prompt type
          prompt_type = case improvement_type
                        when :fix then "fix"
                        when :feature then "feature"
                        when :improvement then "improvement"
                        else "fix"
                        end

          # Generate analysis and solution using LLM (if available)
          analysis, solution = analyze_improvement(description, prompt_type, target_file)

          # Create the prepared prompt
          prompt = PreparedPrompt.create!(
            prompt_type: prompt_type,
            title: generate_title(description, prompt_type),
            content: description,
            severity: severity,
            target_file: target_file,
            analysis: analysis,
            solution: solution,
            metadata: {
              created_via: "platform_dsl",
              created_at: Time.current.iso8601
            }
          )

          # Log the action
          PlatformAuditLog.create!(
            action: "create",
            record_type: "PreparedPrompt",
            record_id: prompt.id,
            change_data: {
              prompt_type: prompt_type,
              description: description.truncate(100)
            },
            triggered_by: "platform_dsl_improvement"
          )

          {
            success: true,
            action: :prepare_prompt,
            prompt_id: prompt.id,
            type: prompt_type,
            title: prompt.title,
            severity: severity,
            message: "Prompt pripremljen. Koristi 'prompts { id: #{prompt.id} } | show' za pregled."
          }
        end

        def analyze_improvement(description, prompt_type, target_file)
          # Try to generate analysis using LLM
          begin
            analysis = generate_analysis(description, prompt_type, target_file)
            solution = generate_solution(description, prompt_type, target_file)
            [analysis, solution]
          rescue => e
            # If LLM fails, return placeholder
            Rails.logger.warn "Failed to generate analysis: #{e.message}"
            [nil, nil]
          end
        end

        def generate_analysis(description, prompt_type, target_file)
          prompt = <<~PROMPT
            Analiziraj sljedeći #{prompt_type == 'fix' ? 'problem' : 'zahtjev'}:

            #{description}

            #{target_file ? "Ciljani fajl: #{target_file}" : ""}

            Napiši kratku analizu (2-3 rečenice) koja objašnjava:
            - Koji je root cause (za fixove) ili svrha (za feature)
            - Koje komponente su uključene
            - Potencijalne rizike ili ovisnosti

            Vrati SAMO tekst analize.
          PROMPT

          generate_with_llm(prompt)
        rescue
          nil
        end

        def generate_solution(description, prompt_type, target_file)
          prompt = <<~PROMPT
            Predloži rješenje za sljedeći #{prompt_type == 'fix' ? 'problem' : 'zahtjev'}:

            #{description}

            #{target_file ? "Ciljani fajl: #{target_file}" : ""}

            Napiši kratak prijedlog rješenja (3-5 bullet points) koji opisuje:
            - Ključne korake implementacije
            - Potrebne izmjene fajlova
            - Testove koje treba napisati

            Vrati SAMO bullet points, bez uvoda.
          PROMPT

          generate_with_llm(prompt)
        rescue
          nil
        end

        def generate_title(description, prompt_type)
          # Try to generate a concise title
          begin
            prompt = <<~PROMPT
              Generiši kratak naslov (max 80 karaktera) za sljedeći #{prompt_type}:

              #{description}

              Vrati SAMO naslov, bez dodatnog teksta.
            PROMPT

            title = generate_with_llm(prompt)
            title.strip.truncate(80)
          rescue
            # Fallback to description truncation
            "#{prompt_type.capitalize}: #{description.truncate(60)}"
          end
        end

        # Prompt action commands (apply, reject)
        def execute_prompt_action(ast)
          action = ast[:action]
          filters = ast[:filters]

          case action
          when :apply
            apply_prompt(filters)
          when :reject
            reject_prompt(filters, ast[:reason])
          else
            raise ExecutionError, "Nepoznata prompt akcija: #{action}"
          end
        end

        def apply_prompt(filters)
          prompt = find_prompt(filters)

          unless prompt.status_pending? || prompt.status_in_progress?
            raise ExecutionError, "Prompt nije u pending ili in_progress statusu (trenutni status: #{prompt.status})"
          end

          prompt.apply!

          # Log the action
          PlatformAuditLog.create!(
            action: "update",
            record_type: "PreparedPrompt",
            record_id: prompt.id,
            change_data: {
              status: "applied",
              applied_by: "platform_dsl"
            },
            triggered_by: "platform_dsl_improvement"
          )

          {
            success: true,
            action: :apply_prompt,
            prompt_id: prompt.id,
            title: prompt.title,
            message: "Prompt je označen kao primijenjen"
          }
        end

        def reject_prompt(filters, reason)
          prompt = find_prompt(filters)

          unless prompt.status_pending? || prompt.status_in_progress?
            raise ExecutionError, "Prompt nije u pending ili in_progress statusu (trenutni status: #{prompt.status})"
          end

          raise ExecutionError, "Potreban razlog za odbijanje" if reason.blank?

          prompt.reject!(reason: reason)

          # Log the action
          PlatformAuditLog.create!(
            action: "update",
            record_type: "PreparedPrompt",
            record_id: prompt.id,
            change_data: {
              status: "rejected",
              reason: reason,
              rejected_by: "platform_dsl"
            },
            triggered_by: "platform_dsl_improvement"
          )

          {
            success: true,
            action: :reject_prompt,
            prompt_id: prompt.id,
            title: prompt.title,
            reason: reason,
            message: "Prompt je odbijen"
          }
        end
      end
    end
  end
end
