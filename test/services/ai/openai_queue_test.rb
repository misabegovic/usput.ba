# frozen_string_literal: true

require "test_helper"

module Ai
  class OpenaiQueueTest < ActiveSupport::TestCase
    setup do
      @mock_chat = Minitest::Mock.new
      @mock_response = Minitest::Mock.new
    end

    # === Request method tests ===

    test "request returns parsed hash response when schema is provided" do
      response_content = { name: "Test", value: 123 }
      @mock_response.expect :nil?, false
      @mock_response.expect :content, response_content
      @mock_response.expect :content, response_content

      @mock_chat.expect :with_schema, @mock_chat, [Hash]
      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal response_content, result
      end
    end

    test "request returns string response when no schema is provided" do
      @mock_response.expect :nil?, false
      @mock_response.expect :content, "Plain text response"
      @mock_response.expect :content, "Plain text response"

      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          context: "Test"
        )

        assert_equal "Plain text response", result
      end
    end

    test "request returns nil when response is nil" do
      @mock_chat.expect :ask, nil, [String]

      RubyLLM.stub :chat, @mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          context: "Test"
        )

        assert_nil result
      end
    end

    test "request returns nil when response content is nil" do
      @mock_response.expect :nil?, false
      @mock_response.expect :content, nil

      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test prompt",
          context: "Test"
        )

        assert_nil result
      end
    end

    # === Error handling tests ===

    test "request raises RateLimitError on RubyLLM::RateLimitError" do
      mock_chat = Object.new
      def mock_chat.ask(*)
        raise RubyLLM::RateLimitError, "Rate limit exceeded"
      end

      RubyLLM.stub :chat, mock_chat do
        error = assert_raises(Ai::OpenaiQueue::RateLimitError) do
          Ai::OpenaiQueue.request(prompt: "Test", context: "Test")
        end

        assert_match(/Rate limit exceeded/, error.message)
      end
    end

    test "request raises RequestError on RubyLLM::Error" do
      mock_chat = Object.new
      def mock_chat.ask(*)
        raise RubyLLM::Error, "API error"
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
      def mock_chat.ask(*)
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
      json_content = '```json
{"name": "Test", "value": 123}
```'
      @mock_response.expect :nil?, false
      @mock_response.expect :content, json_content
      @mock_response.expect :content, json_content

      @mock_chat.expect :with_schema, @mock_chat, [Hash]
      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
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
      @mock_response.expect :nil?, false
      @mock_response.expect :content, json_content
      @mock_response.expect :content, json_content

      @mock_chat.expect :with_schema, @mock_chat, [Hash]
      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
        result = Ai::OpenaiQueue.request(
          prompt: "Test",
          schema: { type: "object" },
          context: "Test"
        )

        assert_equal({ name: "Test", items: ["a", "b"] }, result)
      end
    end

    test "sanitizes smart quotes in JSON" do
      json_content = '{"name": "Test"}'  # Using smart quotes
      @mock_response.expect :nil?, false
      @mock_response.expect :content, json_content
      @mock_response.expect :content, json_content

      @mock_chat.expect :with_schema, @mock_chat, [Hash]
      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
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
      @mock_response.expect :nil?, false
      @mock_response.expect :content, json_content
      @mock_response.expect :content, json_content

      @mock_chat.expect :with_schema, @mock_chat, [Hash]
      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
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
      @mock_response.expect :nil?, false
      @mock_response.expect :content, json_content
      @mock_response.expect :content, json_content

      @mock_chat.expect :with_schema, @mock_chat, [Hash]
      @mock_chat.expect :ask, @mock_response, [String]

      RubyLLM.stub :chat, @mock_chat do
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
  end
end
