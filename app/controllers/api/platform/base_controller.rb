# frozen_string_literal: true

module API
  module Platform
    # Base controller for Platform API
    #
    # Provides authentication and common functionality for all Platform API endpoints.
    # Authentication is via API key in the Authorization header.
    #
    # @example Request with API key
    #   curl -H "Authorization: Bearer YOUR_API_KEY" https://api.usput.ba/platform/chat
    #
    class BaseController < ActionController::API
      before_action :authenticate_api_key!

      # Order matters: Rails checks rescue_from in reverse order (last defined wins)
      # So StandardError must be FIRST, specific errors AFTER
      rescue_from StandardError, with: :handle_standard_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from ::Platform::DSL::ParseError, with: :handle_parse_error
      rescue_from ::Platform::DSL::ExecutionError, with: :handle_execution_error

      private

      def authenticate_api_key!
        api_key = extract_api_key
        return if valid_api_key?(api_key)

        render json: {
          error: "Unauthorized",
          message: "Invalid or missing API key"
        }, status: :unauthorized
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

      def handle_execution_error(error)
        render json: {
          error: "ExecutionError",
          message: error.message
        }, status: :unprocessable_entity
      end

      def handle_parse_error(error)
        render json: {
          error: "ParseError",
          message: error.message
        }, status: :bad_request
      end

      def handle_not_found(error)
        render json: {
          error: "NotFound",
          message: error.message
        }, status: :not_found
      end

      def handle_standard_error(error)
        Rails.logger.error "Platform API Error: #{error.message}\n#{error.backtrace.first(10).join("\n")}"

        render json: {
          error: "InternalError",
          message: Rails.env.production? ? "An unexpected error occurred" : error.message
        }, status: :internal_server_error
      end
    end
  end
end
