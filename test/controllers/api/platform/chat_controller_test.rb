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
end
