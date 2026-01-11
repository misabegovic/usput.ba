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
      # Final cleanup: strip any trailing comma that might remain after sanitization
      json_str = json_str.strip.sub(/,\s*\z/, '')

      begin
        JSON.parse(json_str, symbolize_names: true)
      rescue JSON::ParserError => e
        # Attempt to repair incomplete JSON (e.g., truncated responses)
        repaired_json = attempt_json_repair(json_str)
        if repaired_json
          begin
            return JSON.parse(repaired_json, symbolize_names: true)
          rescue JSON::ParserError
            # Repair didn't help, fall through to error logging
          end
        end

        log_error "Failed to parse AI response: #{e.message}", content: content.to_s.truncate(500)
        {}
      end
    end

    def sanitize_ai_json(json_str)
      json_str = json_str.dup
      # Replace smart/curly quotes with straight quotes
      json_str.gsub!(/[""]/, '"')
      json_str.gsub!(/['']/, "'")
      # Remove trailing commas (invalid JSON but common in AI output)
      json_str.gsub!(/,(\s*[\}\]])/, '\1')
      # Remove trailing comma at end of stream (e.g., "{ ... },\n" or "{ ... }, ")
      json_str.gsub!(/,\s*\z/, '')
      # Escape control characters and fix structural issues within JSON strings
      json_str = escape_chars_in_json_strings(json_str)
      json_str
    end

    # Attempt to repair incomplete JSON that was truncated (EOF error)
    # Returns repaired JSON string or nil if repair isn't possible
    def attempt_json_repair(json_str)
      return nil if json_str.blank?

      # Count unclosed braces and brackets
      open_braces = 0
      open_brackets = 0
      in_string = false
      escape_next = false

      json_str.each_char do |char|
        if escape_next
          escape_next = false
          next
        end

        case char
        when '\\'
          escape_next = true if in_string
        when '"'
          in_string = !in_string unless escape_next
        when '{'
          open_braces += 1 unless in_string
        when '}'
          open_braces -= 1 unless in_string
        when '['
          open_brackets += 1 unless in_string
        when ']'
          open_brackets -= 1 unless in_string
        end
      end

      # If we're in the middle of a string, try to close it
      repaired = json_str.dup
      if in_string
        # Remove incomplete string content back to the last complete field
        # This handles cases like: {"key": "incomplete value...
        repaired = repaired.sub(/,?\s*"[^"]*\z/, '')
        # Recount after the repair
        open_braces = 0
        open_brackets = 0
        in_string = false
        escape_next = false

        repaired.each_char do |char|
          if escape_next
            escape_next = false
            next
          end

          case char
          when '\\'
            escape_next = true if in_string
          when '"'
            in_string = !in_string unless escape_next
          when '{'
            open_braces += 1 unless in_string
          when '}'
            open_braces -= 1 unless in_string
          when '['
            open_brackets += 1 unless in_string
          when ']'
            open_brackets -= 1 unless in_string
          end
        end
      end

      # If there are unclosed structures, add closing characters
      return nil if open_braces < 0 || open_brackets < 0 # Malformed, can't repair

      # Remove any trailing comma before closing
      repaired = repaired.sub(/,\s*\z/, '')

      # Add closing brackets and braces as needed
      repaired += ']' * open_brackets if open_brackets > 0
      repaired += '}' * open_braces if open_braces > 0

      # Only return if we actually made repairs and result differs from input
      repaired != json_str ? repaired : nil
    end

    # Escapes problematic characters that appear within JSON string values
    # This handles cases where the AI includes literal newlines, unescaped
    # quotes, or other control characters in text content
    def escape_chars_in_json_strings(json_str)
      result = []
      in_string = false
      escape_next = false
      i = 0

      while i < json_str.length
        char = json_str[i]
        next_char = json_str[i + 1]

        if escape_next
          result << char
          escape_next = false
        elsif char == '\\'
          if in_string
            # Check if this backslash is followed by a valid JSON escape character
            if next_char && '"\\/bfnrtu'.include?(next_char)
              result << char
              escape_next = true
            else
              # Invalid escape sequence - escape the backslash itself
              result << '\\\\'
            end
          else
            result << char
            escape_next = true
          end
        elsif char == '"'
          if in_string
            # Check if this quote might be inside a string value (not ending it)
            # Look ahead to see if this looks like a premature string end
            if looks_like_embedded_quote?(json_str, i)
              result << '\\"'
            else
              result << char
              in_string = false
            end
          else
            result << char
            in_string = true
          end
        elsif in_string
          # Handle control characters within strings
          case char
          when "\n"
            result << '\\n'
          when "\r"
            result << '\\r'
          when "\t"
            result << '\\t'
          when "\f"
            result << '\\f'
          when "\b"
            result << '\\b'
          else
            # Escape any other control characters (0x00-0x1F)
            if char.ord < 32
              result << format('\\u%04x', char.ord)
            else
              result << char
            end
          end
        else
          result << char
        end

        i += 1
      end

      result.join
    end

    # Heuristic to detect if a quote inside a string is likely an embedded quote
    # rather than the actual end of the string value
    def looks_like_embedded_quote?(json_str, pos)
      return false if pos + 1 >= json_str.length

      remaining = json_str[(pos + 1)..-1]

      # If immediately followed by valid JSON structure, it's probably a real end quote
      return false if remaining.match?(/\A\s*[,\}\]:]/m)

      # If followed by a key pattern like `"key":`, it's probably a real end quote
      return false if remaining.match?(/\A\s*,?\s*"[^"]+"\s*:/m)

      # If followed by array/object closing, it's probably a real end quote
      return false if remaining.match?(/\A\s*[\}\]]/m)

      # Otherwise, this quote is likely embedded in text content
      # Look for patterns that suggest continuation of text
      remaining.match?(/\A[a-zA-Z0-9\s,.'!?;:\-]/m)
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

    def log_error(message, content: nil)
      full_message = content ? "#{message} | Content preview: #{content}" : message
      Rails.logger.error full_message
      Rollbar.error(message, content_preview: content) if defined?(Rollbar)
    end
  end
end
