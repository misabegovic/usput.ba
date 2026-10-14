# Langfuse tracing for model calls (see LLMTracing). Tests configure it
# themselves, with an in-memory exporter, so the suite never exports.
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

Rails.application.config.after_initialize do
  LLMTracing.configure! unless Rails.env.test?
end
