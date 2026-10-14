# RubyLLM Configuration
# https://rubyllm.com/

RubyLLM.configure do |config|
  # Content generation runs on OpenAI (decided 2026-09-30). The other keys stay
  # optional so a model from another provider can be named per call.
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)

  # Jev, TypeSafe's decision model, screens reviews (ReviewModeration). With no
  # key, reviews are not screened and nothing breaks.
  config.typesafe_api_key = ENV["TYPESAFE_API_KEY"].presence || Rails.application.credentials.dig(:typesafe, :api_key)

  # GPT-6 Luna, OpenAI's low-cost tier ($0.10 in, $0.50 out per million tokens
  # on 2026-10-14; it replaced gpt-4o-mini at $0.15 and $0.60). RubyLLM's model
  # registry carries its prices, so every reply reports its cost.
  config.default_model = ENV.fetch("LLM_DEFAULT_MODEL", "gpt-6-luna")

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
  # - Attempt 5: wait ~30s (capped by retry_max_interval)
  config.max_retries = ENV.fetch("LLM_MAX_RETRIES", 5).to_i
  config.retry_interval = ENV.fetch("LLM_RETRY_INTERVAL", 5.0).to_f
  config.retry_backoff_factor = ENV.fetch("LLM_RETRY_BACKOFF_FACTOR", 2.0).to_f
  config.retry_interval_randomness = ENV.fetch("LLM_RETRY_RANDOMNESS", 0.5).to_f
end
