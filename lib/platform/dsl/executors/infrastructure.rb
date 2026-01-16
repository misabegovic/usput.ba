# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # Infrastructure executor - logs, queue, system health
      #
      # Used queries:
      #   infrastructure | health
      #   infrastructure | queue_status
      #   logs { last: "24h" }
      #   logs | errors
      #
      class Infrastructure
        class << self
          def execute_infrastructure(ast)
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
              infrastructure_overview
            end
          end

          def execute_logs(ast)
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
              logs_summary(filters)
            end
          end

          private

          # Infrastructure methods
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

          # Logs methods
          def show_errors(filters)
            time_range = parse_time_range(filters[:last] || "24h")
            errors = []

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

          # Helper methods
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
            { service: ActiveStorage::Blob.service.class.name }
          rescue => e
            { status: "error", message: e.message }
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
            {
              query: query_description,
              estimated: "< 100ms",
              note: "Actual timing requires profiling"
            }
          end
        end
      end
    end
  end
end
