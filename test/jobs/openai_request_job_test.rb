# frozen_string_literal: true

require "test_helper"

class OpenaiRequestJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", OpenaiRequestJob.new.queue_name
  end

  test "job is enqueued to correct queue" do
    assert_enqueued_with(job: OpenaiRequestJob, queue: "ai_generation") do
      OpenaiRequestJob.perform_later(prompt: "Test", context: "Test")
    end
  end

  # === Successful execution tests ===

  test "perform calls OpenaiQueue.request with correct parameters" do
    called_with = nil

    Ai::OpenaiQueue.stub :request, ->(prompt:, schema:, context:) {
      called_with = { prompt: prompt, schema: schema, context: context }
      { result: "success" }
    } do
      OpenaiRequestJob.perform_now(
        prompt: "Test prompt",
        schema: { type: "object" },
        context: "TestContext"
      )
    end

    assert_equal "Test prompt", called_with[:prompt]
    assert_equal({ type: "object" }, called_with[:schema])
    assert_equal "TestContext", called_with[:context]
  end

  test "perform returns result from OpenaiQueue" do
    expected_result = { name: "Test", value: 123 }

    Ai::OpenaiQueue.stub :request, ->(**_args) { expected_result } do
      result = OpenaiRequestJob.perform_now(
        prompt: "Test",
        context: "Test"
      )

      assert_equal expected_result, result
    end
  end

  # === Callback tests ===

  test "perform calls callback class when provided" do
    callback_called = false
    callback_args = nil

    # Create a test callback class
    test_callback = Class.new do
      define_singleton_method(:handle_openai_response) do |id, result|
        callback_called = true
        callback_args = { id: id, result: result }
      end
    end

    stub_const("TestCallbackClass", test_callback) do
      Ai::OpenaiQueue.stub :request, ->(**_args) { { status: "ok" } } do
        OpenaiRequestJob.perform_now(
          prompt: "Test",
          context: "Test",
          callback_class: "TestCallbackClass",
          callback_id: 42
        )
      end
    end

    assert callback_called, "Callback should have been called"
    assert_equal 42, callback_args[:id]
    assert_equal({ status: "ok" }, callback_args[:result])
  end

  test "perform skips callback when callback_class is nil" do
    Ai::OpenaiQueue.stub :request, ->(**_args) { { status: "ok" } } do
      # Should not raise any errors
      result = OpenaiRequestJob.perform_now(
        prompt: "Test",
        context: "Test",
        callback_class: nil,
        callback_id: 123
      )

      assert_equal({ status: "ok" }, result)
    end
  end

  test "perform skips callback when callback_id is nil" do
    Ai::OpenaiQueue.stub :request, ->(**_args) { { status: "ok" } } do
      result = OpenaiRequestJob.perform_now(
        prompt: "Test",
        context: "Test",
        callback_class: "SomeClass",
        callback_id: nil
      )

      assert_equal({ status: "ok" }, result)
    end
  end

  test "perform skips callback when class does not respond to handle_openai_response" do
    test_callback = Class.new
    stub_const("NoHandlerClass", test_callback) do
      Ai::OpenaiQueue.stub :request, ->(**_args) { { status: "ok" } } do
        # Should not raise any errors
        result = OpenaiRequestJob.perform_now(
          prompt: "Test",
          context: "Test",
          callback_class: "NoHandlerClass",
          callback_id: 123
        )

        assert_equal({ status: "ok" }, result)
      end
    end
  end

  # === Retry behavior tests ===

  test "job retries on RequestError" do
    attempts = 0

    Ai::OpenaiQueue.stub :request, ->(**_args) {
      attempts += 1
      raise Ai::OpenaiQueue::RequestError, "API failed"
    } do
      assert_raises(Ai::OpenaiQueue::RequestError) do
        OpenaiRequestJob.perform_now(prompt: "Test", context: "Test")
      end
    end

    assert_equal 1, attempts
  end

  test "job retries on RateLimitError" do
    attempts = 0

    Ai::OpenaiQueue.stub :request, ->(**_args) {
      attempts += 1
      raise Ai::OpenaiQueue::RateLimitError, "Rate limited"
    } do
      assert_raises(Ai::OpenaiQueue::RateLimitError) do
        OpenaiRequestJob.perform_now(prompt: "Test", context: "Test")
      end
    end

    assert_equal 1, attempts
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for RequestError" do
    retry_config = OpenaiRequestJob.rescue_handlers.find do |handler|
      handler[0] == "Ai::OpenaiQueue::RequestError"
    end

    assert_not_nil retry_config, "Should have retry_on for RequestError"
  end

  test "job has retry_on configured for RateLimitError" do
    retry_config = OpenaiRequestJob.rescue_handlers.find do |handler|
      handler[0] == "Ai::OpenaiQueue::RateLimitError"
    end

    assert_not_nil retry_config, "Should have retry_on for RateLimitError"
  end

  private

  # Helper to stub a constant for the duration of a block
  def stub_const(name, value)
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name)
  end
end
