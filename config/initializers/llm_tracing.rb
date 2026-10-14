# Langfuse tracing for model calls (see LlmTracing). Tests configure it
# themselves, with an in-memory exporter, so the suite never exports.
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

Rails.application.config.after_initialize do
  LlmTracing.configure! unless Rails.env.test?
end
