# RubyLLM Configuration
# https://rubyllm.com/

RubyLLM.configure do |config|
  # OpenAI API key for GPT models
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)

  # Anthropic API key for Claude models (preferred)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)

  # Google AI API key for Gemini models
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)

  # Default model to use
  # Options: "gpt-4o-mini", "claude-sonnet-4-20250514", "gemini-2.0-flash", etc.
  config.default_model = ENV.fetch("LLM_DEFAULT_MODEL", "gpt-4o-mini")

  # Request timeout in seconds
  # Increased to 300s (5 min) for complex AI proposals with structured output
  # (e.g., multi-language experience descriptions with JSON schema)
  config.request_timeout = ENV.fetch("LLM_REQUEST_TIMEOUT", 300).to_i

  # Retry configuration for rate limits (429) and transient failures
  # RubyLLM uses Faraday retry middleware which automatically retries on:
  # - 429 (rate limit), 500, 502, 503, 504, 529 status codes
  # - Network errors (timeout, connection failed, etc.)
  #
  # With these settings and rate limit errors:
  # - Attempt 1: immediate
  # - Attempt 2: wait ~5s (5 * 2^0 + randomness)
  # - Attempt 3: wait ~10s (5 * 2^1 + randomness)
  # - Attempt 4: wait ~20s (5 * 2^2 + randomness)
  # - Attempt 5: wait ~40s (5 * 2^3 + randomness)
  # Total max wait: ~75s before giving up
  config.max_retries = ENV.fetch("LLM_MAX_RETRIES", 5).to_i
  config.retry_interval = ENV.fetch("LLM_RETRY_INTERVAL", 5.0).to_f
  config.retry_backoff_factor = ENV.fetch("LLM_RETRY_BACKOFF_FACTOR", 2.0).to_f
  config.retry_interval_randomness = ENV.fetch("LLM_RETRY_RANDOMNESS", 0.5).to_f
end
