# frozen_string_literal: true

module Ai
  module Concerns
    # Centralized error reporting for AI services
    # Logs to Rails.logger AND reports to Rollbar
    module ErrorReporting
      extend ActiveSupport::Concern

      private

      # Log warning - reports to Rollbar as warning level
      # @param message [String] The warning message
      # @param exception [Exception, nil] Optional exception object for full stack trace
      # @param context [Hash] Additional context to include in Rollbar
      def log_warn(message, exception: nil, **context)
        full_message = "[#{service_name}] #{message}"
        Rails.logger.warn(full_message)

        return unless rollbar_enabled?

        rollbar_context = build_rollbar_context(context)

        if exception
          Rollbar.warning(exception, rollbar_context.merge(message: full_message))
        else
          Rollbar.warning(full_message, rollbar_context)
        end
      end

      # Log error - reports to Rollbar as error level
      # @param message [String] The error message
      # @param exception [Exception, nil] Optional exception object for full stack trace
      # @param context [Hash] Additional context to include in Rollbar
      def log_error(message, exception: nil, **context)
        full_message = "[#{service_name}] #{message}"
        Rails.logger.error(full_message)

        return unless rollbar_enabled?

        rollbar_context = build_rollbar_context(context)

        if exception
          Rollbar.error(exception, rollbar_context.merge(message: full_message))
        else
          Rollbar.error(full_message, rollbar_context)
        end
      end

      # Log info - does NOT report to Rollbar (info level only)
      # @param message [String] The info message
      def log_info(message)
        Rails.logger.info("[#{service_name}] #{message}")
      end

      # Log debug - does NOT report to Rollbar
      # @param message [String] The debug message
      def log_debug(message)
        Rails.logger.debug("[#{service_name}] #{message}")
      end

      # Service name for log prefix - override in including class if needed
      def service_name
        self.class.name || "AI::Service"
      end

      def rollbar_enabled?
        defined?(Rollbar) && Rollbar.configuration.enabled
      end

      def build_rollbar_context(context)
        base_context = {
          service: service_name,
          timestamp: Time.current.iso8601
        }

        # Add instance variables that might be useful for debugging
        base_context[:city] = @city_name if defined?(@city_name) && @city_name
        base_context[:coordinates] = @coordinates if defined?(@coordinates) && @coordinates
        base_context[:generation_id] = @generation&.id if defined?(@generation) && @generation

        base_context.merge(context)
      end
    end
  end
end
