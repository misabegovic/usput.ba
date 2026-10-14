# frozen_string_literal: true

require "test_helper"

class LlmTracingTest < ActiveSupport::TestCase
  KEYS = %w[LANGFUSE_PUBLIC_KEY LANGFUSE_SECRET_KEY LANGFUSE_HOST].freeze

  setup do
    @saved_env = KEYS.to_h { |key| [ key, ENV.delete(key) ] }
  end

  teardown do
    LlmTracing.reset! if LlmTracing.configured?
    @saved_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "with no Langfuse keys tracing stays off and a trace still runs its block" do
    assert_not LlmTracing.enabled?
    assert_not LlmTracing.configure!

    assert_equal 42, LlmTracing.trace("Describer") { 42 }
  end

  test "spans go to the Langfuse host's OTLP endpoint with the key pair" do
    ENV["LANGFUSE_PUBLIC_KEY"] = "pk-lf-test"
    ENV["LANGFUSE_SECRET_KEY"] = "sk-lf-test"
    ENV["LANGFUSE_HOST"] = "https://langfuse.example.railway.app/"

    assert LlmTracing.enabled?
    assert_equal "https://langfuse.example.railway.app/api/public/otel/v1/traces", LlmTracing.endpoint
    assert_equal "Basic #{Base64.strict_encode64("pk-lf-test:sk-lf-test")}", LlmTracing.headers["Authorization"]
  end

  test "a model call is a span with its model, tokens and cost inside the service's trace" do
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    LlmTracing.configure!(exporter: exporter)
    model = RubyLLM.models.find("gpt-6-luna")

    LlmTracing.trace("Describer", location: "abc") do
      # The event RubyLLM::Chat raises around each completion
      RubyLLM.instrument("chat.ruby_llm", { provider: "openai", model: model.id, model_info: model }) do |event|
        event[:response_tokens] = RubyLLM::Tokens.new(input: 100_000, output: 100_000)
        event[:tokens] = event[:response_tokens]
      end
    end

    spans = exporter.finished_spans
    call = spans.find { |span| span.attributes["gen_ai.request.model"] == "gpt-6-luna" }
    service = spans.find { |span| span.name == "Describer" }

    assert call, "expected RubyLLM's span for the call"
    assert_equal 100_000, call.attributes["gen_ai.usage.output_tokens"]
    assert_in_delta 0.06, call.attributes["gen_ai.usage.cost"], 0.0001
    assert_equal service.span_id, call.parent_span_id
    assert_equal "Describer", service.attributes["langfuse.trace.name"]
    assert_equal "abc", service.attributes["langfuse.trace.metadata.location"]
  end

  test "tracing keeps Rails' own instrumenter in the chain" do
    LlmTracing.configure!(exporter: OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new)
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("chat.ruby_llm") { |*args| events << args }

    RubyLLM.instrument("chat.ruby_llm", { provider: "openai", model: "gpt-6-luna" }) { :done }

    assert_equal 1, events.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
