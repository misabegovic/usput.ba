# frozen_string_literal: true

require_relative "base_controller"

module API
  module Platform
    # ChatController - Execute Platform DSL commands via API
    #
    # Provides REST API for executing DSL queries and managing conversations.
    #
    # @example Execute a DSL query
    #   POST /api/platform/chat
    #   { "query": "locations { city: \"Mostar\" } | count" }
    #
    # @example Send a natural language message (uses Brain)
    #   POST /api/platform/chat
    #   { "message": "How many locations are in Mostar?" }
    #
    class ChatController < BaseController
      # POST /api/platform/chat
      #
      # Execute a DSL query or natural language message
      #
      # @param query [String] DSL query to execute directly
      # @param message [String] Natural language message (requires Brain)
      # @param conversation_id [String] Optional conversation ID for context
      #
      # @return [JSON] Query result or error
      def create
        if params[:query].present?
          execute_dsl_query
        elsif params[:message].present?
          execute_natural_language
        else
          render json: {
            error: "BadRequest",
            message: "Either 'query' or 'message' parameter is required"
          }, status: :bad_request
        end
      end

      # POST /api/platform/execute
      #
      # Execute a DSL query directly (alias for create with query)
      def execute
        unless params[:query].present?
          return render json: {
            error: "BadRequest",
            message: "'query' parameter is required"
          }, status: :bad_request
        end

        execute_dsl_query
      end

      # GET /api/platform/parse
      #
      # Parse a DSL query and return the AST (for debugging)
      def parse
        unless params[:query].present?
          return render json: {
            error: "BadRequest",
            message: "'query' parameter is required"
          }, status: :bad_request
        end

        ast = ::Platform::DSL::Parser.parse(params[:query])

        render json: {
          success: true,
          query: params[:query],
          ast: ast
        }
      end

      private

      def execute_dsl_query
        query = params[:query]
        result = ::Platform::DSL.execute(query)

        # Log the API call
        log_api_call(query, result)

        render json: {
          success: true,
          query: query,
          result: result
        }
      end

      def execute_natural_language
        message = params[:message]
        conversation_id = params[:conversation_id]

        # Try to use Brain for natural language processing
        if defined?(::Platform::Brain)
          brain = ::Platform::Brain.new(conversation_id: conversation_id)
          response = brain.process(message)

          render json: {
            success: true,
            message: message,
            response: response[:text],
            dsl_queries: response[:dsl_queries],
            conversation_id: response[:conversation_id]
          }
        else
          render json: {
            error: "NotImplemented",
            message: "Natural language processing requires Platform::Brain"
          }, status: :not_implemented
        end
      end

      def log_api_call(query, result)
        PlatformAuditLog.create(
          action: "create",
          record_type: "ApiCall",
          record_id: 0,
          change_data: {
            query: query.truncate(500),
            result_action: result[:action],
            timestamp: Time.current.iso8601
          },
          triggered_by: "platform_api"
        )
      rescue => e
        Rails.logger.warn "Failed to log API call: #{e.message}"
      end
    end
  end
end
