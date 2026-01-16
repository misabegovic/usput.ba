# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # TableQuery executor - dynamic queries on database tables
      #
      # Used queries:
      #   locations { city: "Mostar" } | count
      #   locations { type: "restaurant" } | sample 5
      #   experiences | aggregate count() by city
      #
      class TableQuery
        # Table name to model mapping
        TABLE_MAP = {
          "locations" => "Location",
          "location" => "Location",
          "experiences" => "Experience",
          "experience" => "Experience",
          "plans" => "Plan",
          "plan" => "Plan",
          "plan_experiences" => "PlanExperience",
          "plan_experience" => "PlanExperience",
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

          private

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
            when :show, :list
              return scope.limit(100).to_a.map { |r| format_record(r) }
            when :first
              record = scope.first
              return record ? format_record(record) : nil
            when :last
              record = scope.last
              return record ? format_record(record) : nil
            else
              raise ExecutionError, "Nepoznata operacija: #{operation[:name]}"
            end
          end

          def apply_aggregate(scope, operation)
            func = operation[:args]&.first || :count
            group_by = operation[:group_by]

            case func.to_s
            when "count", "count()"
              group_by ? scope.group(group_by).count : scope.count
            when "sum"
              field = operation[:args]&.[](1)
              group_by ? scope.group(group_by).sum(field) : scope.sum(field)
            when "avg"
              field = operation[:args]&.[](1)
              group_by ? scope.group(group_by).average(field) : scope.average(field)
            else
              raise ExecutionError, "Nepoznata agregacijska funkcija: #{func}"
            end
          end

          def apply_where_condition(scope, condition)
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
        end
      end
    end
  end
end
