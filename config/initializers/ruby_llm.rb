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

  # Request timeout in seconds (default: 180s for complex enrichment prompts)
  config.request_timeout = ENV.fetch("LLM_REQUEST_TIMEOUT", 180).to_i
end
