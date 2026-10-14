# frozen_string_literal: true

require "test_helper"

module Ai
  class OpenaiQueueTest < ActiveJob::TestCase
    # An assistant reply as RubyLLM 2 returns it: structured output arrives as
    # a JSON string in content, read back through #parsed.
    def reply(content)
      RubyLLM::Message.new(role: :assistant, content: content, model: "gpt-6-luna")
    end

    # === Request method tests ===

    test "request returns parsed hash response when schema is provided" do
      response_content = { name: "Test", value: 123 }

      mock_response = reply(response_content.to_json)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal response_content.deep_symbolize_keys, result
      end
    end

    test "request returns string response when no schema is provided" do
      mock_response = reply("Plain text response")

      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          context: "Test"
        )

        assert_equal "Plain text response", result
      end
    end

    test "request returns nil when response is nil" do
      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) { |_prompt| nil }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          context: "Test"
        )

        assert_nil result
      end
    end

    test "request returns nil when response content is nil" do
      mock_response = reply(nil)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          context: "Test"
        )

        assert_nil result
      end
    end

    # === Model and cost (RubyLLM 2) ===

    test "GPT-6 Luna is in RubyLLM's registry with its prices" do
      model = RubyLLM.models.find("gpt-6-luna")
      tokens = RubyLLM::Tokens.new(input: 100_000, output: 100_000)

      # $0.10 in and $0.50 out per million tokens (OpenAI, 2026-10-14)
      assert_in_delta 0.06, RubyLLM::Cost.new(tokens: tokens, model: model).total, 0.0001
    end

    test "each call logs its model, tokens and cost" do
      response = reply("Plain text response")
      response.define_singleton_method(:tokens) { RubyLLM::Tokens.new(input: 1200, output: 300) }
      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) { |_prompt| response }
      logged = []

      Rails.logger.stub :info, ->(message) { logged << message } do
        RubyLLM.stub :chat, mock_chat do
          Ai::OpenaiQueue.request(prompt: "Test", context: "Describer")
        end
      end

      assert_includes logged, "[Describer] gpt-6-luna tokens in=1200 out=300 cost=$0.000270"
    end

    test "a reply without usage still returns its content" do
      response = reply("Plain text response")
      response.define_singleton_method(:cost) { raise "no pricing" }
      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) { |_prompt| response }

      RubyLLM.stub :chat, mock_chat do
        assert_equal "Plain text response", Ai::OpenaiQueue.request(prompt: "Test", context: "Test")
      end
    end

    # === Error handling tests ===

    test "request raises RateLimitError on RubyLLM::RateLimitError" do
      # RubyLLM 2 errors take the response as a keyword; its body is the message
      mock_response = Object.new
      mock_response.define_singleton_method(:body) { '{"error": {"message": "Rate limit exceeded"}}' }

      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) do |_prompt|
        raise RubyLLM::RateLimitError.new(response: mock_response)
      end

      RubyLLM.stub :chat, mock_chat do
        error = assert_raises(Ai::OpenaiQueue::RateLimitError) do
          Ai::OpenaiQueue.request(prompt: "Test", context: "Test")
        end

        assert_match(/Rate limit/, error.message)
      end
    end

    test "request raises RequestError on RubyLLM::Error" do
      # RubyLLM 2 errors take the response as a keyword; its body is the message
      mock_response = Object.new
      mock_response.define_singleton_method(:body) { '{"error": {"message": "API error"}}' }

      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) do |_prompt|
        raise RubyLLM::Error.new(response: mock_response)
      end

      RubyLLM.stub :chat, mock_chat do
        error = assert_raises(Ai::OpenaiQueue::RequestError) do
          Ai::OpenaiQueue.request(prompt: "Test", context: "Test")
        end

        assert_match(/API error/, error.message)
      end
    end

    test "request raises RequestError on StandardError" do
      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) do |_prompt|
        raise StandardError, "Unexpected error"
      end

      RubyLLM.stub :chat, mock_chat do
        error = assert_raises(Ai::OpenaiQueue::RequestError) do
          Ai::OpenaiQueue.request(prompt: "Test", context: "Test")
        end

        assert_match(/Unexpected error/, error.message)
      end
    end

    # === JSON parsing tests ===

    test "parses JSON from markdown code block" do
      json_content = "```json\n{\"name\": \"Test\", \"value\": 123}\n```"

      mock_response = reply(json_content)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ name: "Test", value: 123 }, result)
      end
    end

    test "parses raw JSON object" do
      json_content = '{"name": "Test", "items": ["a", "b"]}'

      mock_response = reply(json_content)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ name: "Test", items: %w[a b] }, result)
      end
    end

    test "sanitizes smart quotes in JSON" do
      # Curly quotes, as a model writing prose sometimes returns
      json_content = "{\u201Cname\u201D: \u201CTest\u201D}"

      mock_response = reply(json_content)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ name: "Test" }, result)
      end
    end

    test "handles trailing commas in JSON" do
      json_content = '{"name": "Test", "value": 1,}'

      mock_response = reply(json_content)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ name: "Test", value: 1 }, result)
      end
    end

    test "returns empty hash on invalid JSON" do
      json_content = "not valid json at all"

      mock_response = reply(json_content)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({}, result)
      end
    end

    # === Enqueue method tests ===

    test "enqueue creates OpenaiRequestJob" do
      assert_enqueued_with(job: OpenaiRequestJob, queue: "ai_generation") do
        Ai::OpenaiQueue.enqueue(
          prompt: "Test prompt",
          schema: { type: "object" },
          context: "TestContext",
          callback_class: "TestClass",
          callback_id: 123
        )
      end
    end

    test "enqueue passes all parameters to job" do
      assert_enqueued_with(
        job: OpenaiRequestJob,
        args: [ {
          prompt: "Test prompt",
          schema: { type: "object" },
          context: "TestContext",
          callback_class: "TestCallback",
          callback_id: 456
        } ]
      ) do
        Ai::OpenaiQueue.enqueue(
          prompt: "Test prompt",
          schema: { type: "object" },
          context: "TestContext",
          callback_class: "TestCallback",
          callback_id: 456
        )
      end
    end

    # === Error class hierarchy tests ===

    test "RateLimitError is a subclass of RequestError" do
      assert Ai::OpenaiQueue::RateLimitError < Ai::OpenaiQueue::RequestError
    end

    test "RequestError is a subclass of StandardError" do
      assert Ai::OpenaiQueue::RequestError < StandardError
    end

    test "GatewayError is a subclass of RequestError" do
      assert Ai::OpenaiQueue::GatewayError < Ai::OpenaiQueue::RequestError
    end

    test "SslError is a subclass of RequestError" do
      assert Ai::OpenaiQueue::SslError < Ai::OpenaiQueue::RequestError
    end

    # === Gateway error detection tests ===

    test "retries on gateway error in response content" do
      call_count = 0
      gateway_html = "<html><title>502 Bad Gateway</title></html>"
      good_response = { result: "success" }

      mock_response_bad = reply(gateway_html)

      mock_response_good = reply(good_response.to_json)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) do |_prompt|
        call_count += 1
        call_count == 1 ? mock_response_bad : mock_response_good
      end

      # Stub RubyLLM.chat before creating the queue instance
      RubyLLM.stub :chat, mock_chat do
        queue = Ai::OpenaiQueue.new

        # Skip actual sleep in tests
        queue.stub(:sleep, nil) do
          result = queue.execute_request(
            prompt: "Test",
            schema: { type: "object" },
            context: "Test"
          )

          assert_equal 2, call_count, "Should have retried once"
          assert_equal good_response.deep_symbolize_keys, result
        end
      end
    end

    test "gateway error detection identifies 502 Bad Gateway" do
      mock_chat = Minitest::Mock.new
      RubyLLM.stub :chat, mock_chat do
        queue = Ai::OpenaiQueue.new
        assert queue.send(:gateway_error_content?, "<html><title>502 Bad Gateway</title></html>")
      end
    end

    test "gateway error detection identifies 503 Service Unavailable" do
      mock_chat = Minitest::Mock.new
      RubyLLM.stub :chat, mock_chat do
        queue = Ai::OpenaiQueue.new
        assert queue.send(:gateway_error_content?, "<html><title>503 Service Unavailable</title></html>")
      end
    end

    test "gateway error detection identifies Cloudflare errors" do
      mock_chat = Minitest::Mock.new
      RubyLLM.stub :chat, mock_chat do
        queue = Ai::OpenaiQueue.new
        assert queue.send(:gateway_error_content?, "<html><body>Cloudflare Error</body></html>")
      end
    end

    test "gateway error detection returns false for normal content" do
      mock_chat = Minitest::Mock.new
      RubyLLM.stub :chat, mock_chat do
        queue = Ai::OpenaiQueue.new
        refute queue.send(:gateway_error_content?, '{"result": "success"}')
        refute queue.send(:gateway_error_content?, "Plain text response")
      end
    end

    # === SSL error handling tests ===

    test "retries on SSL error and succeeds on retry" do
      call_count = 0
      good_response = { result: "success" }

      mock_response_good = reply(good_response.to_json)

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) do |_prompt|
        call_count += 1
        if call_count == 1
          raise OpenSSL::SSL::SSLError, "SSL_read: unexpected eof while reading"
        end
        mock_response_good
      end

      RubyLLM.stub :chat, mock_chat do
        queue = Ai::OpenaiQueue.new

        queue.stub(:sleep, nil) do
          result = queue.execute_request(
            prompt: "Test",
            schema: { type: "object" },
            context: "Test"
          )

          assert_equal 2, call_count, "Should have retried once"
          assert_equal good_response.deep_symbolize_keys, result
        end
      end
    end

    test "raises SslError after max retries" do
      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) do |_prompt|
        raise OpenSSL::SSL::SSLError, "SSL_read: unexpected eof while reading"
      end

      RubyLLM.stub :chat, mock_chat do
        queue = Ai::OpenaiQueue.new

        queue.stub(:sleep, nil) do
          error = assert_raises(Ai::OpenaiQueue::SslError) do
            queue.execute_request(prompt: "Test", context: "Test")
          end

          assert_match(/SSL error/, error.message)
          assert_match(/unexpected eof/, error.message)
        end
      end
    end
  end
end
