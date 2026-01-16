# frozen_string_literal: true

require_relative "base_controller"

module API
  module Platform
    # StatusController - Platform status and health endpoints
    #
    # Provides REST API for checking Platform health, prompts, and statistics.
    #
    class StatusController < BaseController
      # GET /api/platform/status
      #
      # Get overall Platform status
      def index
        status = {
          platform: "operational",
          version: platform_version,
          environment: Rails.env,
          timestamp: Time.current.iso8601
        }

        # Add health checks
        status[:health] = health_check
        status[:statistics] = quick_statistics

        render json: status
      end

      # GET /api/platform/health
      #
      # Detailed health check
      def health
        result = ::Platform::DSL.execute("infrastructure | health")

        render json: {
          status: determine_health_status(result),
          checks: result,
          timestamp: Time.current.iso8601
        }
      end

      # GET /api/platform/prompts
      #
      # List pending prompts
      def prompts
        status_filter = sanitize_status(params[:status])
        result = ::Platform::DSL.execute("prompts { status: \"#{status_filter}\" } | list")

        render json: result
      end

      # GET /api/platform/prompts/:id
      #
      # Get prompt details
      def show_prompt
        prompt_id = sanitize_integer(params[:id])
        return render json: { error: "Invalid prompt ID" }, status: :bad_request unless prompt_id

        result = ::Platform::DSL.execute("prompts { id: #{prompt_id} } | show")

        render json: result
      end

      # GET /api/platform/statistics
      #
      # Get Platform statistics
      def statistics
        result = ::Platform::DSL.execute("schema | stats")

        render json: result
      end

      # GET /api/platform/infrastructure
      #
      # Get infrastructure status
      def infrastructure
        result = ::Platform::DSL.execute("infrastructure")

        render json: result
      end

      # GET /api/platform/logs
      #
      # Get recent audit logs
      def logs
        time_range = sanitize_time_range(params[:last])
        result = ::Platform::DSL.execute("logs { last: \"#{time_range}\" }")

        render json: result
      end

      private

      # Sanitization helpers to prevent DSL injection
      ALLOWED_STATUSES = %w[pending approved rejected executed expired all].freeze
      ALLOWED_TIME_RANGES = %w[1h 6h 12h 24h 48h 7d 30d].freeze

      def sanitize_status(status)
        return "pending" if status.blank?
        ALLOWED_STATUSES.include?(status.to_s.downcase) ? status.to_s.downcase : "pending"
      end

      def sanitize_integer(value)
        return nil if value.blank?
        Integer(value, 10) rescue nil
      end

      def sanitize_time_range(range)
        return "24h" if range.blank?
        ALLOWED_TIME_RANGES.include?(range.to_s.downcase) ? range.to_s.downcase : "24h"
      end

      def platform_version
        # Could be read from a version file or constant
        "1.0.0"
      end

      def health_check
        checks = {}

        # Database check
        checks[:database] = begin
          ActiveRecord::Base.connection.execute("SELECT 1")
          "ok"
        rescue => e
          "error: #{e.message}"
        end

        # Storage check
        checks[:storage] = begin
          ActiveStorage::Blob.count
          "ok"
        rescue => e
          "error: #{e.message}"
        end

        # Queue check
        checks[:queue] = begin
          if defined?(SolidQueue::Job) && SolidQueue::Job.table_exists?
            "ok"
          else
            "not_configured"
          end
        rescue
          "not_configured"
        end

        checks
      end

      def quick_statistics
        {
          locations: Location.count,
          experiences: Experience.count,
          pending_prompts: PreparedPrompt.status_pending.count,
          curators: User.curator.count
        }
      rescue => e
        { error: e.message }
      end

      def determine_health_status(health_result)
        return "unhealthy" unless health_result.is_a?(Hash)

        # Check database status
        db_status = health_result.dig(:database, :status)
        return "unhealthy" if db_status != "ok"

        # Check for critical issues
        if health_result[:api_keys].is_a?(Hash)
          configured_count = health_result[:api_keys].values.count("configured")
          total_count = health_result[:api_keys].size
          return "degraded" if configured_count < total_count / 2
        end

        "healthy"
      end
    end
  end
end
