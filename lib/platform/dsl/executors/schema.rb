# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # Schema executor - stats, describe, health operations
      #
      # Used queries:
      #   schema | stats
      #   schema | describe <table>
      #   schema | health
      #
      class Schema
        class << self
          def execute(ast)
            operation = ast[:operations].first
            case operation[:name]
            when :stats
              # Check for "live" flag in args: schema | stats live
              live_mode = operation[:args]&.first&.to_s == "live"
              build_stats(live: live_mode)
            when :stats_live
              build_stats(live: true)
            when :describe
              table = operation[:args]&.first
              describe_table(table)
            when :health
              build_health
            when :refresh
              # Force refresh all stats
              PlatformStatistic.refresh_all
              { action: :refresh, status: :ok, message: "Stats refreshed" }
            else
              raise ExecutionError, "Nepoznata schema operacija: #{operation[:name]}"
            end
          end

          private

          def build_stats(live: false)
            # Force live query if requested
            return build_stats_directly if live

            # Use cached statistics if available
            cached = PlatformStatistic.find_by(key: "layer_zero")
            if cached&.fresh?(5.minutes)
              return format_cached_stats(cached.value)
            end

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
              ai_generated: {
                locations: { ai: Location.where(ai_generated: true).count, human: Location.where(ai_generated: false).count },
                experiences: { ai: Experience.where(ai_generated: true).count, human: Experience.where(ai_generated: false).count },
                plans: { ai: Plan.where(ai_generated: true).count, human: Plan.where(ai_generated: false).count }
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
            raise ExecutionError, "Table name required for describe" if table_name.blank?

            model = TableQuery.resolve_model(table_name.to_s)
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
        end
      end
    end
  end
end
