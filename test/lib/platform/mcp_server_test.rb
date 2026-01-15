# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/platform/mcp_server"

class Platform::MCPServerTest < ActiveSupport::TestCase
  setup do
    @server = Platform::MCPServer.new
  end

  # ===================
  # Constants Tests
  # ===================

  test "PROTOCOL_VERSION is defined" do
    assert_equal "2024-11-05", Platform::MCPServer::PROTOCOL_VERSION
  end

  test "SERVER_NAME is defined" do
    assert_equal "platform-mcp", Platform::MCPServer::SERVER_NAME
  end

  test "SERVER_VERSION is defined" do
    assert_equal "1.0.0", Platform::MCPServer::SERVER_VERSION
  end

  # ===================
  # Initialization Tests
  # ===================

  test "initializes with running state" do
    assert @server.instance_variable_get(:@running)
  end

  # ===================
  # Handle Initialize Tests
  # ===================

  test "handle_initialize returns server info" do
    result = @server.send(:handle_initialize, {})

    assert_equal Platform::MCPServer::PROTOCOL_VERSION, result[:protocolVersion]
    assert_equal Platform::MCPServer::SERVER_NAME, result[:serverInfo][:name]
    assert_equal Platform::MCPServer::SERVER_VERSION, result[:serverInfo][:version]
    assert result[:capabilities].key?(:tools)
    assert result[:capabilities].key?(:resources)
    assert result[:capabilities].key?(:prompts)
  end

  # ===================
  # Handle Tools List Tests
  # ===================

  test "handle_tools_list returns available tools" do
    result = @server.send(:handle_tools_list)

    assert result.key?(:tools)
    assert result[:tools].is_a?(Array)

    tool_names = result[:tools].map { |t| t[:name] }
    assert_includes tool_names, "platform_execute"
    assert_includes tool_names, "platform_status"
    assert_includes tool_names, "platform_prompts"
    assert_includes tool_names, "prepare_fix"
    assert_includes tool_names, "prepare_feature"
  end

  test "platform_execute tool has correct schema" do
    result = @server.send(:handle_tools_list)
    tool = result[:tools].find { |t| t[:name] == "platform_execute" }

    assert tool.present?
    assert tool[:description].present?
    assert_equal "object", tool[:inputSchema][:type]
    assert_includes tool[:inputSchema][:required], "query"
  end

  test "prepare_fix tool has correct schema" do
    result = @server.send(:handle_tools_list)
    tool = result[:tools].find { |t| t[:name] == "prepare_fix" }

    assert tool.present?
    assert tool[:inputSchema][:properties][:description].present?
    assert tool[:inputSchema][:properties][:severity].present?
    assert_includes tool[:inputSchema][:required], "description"
  end

  # ===================
  # Handle Tools Call Tests
  # ===================

  test "handle_tools_call returns error for unknown tool" do
    result = @server.send(:handle_tools_call, { "name" => "unknown_tool" })

    assert result[:error].present?
    assert_equal(-32602, result[:error][:code])
    assert_includes result[:error][:message], "unknown_tool"
  end

  test "handle_tools_call routes to platform_execute" do
    Platform::DSL.stub :execute, { count: 10 } do
      result = @server.send(:handle_tools_call, {
        "name" => "platform_execute",
        "arguments" => { "query" => "schema | stats" }
      })

      assert result[:content].present?
    end
  end

  test "handle_tools_call routes to platform_status" do
    Platform::DSL.stub :execute, { status: "healthy" } do
      result = @server.send(:handle_tools_call, {
        "name" => "platform_status",
        "arguments" => {}
      })

      assert result[:content].present?
    end
  end

  test "handle_tools_call routes to platform_prompts" do
    Platform::DSL.stub :execute, { prompts: [] } do
      result = @server.send(:handle_tools_call, {
        "name" => "platform_prompts",
        "arguments" => {}
      })

      assert result[:content].present?
    end
  end

  test "handle_tools_call routes to prepare_fix" do
    Platform::DSL.stub :execute, { prompt_id: 1 } do
      result = @server.send(:handle_tools_call, {
        "name" => "prepare_fix",
        "arguments" => { "description" => "Fix bug" }
      })

      assert result[:content].present?
    end
  end

  test "handle_tools_call routes to prepare_feature" do
    Platform::DSL.stub :execute, { prompt_id: 1 } do
      result = @server.send(:handle_tools_call, {
        "name" => "prepare_feature",
        "arguments" => { "description" => "Add feature" }
      })

      assert result[:content].present?
    end
  end

  # ===================
  # Handle Resources List Tests
  # ===================

  test "handle_resources_list returns available resources" do
    result = @server.send(:handle_resources_list)

    assert result.key?(:resources)
    assert result[:resources].is_a?(Array)

    uris = result[:resources].map { |r| r[:uri] }
    assert_includes uris, "platform://schema"
    assert_includes uris, "platform://prompts"
    assert_includes uris, "platform://infrastructure"
  end

  test "resources have required fields" do
    result = @server.send(:handle_resources_list)

    result[:resources].each do |resource|
      assert resource[:uri].present?
      assert resource[:name].present?
      assert resource[:description].present?
      assert resource[:mimeType].present?
    end
  end

  # ===================
  # Handle Resources Read Tests
  # ===================

  test "handle_resources_read returns error for unknown resource" do
    result = @server.send(:handle_resources_read, { "uri" => "platform://unknown" })

    assert result[:error].present?
    assert_equal(-32602, result[:error][:code])
  end

  test "handle_resources_read reads schema resource" do
    Platform::DSL.stub :execute, { locations: 100 } do
      result = @server.send(:handle_resources_read, { "uri" => "platform://schema" })

      assert result[:contents].present?
      assert_equal "platform://schema", result[:contents].first[:uri]
    end
  end

  test "handle_resources_read reads prompts resource" do
    Platform::DSL.stub :execute, { prompts: [] } do
      result = @server.send(:handle_resources_read, { "uri" => "platform://prompts" })

      assert result[:contents].present?
      assert_equal "platform://prompts", result[:contents].first[:uri]
    end
  end

  test "handle_resources_read reads infrastructure resource" do
    Platform::DSL.stub :execute, { health: "ok" } do
      result = @server.send(:handle_resources_read, { "uri" => "platform://infrastructure" })

      assert result[:contents].present?
      assert_equal "platform://infrastructure", result[:contents].first[:uri]
    end
  end

  # ===================
  # Handle Prompts List Tests
  # ===================

  test "handle_prompts_list returns available prompts" do
    result = @server.send(:handle_prompts_list)

    assert result.key?(:prompts)
    assert result[:prompts].is_a?(Array)

    prompt_names = result[:prompts].map { |p| p[:name] }
    assert_includes prompt_names, "analyze_location"
    assert_includes prompt_names, "city_report"
  end

  test "prompts have required arguments" do
    result = @server.send(:handle_prompts_list)

    result[:prompts].each do |prompt|
      assert prompt[:name].present?
      assert prompt[:description].present?
      assert prompt[:arguments].is_a?(Array)
    end
  end

  # ===================
  # Handle Prompts Get Tests
  # ===================

  test "handle_prompts_get returns error for unknown prompt" do
    result = @server.send(:handle_prompts_get, { "name" => "unknown_prompt" })

    assert result[:error].present?
    assert_equal(-32602, result[:error][:code])
  end

  test "handle_prompts_get returns analyze_location prompt" do
    result = @server.send(:handle_prompts_get, {
      "name" => "analyze_location",
      "arguments" => { "location" => "Mostar" }
    })

    assert result[:messages].present?
    assert_equal "user", result[:messages].first[:role]
    assert_includes result[:messages].first[:content][:text], "Mostar"
  end

  test "handle_prompts_get returns city_report prompt" do
    result = @server.send(:handle_prompts_get, {
      "name" => "city_report",
      "arguments" => { "city" => "Sarajevo" }
    })

    assert result[:messages].present?
    assert_includes result[:messages].first[:content][:text], "Sarajevo"
  end

  # ===================
  # Execute DSL Tests
  # ===================

  test "execute_dsl returns error for blank query" do
    result = @server.send(:execute_dsl, nil)

    assert result[:isError]
    assert_includes result[:content].first[:text], "required"
  end

  test "execute_dsl returns result for valid query" do
    Platform::DSL.stub :execute, { count: 42 } do
      result = @server.send(:execute_dsl, "schema | stats")

      refute result[:isError]
      assert_includes result[:content].first[:text], "42"
    end
  end

  test "execute_dsl handles parse error" do
    Platform::DSL.stub :execute, ->(_) { raise Platform::DSL::ParseError, "Invalid syntax" } do
      result = @server.send(:execute_dsl, "bad query")

      assert result[:isError]
      assert_includes result[:content].first[:text], "Parse Error"
    end
  end

  test "execute_dsl handles execution error" do
    Platform::DSL.stub :execute, ->(_) { raise Platform::DSL::ExecutionError, "Execution failed" } do
      result = @server.send(:execute_dsl, "schema | stats")

      assert result[:isError]
      assert_includes result[:content].first[:text], "Execution Error"
    end
  end

  test "execute_dsl handles generic error" do
    Platform::DSL.stub :execute, ->(_) { raise StandardError, "Something went wrong" } do
      result = @server.send(:execute_dsl, "schema | stats")

      assert result[:isError]
      assert_includes result[:content].first[:text], "Error"
    end
  end

  # ===================
  # Get Status Tests
  # ===================

  test "get_status returns infrastructure data" do
    Platform::DSL.stub :execute, { healthy: true } do
      result = @server.send(:get_status)

      assert result[:content].present?
      assert_includes result[:content].first[:text], "healthy"
    end
  end

  test "get_status handles errors" do
    Platform::DSL.stub :execute, -> { raise StandardError, "Failed" } do
      result = @server.send(:get_status)

      assert result[:isError]
    end
  end

  # ===================
  # List Prompts Tests
  # ===================

  test "list_prompts without status filter" do
    Platform::DSL.stub :execute, { prompts: [] } do
      result = @server.send(:list_prompts, nil)

      assert result[:content].present?
    end
  end

  test "list_prompts with status filter" do
    Platform::DSL.stub :execute, { prompts: [] } do
      result = @server.send(:list_prompts, "pending")

      assert result[:content].present?
    end
  end

  # ===================
  # Prepare Fix Tests
  # ===================

  test "prepare_fix with all arguments" do
    Platform::DSL.stub :execute, { prompt_id: 1 } do
      result = @server.send(:prepare_fix, {
        "description" => "Fix bug",
        "severity" => "high",
        "file" => "app/models/user.rb"
      })

      assert result[:content].present?
    end
  end

  test "prepare_fix with only description" do
    Platform::DSL.stub :execute, { prompt_id: 1 } do
      result = @server.send(:prepare_fix, {
        "description" => "Fix bug"
      })

      assert result[:content].present?
    end
  end

  # ===================
  # Prepare Feature Tests
  # ===================

  test "prepare_feature creates prompt" do
    Platform::DSL.stub :execute, { prompt_id: 1 } do
      result = @server.send(:prepare_feature, {
        "description" => "Add new feature"
      })

      assert result[:content].present?
    end
  end

  # ===================
  # Resource Reader Tests
  # ===================

  test "read_schema returns schema data" do
    Platform::DSL.stub :execute, { locations: 100 } do
      result = @server.send(:read_schema)

      assert result[:contents].present?
      assert_equal "application/json", result[:contents].first[:mimeType]
    end
  end

  test "read_schema handles errors" do
    Platform::DSL.stub :execute, -> { raise StandardError, "DB error" } do
      result = @server.send(:read_schema)

      assert result[:error].present?
    end
  end

  test "read_prompts returns prompts data" do
    Platform::DSL.stub :execute, { prompts: [] } do
      result = @server.send(:read_prompts)

      assert result[:contents].present?
    end
  end

  test "read_infrastructure returns health data" do
    Platform::DSL.stub :execute, { healthy: true } do
      result = @server.send(:read_infrastructure)

      assert result[:contents].present?
    end
  end

  # ===================
  # Handle Request Tests
  # ===================

  test "handle_request routes initialize method" do
    request = { "method" => "initialize", "params" => {}, "id" => 1 }
    result = @server.send(:handle_request, request)

    assert_equal "2.0", result[:jsonrpc]
    assert_equal 1, result[:id]
    assert result[:result].present?
  end

  test "handle_request returns nil for initialized notification" do
    request = { "method" => "initialized", "params" => {} }
    result = @server.send(:handle_request, request)

    assert_nil result
  end

  test "handle_request routes tools/list method" do
    request = { "method" => "tools/list", "params" => {}, "id" => 1 }
    result = @server.send(:handle_request, request)

    assert result[:result][:tools].present?
  end

  test "handle_request routes tools/call method" do
    Platform::DSL.stub :execute, { count: 10 } do
      request = {
        "method" => "tools/call",
        "params" => { "name" => "platform_execute", "arguments" => { "query" => "test" } },
        "id" => 1
      }
      result = @server.send(:handle_request, request)

      assert result[:result].present?
    end
  end

  test "handle_request routes resources/list method" do
    request = { "method" => "resources/list", "params" => {}, "id" => 1 }
    result = @server.send(:handle_request, request)

    assert result[:result][:resources].present?
  end

  test "handle_request routes prompts/list method" do
    request = { "method" => "prompts/list", "params" => {}, "id" => 1 }
    result = @server.send(:handle_request, request)

    assert result[:result][:prompts].present?
  end

  test "handle_request handles shutdown" do
    request = { "method" => "shutdown", "params" => {}, "id" => 1 }
    result = @server.send(:handle_request, request)

    refute @server.instance_variable_get(:@running)
    assert_equal({}, result[:result])
  end

  test "handle_request returns error for unknown method" do
    request = { "method" => "unknown_method", "params" => {}, "id" => 1 }
    result = @server.send(:handle_request, request)

    assert result[:error].present?
    assert_equal(-32601, result[:error][:code])
  end

  test "handle_request returns nil for notifications (no id)" do
    request = { "method" => "some_notification", "params" => {} }
    result = @server.send(:handle_request, request)

    assert_nil result
  end

  # ===================
  # Write Methods Tests
  # ===================

  test "write_error creates proper error response" do
    io = StringIO.new
    original_stdout = $stdout
    begin
      $stdout = io
      @server.send(:write_error, -32700, "Parse error", 1)
    ensure
      $stdout = original_stdout
    end

    output = JSON.parse(io.string)

    assert_equal "2.0", output["jsonrpc"]
    assert_equal 1, output["id"]
    assert_equal(-32700, output["error"]["code"])
    assert_equal "Parse error", output["error"]["message"]
  end

  test "write_response outputs JSON" do
    io = StringIO.new
    original_stdout = $stdout
    begin
      $stdout = io
      @server.send(:write_response, { jsonrpc: "2.0", id: 1, result: {} })
    ensure
      $stdout = original_stdout
    end

    output = JSON.parse(io.string)

    assert_equal "2.0", output["jsonrpc"]
    assert_equal 1, output["id"]
  end
end
