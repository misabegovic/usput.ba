# frozen_string_literal: true

module API
  module Platform
    # Base controller for Platform API
    #
    # Provides authentication, rate limiting, and common functionality for all
    # Platform API endpoints. Authentication is via API key in the Authorization header.
    #
    # @example Request with API key
    #   curl -H "Authorization: Bearer YOUR_API_KEY" https://api.usput.ba/platform/chat
    #
    # Rate Limits:
    #   - Default: 60 requests per minute
    #   - Configurable via PLATFORM_API_RATE_LIMIT env var
    #
    class BaseController < ActionController::API
      before_action :authenticate_api_key!
      before_action :check_rate_limit!

      # Order matters: Rails checks rescue_from in reverse order (last defined wins)
      # So StandardError must be FIRST, specific errors AFTER
      rescue_from StandardError, with: :handle_standard_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
      rescue_from ArgumentError, with: :handle_argument_error
      rescue_from ::Platform::DSL::ParseError, with: :handle_parse_error
      rescue_from ::Platform::DSL::ExecutionError, with: :handle_execution_error

      private

      def authenticate_api_key!
        api_key = extract_api_key
        return if valid_api_key?(api_key)

        render json: error_response("Unauthorized", "Invalid or missing API key", status: 401),
               status: :unauthorized
      end

      def extract_api_key
        # Accept API key from Authorization header or api_key parameter
        auth_header = request.headers["Authorization"]
        if auth_header&.start_with?("Bearer ")
          auth_header.split(" ").last
        else
          params[:api_key]
        end
      end

      def valid_api_key?(key)
        return false if key.blank?

        # Check against configured API key
        configured_key = ENV["PLATFORM_API_KEY"]
        return false if configured_key.blank?

        ActiveSupport::SecurityUtils.secure_compare(key, configured_key)
      end

      # Rate limiting using Rails cache
      def check_rate_limit!
        return if skip_rate_limit?

        key = rate_limit_key
        limit = rate_limit_per_minute
        window = 1.minute

        current = Rails.cache.increment(key, 1, expires_in: window, raw: true) || 1

        # Set rate limit headers
        response.headers["X-RateLimit-Limit"] = limit.to_s
        response.headers["X-RateLimit-Remaining"] = [limit - current.to_i, 0].max.to_s
        response.headers["X-RateLimit-Reset"] = (Time.current + window).to_i.to_s

        return unless current.to_i > limit

        render json: error_response(
          "RateLimitExceeded",
          "Rate limit exceeded. Please wait before making more requests.",
          status: 429,
          details: { limit: limit, retry_after: window.to_i }
        ), status: :too_many_requests
      end

      def rate_limit_key
        api_key = extract_api_key
        "platform_api:rate_limit:#{api_key || request.remote_ip}"
      end

      def rate_limit_per_minute
        (ENV["PLATFORM_API_RATE_LIMIT"] || 60).to_i
      end

      def skip_rate_limit?
        # Skip rate limiting in test environment
        Rails.env.test?
      end

      def handle_execution_error(error)
        render json: error_response("ExecutionError", error.message, status: 422),
               status: :unprocessable_entity
      end

      def handle_parse_error(error)
        render json: error_response("ParseError", error.message, status: 400),
               status: :bad_request
      end

      def handle_not_found(error)
        render json: error_response("NotFound", error.message, status: 404),
               status: :not_found
      end

      def handle_validation_error(error)
        render json: error_response(
          "ValidationError",
          error.message,
          status: 422,
          details: { errors: error.record&.errors&.to_hash }
        ), status: :unprocessable_entity
      end

      def handle_argument_error(error)
        render json: error_response("ArgumentError", error.message, status: 400),
               status: :bad_request
      end

      def handle_standard_error(error)
        Rails.logger.error "Platform API Error: #{error.class.name}: #{error.message}\n#{error.backtrace.first(10).join("\n")}"

        message = Rails.env.production? ? "An unexpected error occurred" : error.message

        render json: error_response(
          "InternalError",
          message,
          status: 500,
          details: Rails.env.production? ? nil : { error_class: error.class.name }
        ), status: :internal_server_error
      end

      # Standardized error response format
      def error_response(error_type, message, status:, details: nil)
        response = {
          error: error_type,
          message: message,
          status: status,
          timestamp: Time.current.iso8601
        }
        response[:details] = details if details.present?
        response
      end
    end
  end
end
