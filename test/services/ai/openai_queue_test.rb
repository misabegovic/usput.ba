# frozen_string_literal: true

require "test_helper"

module Ai
  class OpenaiQueueTest < ActiveJob::TestCase
    # === Request method tests ===

    test "request returns parsed hash response when schema is provided" do
      response_content = { name: "Test", value: 123 }

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { response_content }

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
      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { "Plain text response" }

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
      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { nil }

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

    # === Error handling tests ===

    test "request raises RateLimitError on RubyLLM::RateLimitError" do
      # RubyLLM errors expect a response object with a body method
      mock_response = Object.new
      mock_response.define_singleton_method(:body) { '{"error": {"message": "Rate limit exceeded"}}' }

      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) do |_prompt|
        raise RubyLLM::RateLimitError.new(mock_response)
      end

      RubyLLM.stub :chat, mock_chat do
        error = assert_raises(Ai::OpenaiQueue::RateLimitError) do
          Ai::OpenaiQueue.request(prompt: "Test", context: "Test")
        end

        assert_match(/Rate limit/, error.message)
      end
    end

    test "request raises RequestError on RubyLLM::Error" do
      # RubyLLM errors expect a response object with a body method
      mock_response = Object.new
      mock_response.define_singleton_method(:body) { '{"error": {"message": "API error"}}' }

      mock_chat = Object.new
      mock_chat.define_singleton_method(:ask) do |_prompt|
        raise RubyLLM::Error.new(mock_response)
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

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

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

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

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
      # Using smart quotes that should be converted to regular quotes
      json_content = '{"name": "Test"}'

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

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

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

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

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

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

    test "repairs incomplete JSON with missing closing braces" do
      # Simulates truncated AI response (EOF error)
      json_content = '{"name": "Test", "nested": {"inner": "value"'

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ name: "Test", nested: { inner: "value" } }, result)
      end
    end

    test "repairs incomplete JSON with missing closing bracket" do
      json_content = '{"items": [1, 2, 3'

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ items: [1, 2, 3] }, result)
      end
    end

    test "handles control characters in JSON strings" do
      # JSON with literal newlines and tabs that should be escaped
      json_content = "{\"name\": \"Test\nwith\nnewlines\"}"

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

      mock_chat = Object.new
      mock_chat.define_singleton_method(:with_schema) { |_schema| self }
      mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

      RubyLLM.stub :chat, mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ name: "Test\nwith\nnewlines" }, result)
      end
    end

    test "handles trailing comma at end of JSON stream" do
      json_content = '{"name": "Test", "value": 1},'

      mock_response = Object.new
      mock_response.define_singleton_method(:nil?) { false }
      mock_response.define_singleton_method(:content) { json_content }

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
        args: [{
          prompt: "Test prompt",
          schema: { type: "object" },
          context: "TestContext",
          callback_class: "TestCallback",
          callback_id: 456
        }]
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

      mock_response_bad = Object.new
      mock_response_bad.define_singleton_method(:nil?) { false }
      mock_response_bad.define_singleton_method(:content) { gateway_html }

      mock_response_good = Object.new
      mock_response_good.define_singleton_method(:nil?) { false }
      mock_response_good.define_singleton_method(:content) { good_response }

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
      queue = Ai::OpenaiQueue.new
      assert queue.send(:gateway_error_content?, "<html><title>502 Bad Gateway</title></html>")
    end

    test "gateway error detection identifies 503 Service Unavailable" do
      queue = Ai::OpenaiQueue.new
      assert queue.send(:gateway_error_content?, "<html><title>503 Service Unavailable</title></html>")
    end

    test "gateway error detection identifies Cloudflare errors" do
      queue = Ai::OpenaiQueue.new
      assert queue.send(:gateway_error_content?, "<html><body>Cloudflare Error</body></html>")
    end

    test "gateway error detection returns false for normal content" do
      queue = Ai::OpenaiQueue.new
      refute queue.send(:gateway_error_content?, '{"result": "success"}')
      refute queue.send(:gateway_error_content?, "Plain text response")
    end

    # === SSL error handling tests ===

    test "retries on SSL error and succeeds on retry" do
      call_count = 0
      good_response = { result: "success" }

      mock_response_good = Object.new
      mock_response_good.define_singleton_method(:nil?) { false }
      mock_response_good.define_singleton_method(:content) { good_response }

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
