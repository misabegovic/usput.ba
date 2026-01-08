# frozen_string_literal: true

module Ai
  # Thin wrapper around RubyLLM for OpenAI API requests
  # Provides centralized error handling and logging
  #
  # Rate limiting is handled by RubyLLM's built-in Faraday retry middleware:
  # - Automatically retries on 429 (rate limit) status codes
  # - Uses exponential backoff (configured in config/initializers/ruby_llm.rb)
  # - Also retries on 500, 502, 503, 504, 529 and network errors
  #
  # Usage:
  #   result = Ai::OpenaiQueue.request(
  #     prompt: "Your prompt",
  #     schema: { type: "object", ... },
  #     context: "PlanCreator"
  #   )
  class OpenaiQueue
    include Concerns::ErrorReporting

    class RequestError < StandardError; end
    class RateLimitError < RequestError; end

    class << self
      # Synchronous request with automatic rate limiting (via RubyLLM)
      # @param prompt [String] The prompt to send
      # @param schema [Hash, nil] Optional JSON schema for structured output
      # @param context [String] Context for logging (e.g., "PlanCreator")
      # @return [Hash, String, nil] Parsed response or nil on failure
      def request(prompt:, schema: nil, context: "OpenaiQueue")
        new.execute_request(prompt: prompt, schema: schema, context: context)
      end

      # Queue a request for background processing (async)
      # @return [String] Job ID
      def enqueue(prompt:, schema: nil, context: "OpenaiQueue", callback_class: nil, callback_id: nil)
        OpenaiRequestJob.perform_later(
          prompt: prompt,
          schema: schema,
          context: context,
          callback_class: callback_class,
          callback_id: callback_id
        )
      end
    end

    def initialize
      @chat = RubyLLM.chat
    end

    # Execute a request - RubyLLM handles retries internally
    def execute_request(prompt:, schema: nil, context: "OpenaiQueue")
      response = if schema
        @chat.with_schema(schema).ask(prompt)
      else
        @chat.ask(prompt)
      end

      parse_response(response, schema)
    rescue RubyLLM::RateLimitError => e
      # RubyLLM already retried - if we're here, all retries failed
      log_error "[#{context}] Rate limit exceeded after retries: #{e.message}"
      raise RateLimitError, "Rate limit exceeded: #{e.message}"
    rescue RubyLLM::Error => e
      log_error "[#{context}] API error: #{e.message}"
      raise RequestError, e.message
    rescue StandardError => e
      log_error "[#{context}] Request failed: #{e.message}"
      raise RequestError, e.message
    end

    private

    def parse_response(response, schema)
      return nil if response.nil? || response.content.nil?

      if response.content.is_a?(Hash)
        response.content.deep_symbolize_keys
      elsif schema.nil?
        # No schema means we expect plain text, return as-is
        response.content
      else
        parse_ai_json_response(response.content)
      end
    end

    def parse_ai_json_response(content)
      return {} if content.blank?

      json_match = content.match(/```(?:json)?\s*([\s\S]*?)```/) ||
                   content.match(/(\{[\s\S]*\})/)
      json_str = json_match ? json_match[1] : content
      json_str = sanitize_ai_json(json_str)
      JSON.parse(json_str, symbolize_names: true)
    rescue JSON::ParserError => e
      log_error "Failed to parse AI response: #{e.message}"
      {}
    end

    def sanitize_ai_json(json_str)
      json_str = json_str.dup
      json_str.gsub!(/[""]/, '"')
      json_str.gsub!(/['']/, "'")
      json_str.gsub!(/,(\s*[\}\]])/, '\1')
      json_str
    end

    def log_error(message)
      Rails.logger.error message
      Rollbar.error(message) if defined?(Rollbar)
    end
  end
end
