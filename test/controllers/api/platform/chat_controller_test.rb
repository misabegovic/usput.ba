# frozen_string_literal: true

require "test_helper"

class ApiPlatformChatControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_key = "test_api_key_12345"
    ENV["PLATFORM_API_KEY"] = @api_key
  end

  teardown do
    ENV["PLATFORM_API_KEY"] = nil
  end

  # Authentication tests

  test "rejects requests without API key" do
    post api_platform_chat_path, params: { query: "schema | stats" }

    assert_response :unauthorized
    assert_includes response.parsed_body["error"], "Unauthorized"
  end

  test "rejects requests with invalid API key" do
    post api_platform_chat_path,
         params: { query: "schema | stats" },
         headers: { "Authorization" => "Bearer invalid_key" }

    assert_response :unauthorized
  end

  test "accepts requests with valid API key in header" do
    post api_platform_chat_path,
         params: { query: "schema | stats" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
  end

  test "accepts requests with valid API key in params" do
    post api_platform_chat_path,
         params: { query: "schema | stats", api_key: @api_key }

    assert_response :success
  end

  # Chat endpoint tests

  test "executes DSL query successfully" do
    post api_platform_chat_path,
         params: { query: "locations | count" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body["success"]
    assert_equal "locations | count", body["query"]
    assert body["result"].present?
  end

  test "returns error for missing query and message" do
    post api_platform_chat_path,
         params: {},
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "BadRequest"
  end

  test "handles parse errors gracefully" do
    post api_platform_chat_path,
         params: { query: "invalid !!! query syntax" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "ParseError"
  end

  test "handles execution errors gracefully" do
    post api_platform_chat_path,
         params: { query: "prompts { id: 999999 } | show" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"], "ExecutionError"
  end

  # Execute endpoint tests

  test "execute endpoint works with valid query" do
    post api_platform_execute_path,
         params: { query: "schema | stats" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    assert response.parsed_body["success"]
  end

  test "execute endpoint requires query parameter" do
    post api_platform_execute_path,
         params: {},
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :bad_request
  end

  # Parse endpoint tests

  test "parse endpoint returns AST" do
    get api_platform_parse_path,
        params: { query: "locations { city: \"Mostar\" } | count" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body["success"]
    assert body["ast"].present?
    assert_equal "table_query", body["ast"]["type"]
  end

  test "parse endpoint handles errors" do
    get api_platform_parse_path,
        params: { query: "invalid !!! syntax" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :bad_request
  end

  # Integration tests

  test "can execute various DSL commands" do
    queries = [
      "schema | stats",
      "locations | count",
      "prompts | count",
      "infrastructure"
    ]

    queries.each do |query|
      post api_platform_chat_path,
           params: { query: query },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success, "Failed for query: #{query}"
    end
  end

  test "creates audit log for API calls" do
    assert_difference "PlatformAuditLog.count" do
      post api_platform_chat_path,
           params: { query: "schema | stats" },
           headers: { "Authorization" => "Bearer #{@api_key}" }
    end

    log = PlatformAuditLog.last
    assert_equal "ApiCall", log.record_type
    assert_equal "platform_api", log.triggered_by
  end

  # Error response format tests

  test "error responses include standard fields" do
    post api_platform_chat_path,
         params: { query: "invalid !!! query syntax" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :bad_request
    body = response.parsed_body

    assert body["error"].present?
    assert body["message"].present?
    assert body["status"].present?
    assert body["timestamp"].present?
  end

  test "unauthorized error includes standard fields" do
    post api_platform_chat_path, params: { query: "schema | stats" }

    assert_response :unauthorized
    body = response.parsed_body

    assert_equal "Unauthorized", body["error"]
    assert_equal 401, body["status"]
    assert body["timestamp"].present?
  end

  # Streaming tests (basic - just ensure endpoint accepts stream param)

  test "stream parameter is accepted without error" do
    # Note: Full streaming test would require EventSource/SSE client
    # This test just ensures the endpoint doesn't crash with stream=true
    post api_platform_chat_path,
         params: { query: "schema | stats", stream: "true" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    # Response should be text/event-stream for streaming
    assert_equal "text/event-stream", response.content_type.split(";").first
  end

  test "stream with boolean true works" do
    post api_platform_chat_path,
         params: { query: "schema | stats", stream: true },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_equal "text/event-stream", response.content_type.split(";").first
  end

  test "stream without query or message returns error event" do
    post api_platform_chat_path,
         params: { stream: "true" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_equal "text/event-stream", response.content_type.split(";").first
    assert_includes response.body, "BadRequest"
  end

  # Natural language processing tests

  test "executes natural language message via Brain" do
    Platform::Brain.stub(:new, ->(**kwargs) {
      mock = Minitest::Mock.new
      mock.expect(:process, {
        text: "Test response",
        dsl_queries: [],
        conversation_id: "test-123"
      }, [String])
      mock
    }) do
      post api_platform_chat_path,
           params: { message: "How many locations are there?" },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      body = response.parsed_body

      assert body["success"]
      assert_equal "How many locations are there?", body["message"]
      assert body["response"].present?
    end
  end

  test "natural language with conversation_id passes it to Brain" do
    received_conversation_id = nil
    Platform::Brain.stub(:new, ->(**kwargs) {
      received_conversation_id = kwargs[:conversation_id]
      mock = Minitest::Mock.new
      mock.expect(:process, {
        text: "Test response",
        dsl_queries: [],
        conversation_id: "conv-456"
      }, [String])
      mock
    }) do
      post api_platform_chat_path,
           params: { message: "Test message", conversation_id: "existing-conv-123" },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      assert_equal "existing-conv-123", received_conversation_id
    end
  end

  # Parse endpoint tests - additional coverage

  test "parse endpoint requires query parameter" do
    get api_platform_parse_path,
        params: {},
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "BadRequest"
    assert_includes response.parsed_body["message"], "query"
  end

  # Execute endpoint additional tests

  test "execute endpoint handles execution errors" do
    post api_platform_execute_path,
         params: { query: "prompts { id: 99999999 } | show" },
         headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"], "ExecutionError"
  end

  # API key extraction tests

  test "accepts API key from params when no header" do
    post api_platform_chat_path,
         params: { query: "schema | stats", api_key: @api_key }

    assert_response :success
  end

  test "rejects when API key is blank" do
    post api_platform_chat_path,
         params: { query: "schema | stats", api_key: "" }

    assert_response :unauthorized
  end

  test "rejects when PLATFORM_API_KEY env is not set" do
    ENV["PLATFORM_API_KEY"] = nil

    post api_platform_chat_path,
         params: { query: "schema | stats" },
         headers: { "Authorization" => "Bearer some_key" }

    assert_response :unauthorized
  end

  # Audit log edge case

  test "continues even if audit log fails" do
    PlatformAuditLog.stub(:create, ->(*args) { raise "DB error" }) do
      post api_platform_chat_path,
           params: { query: "schema | stats" },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
    end
  end

  # Test stream_response error handling
  test "stream handles errors gracefully" do
    Platform::DSL.stub(:execute, ->(_) { raise "Unexpected stream error" }) do
      post api_platform_chat_path,
           params: { query: "schema | stats", stream: true },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_equal "text/event-stream", response.content_type.split(";").first
      # Error should be in the stream output
      assert_includes response.body, "error"
    end
  end

  # Test natural language when Brain is not defined
  test "returns not implemented when Brain is not available for natural language" do
    # Hide Platform::Brain temporarily
    original_brain = Platform::Brain
    Platform.send(:remove_const, :Brain)

    begin
      post api_platform_chat_path,
           params: { message: "How many locations?" },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :not_implemented
      body = response.parsed_body
      assert_equal "NotImplemented", body["error"]
      assert_includes body["message"], "Platform::Brain"
    ensure
      # Restore Platform::Brain
      Platform.const_set(:Brain, original_brain)
    end
  end

  # Test streaming with Brain message (not query)
  test "stream with message uses Brain for processing" do
    mock_brain = Object.new
    mock_brain.define_singleton_method(:process) do |_message, &block|
      # Actually yield to the block to cover line 168
      block.call("progress", { step: "thinking" }) if block
      {
        text: "Streamed response",
        dsl_queries: ["locations | count"],
        conversation_id: "stream-123"
      }
    end

    Platform::Brain.stub(:new, ->(**_kwargs) { mock_brain }) do
      post api_platform_chat_path,
           params: { message: "Test streaming", stream: true },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_equal "text/event-stream", response.content_type.split(";").first
      assert_includes response.body, "start"
      assert_includes response.body, "progress"
    end
  end

  # Test streaming when Brain is not defined
  test "stream returns not implemented when Brain is not available" do
    original_brain = Platform::Brain
    Platform.send(:remove_const, :Brain)

    begin
      post api_platform_chat_path,
           params: { message: "Test message", stream: true },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_equal "text/event-stream", response.content_type.split(";").first
      assert_includes response.body, "NotImplemented"
      assert_includes response.body, "Brain not available"
    ensure
      Platform.const_set(:Brain, original_brain)
    end
  end

  # Production guard test
  test "production guard returns forbidden in production without env var" do
    original_env = Rails.env
    Rails.instance_variable_set(:@_env, ActiveSupport::EnvironmentInquirer.new("production"))

    begin
      post api_platform_chat_path,
           params: { query: "schema | stats" },
           headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :forbidden
      body = response.parsed_body
      assert_equal "Forbidden", body["error"]
      assert_includes body["message"], "Platform Chat API nije dostupan u produkciji"
    ensure
      Rails.instance_variable_set(:@_env, ActiveSupport::EnvironmentInquirer.new(original_env.to_s))
    end
  end
end
