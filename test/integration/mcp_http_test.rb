# frozen_string_literal: true

require "test_helper"

# The MCP server over HTTP: a bearer token, admins only, reading tools only.
class MCPHTTPTest < ActionDispatch::IntegrationTest
  setup do
    @admin = person(:admin)
    @record, @token = APIToken.issue!(user: @admin, name: "laptop")
  end

  test "no token, a wrong one or a revoked one is unauthorized" do
    rpc("tools/list", token: nil)
    assert_response :unauthorized
    rpc("tools/list", token: "usput_wrong")
    assert_response :unauthorized

    @record.revoke!
    rpc("tools/list")
    assert_response :unauthorized
  end

  test "a curator's token is refused in the first release" do
    _, curator_token = APIToken.issue!(user: person(:curator), name: "agent")

    rpc("tools/list", token: curator_token)

    assert_response :forbidden
  end

  test "an admin lists reading tools only and the token's use is noted" do
    rpc("tools/list")

    assert_response :success
    names = response.parsed_body.dig("result", "tools").pluck("name")
    assert_includes names, "reviews_queue"
    assert_not_includes names, "reviews_approve"
    assert @record.reload.last_used_at.present?
  end

  test "a tool call over HTTP answers as the token's user" do
    Location.create!(name: "Una", city: "Bihać", lat: 44.8169, lng: 15.8708)

    rpc("tools/call", name: "places_list", arguments: { city: "Bihać" })

    assert_response :success
    text = response.parsed_body.dig("result", "content", 0, "text")
    assert_equal [ "Una" ], JSON.parse(text).pluck("name")
  end

  test "the server keeps no stream to GET" do
    get "/mcp", headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :method_not_allowed
  end

  private

  def rpc(method, token: @token, **params)
    headers = { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method:, params: }.to_json, headers:
  end

  def person(role)
    User.create!(username: "http_#{role}", email: "http_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end
