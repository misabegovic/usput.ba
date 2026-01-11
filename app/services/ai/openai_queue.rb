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
  # Additional retry logic is implemented for:
  # - Gateway errors (502, 503, 504) that come through as HTML content from
  #   CDNs like Cloudflare, which the Faraday middleware doesn't catch
  # - Network timeout errors (Net::ReadTimeout, Net::OpenTimeout) with
  #   3 retries and exponential backoff (10s, 20s, 40s delays)
  # - SSL errors (OpenSSL::SSL::SSLError) such as unexpected EOF or connection
  #   reset, with 3 retries and exponential backoff (5s, 10s, 20s delays)
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
    class GatewayError < RequestError; end
    class TimeoutError < RequestError; end
    class SslError < RequestError; end

    # Gateway error patterns in HTML responses from CDNs like Cloudflare
    GATEWAY_ERROR_PATTERNS = [
      /502\s*Bad\s*Gateway/i,
      /503\s*Service\s*(Temporarily\s*)?Unavailable/i,
      /504\s*Gateway\s*Time[- ]?out/i,
      /<title>[^<]*(?:502|503|504)[^<]*<\/title>/i,
      /cloudflare/i
    ].freeze

    # Retry configuration for gateway errors
    GATEWAY_RETRY_ATTEMPTS = 3
    GATEWAY_RETRY_BASE_DELAY = 5 # seconds

    # Retry configuration for network timeout errors
    TIMEOUT_RETRY_ATTEMPTS = 3
    TIMEOUT_RETRY_BASE_DELAY = 10 # seconds (longer than gateway since timeouts indicate slow responses)

    # Retry configuration for SSL errors (connection reset, unexpected EOF, etc.)
    SSL_RETRY_ATTEMPTS = 3
    SSL_RETRY_BASE_DELAY = 5 # seconds

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
    # Additional retry logic for gateway errors from CDNs
    def execute_request(prompt:, schema: nil, context: "OpenaiQueue")
      attempt = 0

      begin
        attempt += 1
        response = if schema
          @chat.with_schema(schema).ask(prompt)
        else
          @chat.ask(prompt)
        end

        # Check for gateway errors in the response content
        check_for_gateway_error_in_response(response)

        parse_response(response, schema)
      rescue GatewayError => e
        if attempt < GATEWAY_RETRY_ATTEMPTS
          delay = GATEWAY_RETRY_BASE_DELAY * (2**(attempt - 1))
          Rails.logger.warn "[#{context}] Gateway error (attempt #{attempt}/#{GATEWAY_RETRY_ATTEMPTS}), retrying in #{delay}s: #{e.message}"
          sleep(delay)
          retry
        end
        log_error "[#{context}] Gateway error after #{GATEWAY_RETRY_ATTEMPTS} attempts: #{e.message}"
        raise RequestError, "Gateway error: #{e.message}"
      rescue RubyLLM::RateLimitError => e
        # RubyLLM already retried - if we're here, all retries failed
        log_error "[#{context}] Rate limit exceeded after retries: #{e.message}"
        raise RateLimitError, "Rate limit exceeded: #{e.message}"
      rescue RubyLLM::Error => e
        # Check if the error message contains gateway error HTML
        if gateway_error_content?(e.message) && attempt < GATEWAY_RETRY_ATTEMPTS
          delay = GATEWAY_RETRY_BASE_DELAY * (2**(attempt - 1))
          Rails.logger.warn "[#{context}] Gateway error in exception (attempt #{attempt}/#{GATEWAY_RETRY_ATTEMPTS}), retrying in #{delay}s"
          sleep(delay)
          retry
        end
        log_error "[#{context}] API error: #{e.message}"
        raise RequestError, e.message
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        # Network timeout errors - retry with exponential backoff
        if attempt < TIMEOUT_RETRY_ATTEMPTS
          delay = TIMEOUT_RETRY_BASE_DELAY * (2**(attempt - 1))
          Rails.logger.warn "[#{context}] Network timeout (attempt #{attempt}/#{TIMEOUT_RETRY_ATTEMPTS}), retrying in #{delay}s: #{e.class.name}"
          sleep(delay)
          retry
        end
        log_error "[#{context}] Network timeout after #{TIMEOUT_RETRY_ATTEMPTS} attempts: #{e.message}"
        raise TimeoutError, "Network timeout: #{e.message}"
      rescue OpenSSL::SSL::SSLError => e
        # SSL errors (unexpected EOF, connection reset, etc.) - retry with exponential backoff
        if attempt < SSL_RETRY_ATTEMPTS
          delay = SSL_RETRY_BASE_DELAY * (2**(attempt - 1))
          Rails.logger.warn "[#{context}] SSL error (attempt #{attempt}/#{SSL_RETRY_ATTEMPTS}), retrying in #{delay}s: #{e.message}"
          sleep(delay)
          retry
        end
        log_error "[#{context}] SSL error after #{SSL_RETRY_ATTEMPTS} attempts: #{e.message}"
        raise SslError, "SSL error: #{e.message}"
      rescue StandardError => e
        # Check if the error message contains gateway error HTML
        if gateway_error_content?(e.message) && attempt < GATEWAY_RETRY_ATTEMPTS
          delay = GATEWAY_RETRY_BASE_DELAY * (2**(attempt - 1))
          Rails.logger.warn "[#{context}] Gateway error in exception (attempt #{attempt}/#{GATEWAY_RETRY_ATTEMPTS}), retrying in #{delay}s"
          sleep(delay)
          retry
        end
        log_error "[#{context}] Request failed: #{e.message}"
        raise RequestError, e.message
      end
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

    # Check if response content contains gateway error HTML from CDNs
    def check_for_gateway_error_in_response(response)
      return if response.nil?

      content = response.content.to_s
      return if content.blank?

      if gateway_error_content?(content)
        raise GatewayError, extract_gateway_error_type(content)
      end
    end

    # Check if content contains gateway error patterns
    def gateway_error_content?(content)
      return false if content.blank?

      # Quick check: must contain HTML markers
      return false unless content.include?("<") && content.include?(">")

      GATEWAY_ERROR_PATTERNS.any? { |pattern| content.match?(pattern) }
    end

    # Extract the type of gateway error from HTML content
    def extract_gateway_error_type(content)
      case content
      when /502/i then "502 Bad Gateway"
      when /503/i then "503 Service Unavailable"
      when /504/i then "504 Gateway Timeout"
      else "Gateway Error"
      end
    end

    def log_error(message)
      Rails.logger.error message
      Rollbar.error(message) if defined?(Rollbar)
    end
  end
end
