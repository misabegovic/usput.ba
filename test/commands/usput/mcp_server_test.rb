# frozen_string_literal: true

require "test_helper"

# The commands as MCP tools: what each kind of server offers, and how a call
# and a refusal read on the wire.
class Usput::MCPServerTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(username: "mcp_curator", email: "mcp_curator@example.com", password: "password123",
                            user_type: :curator).tap(&:confirm)
    @place = Location.create!(name: "Kravice", city: "Ljubuški", lat: 43.1564, lng: 17.6081)
  end

  test "a reading server offers only reading tools, a deciding one offers both" do
    reading = tool_names(Usput::MCPServer.build(actor: @curator))
    deciding = tool_names(Usput::MCPServer.build(actor: @curator, decides: true))

    assert_includes reading, "places_list"
    assert_not_includes reading, "places_archive"
    assert_includes deciding, "places_archive"
    assert_equal Usput::Commands.all.map(&:tool_name).sort, deciding.sort
  end

  test "a tool call answers with the command's result as JSON" do
    result = call(Usput::MCPServer.build(actor: nil), "places_list", city: "Ljubuški")

    assert_not result["isError"]
    assert_equal [ "Kravice" ], JSON.parse(result.dig("content", 0, "text")).pluck("name")
  end

  test "a refused call is a tool error naming why, not a protocol error" do
    result = call(Usput::MCPServer.build(actor: nil, decides: true), "places_archive", id: @place.uuid)

    assert result["isError"]
    assert_match(/not allowed/, result.dig("content", 0, "text"))
    assert_not @place.reload.archived?
  end

  test "a deciding call acts as the server's actor" do
    call(Usput::MCPServer.build(actor: @curator, decides: true), "places_archive", id: @place.uuid)

    assert @place.reload.archived?
    assert_equal @curator.uuid, DecisionLog.history(@place).last.data.symbolize_keys[:by]
  end

  test "the brain's pages are resources" do
    server = Usput::MCPServer.build(actor: nil)
    listed = rpc(server, "resources/list").dig("result", "resources").pluck("uri")
    page = rpc(server, "resources/read", uri: "usput://brain/state").dig("result", "contents", 0, "text")

    assert_includes listed, "usput://brain/index"
    assert_includes page, "## Now"
  end

  private

  def tool_names(server) = rpc(server, "tools/list").dig("result", "tools").pluck("name")

  def call(server, name, **arguments) = rpc(server, "tools/call", name:, arguments:)["result"]

  def rpc(server, method, **params)
    JSON.parse(server.handle_json({ jsonrpc: "2.0", id: 1, method:, params: }.to_json))
  end
end
