# frozen_string_literal: true

require "base64"

# Traces every model call to Langfuse over OpenTelemetry. Langfuse runs
# self-hosted on Railway (decided 2026-09-30). RubyLLM opens one span per call
# with the GenAI attributes (model, tokens); this module points the exporter
# at Langfuse, adds each call's cost, and groups a service's calls under one
# trace named for it.
#
# With no Langfuse keys nothing is configured: the OpenTelemetry API stays a
# no-op, `trace` just runs its block, and no request waits on Langfuse.
# Prompts and replies are not sent; RubyLLM's spans carry no message content.
module LLMTracing
  TRACES_PATH = "/api/public/otel/v1/traces"
  SETTINGS = %i[public_key secret_key host].freeze

  class << self
    def enabled?
      SETTINGS.all? { |key| setting(key).present? }
    end

    def endpoint
      "#{setting(:host).chomp("/")}#{TRACES_PATH}"
    end

    def headers
      token = Base64.strict_encode64("#{setting(:public_key)}:#{setting(:secret_key)}")
      { "Authorization" => "Basic #{token}", "x-langfuse-ingestion-version" => "4" }
    end

    # Called once at boot. A test passes its own exporter.
    def configure!(exporter: nil)
      return false unless exporter || enabled?

      exporter ||= OpenTelemetry::Exporter::OTLP::Exporter.new(endpoint: endpoint, headers: headers)
      processor = if exporter.is_a?(OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter)
        OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)
      else
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
      end

      OpenTelemetry::SDK.configure do |c|
        c.service_name = "usput"
        c.add_span_processor(processor)
      end
      RubyLLM::OpenTelemetry.enable
      unless RubyLLM.config.instrumenter.is_a?(CostInstrumenter)
        RubyLLM.config.instrumenter = CostInstrumenter.new(RubyLLM.config.instrumenter)
      end
      @configured = true
    end

    def configured? = @configured == true

    # Undoes configure!, for tests.
    def reset!
      RubyLLM::OpenTelemetry.disable
      RubyLLM.config.instrumenter = RubyLLM.config.instrumenter.inner if RubyLLM.config.instrumenter.is_a?(CostInstrumenter)
      OpenTelemetry.tracer_provider.shutdown if OpenTelemetry.tracer_provider.respond_to?(:shutdown)
      OpenTelemetry.tracer_provider = OpenTelemetry::Trace::TracerProvider.new
      @configured = false
    end

    # Groups the model calls inside the block under one trace named for the
    # service. Metadata lands on the trace, where Langfuse can filter on it.
    def trace(name, **metadata, &block)
      attributes = { "langfuse.trace.name" => name.to_s, "langfuse.observation.type" => "chain" }
      metadata.each { |key, value| attributes["langfuse.trace.metadata.#{key}"] = value.to_s }
      OpenTelemetry.tracer_provider.tracer("usput").in_span(name.to_s, attributes: attributes, &block)
    end

    private

    # Rails credentials under `langfuse:`, with LANGFUSE_* environment
    # variables as the override.
    def setting(key)
      ENV["LANGFUSE_#{key.upcase}"].presence || Rails.application.credentials.dig(:langfuse, key)
    end
  end

  # Wraps RubyLLM's instrumenter (ActiveSupport::Notifications in Rails) and,
  # once a chat reply is in, puts its dollar cost on the span RubyLLM opened
  # for it, priced from RubyLLM's model registry. Langfuse reads
  # `gen_ai.usage.cost` as the generation's total cost. Never raises.
  class CostInstrumenter
    attr_reader :inner

    def initialize(inner)
      @inner = inner
    end

    def instrument(name, payload, &block)
      run = lambda do |event|
        result = block&.call(event)
        record_cost(payload) if name == "chat.ruby_llm"
        result
      end
      inner.respond_to?(:instrument) ? inner.instrument(name, payload, &run) : run.call(payload)
    end

    private

    def record_cost(payload)
      tokens = payload[:response_tokens]
      model = payload[:model_info]
      return unless tokens && model

      cost = RubyLLM::Cost.new(tokens: tokens, model: model).total
      OpenTelemetry::Trace.current_span.set_attribute("gen_ai.usage.cost", cost.to_f) if cost
    rescue StandardError => e
      Rails.logger.debug "[LLMTracing] cost not recorded: #{e.class}"
    end
  end
end
