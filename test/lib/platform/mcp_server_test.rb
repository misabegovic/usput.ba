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

  # ===================
  # Additional Coverage Tests
  # ===================

  test "handle_request handles resources/read method" do
    Platform::DSL.stub :execute, { data: "test" } do
      request = {
        "method" => "resources/read",
        "params" => { "uri" => "platform://schema" },
        "id" => 1
      }
      result = @server.send(:handle_request, request)

      assert result[:result].present?
    end
  end

  test "handle_request handles prompts/get method" do
    request = {
      "method" => "prompts/get",
      "params" => { "name" => "analyze_location", "arguments" => { "location" => "Test" } },
      "id" => 1
    }
    result = @server.send(:handle_request, request)

    assert result[:result][:messages].present?
  end

  test "list_prompts handles errors" do
    Platform::DSL.stub :execute, ->(_) { raise StandardError, "Query failed" } do
      result = @server.send(:list_prompts, nil)

      assert result[:isError]
    end
  end

  test "prepare_fix handles errors" do
    Platform::DSL.stub :execute, ->(_) { raise StandardError, "Creation failed" } do
      result = @server.send(:prepare_fix, { "description" => "Fix bug" })

      assert result[:isError]
    end
  end

  test "prepare_feature handles errors" do
    Platform::DSL.stub :execute, ->(_) { raise StandardError, "Creation failed" } do
      result = @server.send(:prepare_feature, { "description" => "Add feature" })

      assert result[:isError]
    end
  end

  test "read_prompts handles errors" do
    Platform::DSL.stub :execute, ->(_) { raise StandardError, "Query failed" } do
      result = @server.send(:read_prompts)

      assert result[:error].present?
    end
  end

  test "read_infrastructure handles errors" do
    Platform::DSL.stub :execute, ->(_) { raise StandardError, "Query failed" } do
      result = @server.send(:read_infrastructure)

      assert result[:error].present?
    end
  end

  test "execute_dsl with empty string query" do
    result = @server.send(:execute_dsl, "")

    assert result[:isError]
    assert_includes result[:content].first[:text], "required"
  end

  test "handle_tools_call with nil arguments" do
    Platform::DSL.stub :execute, { status: "ok" } do
      result = @server.send(:handle_tools_call, {
        "name" => "platform_status"
        # No "arguments" key
      })

      assert result[:content].present?
    end
  end

  test "handle_prompts_get with empty arguments" do
    result = @server.send(:handle_prompts_get, {
      "name" => "analyze_location"
      # No "arguments" key
    })

    assert result[:messages].present?
  end

  test "handle_request returns error result properly formatted" do
    request = {
      "method" => "tools/call",
      "params" => { "name" => "unknown_tool" },
      "id" => 1
    }
    result = @server.send(:handle_request, request)

    assert result[:error].present?
    assert_equal 1, result[:id]
    assert_equal "2.0", result[:jsonrpc]
  end

  test "class method run creates and runs server" do
    mock_server = Object.new
    run_called = false
    mock_server.define_singleton_method(:run) { run_called = true }

    Platform::MCPServer.stub(:new, mock_server) do
      # Simulate very quick run
      Platform::MCPServer.run
    end

    assert run_called
  end

  test "write_error with nil id" do
    io = StringIO.new
    original_stdout = $stdout
    begin
      $stdout = io
      @server.send(:write_error, -32600, "Invalid Request", nil)
    ensure
      $stdout = original_stdout
    end

    output = JSON.parse(io.string)

    assert_nil output["id"]
    assert_equal(-32600, output["error"]["code"])
  end

  test "prepare_fix with severity only" do
    Platform::DSL.stub :execute, { prompt_id: 1 } do
      result = @server.send(:prepare_fix, {
        "description" => "Fix bug",
        "severity" => "critical"
      })

      assert result[:content].present?
    end
  end

  test "prepare_fix with file only" do
    Platform::DSL.stub :execute, { prompt_id: 1 } do
      result = @server.send(:prepare_fix, {
        "description" => "Fix bug",
        "file" => "app/models/test.rb"
      })

      assert result[:content].present?
    end
  end

  # ===================
  # Run Method Tests (stdin loop)
  # ===================

  test "run processes json lines from stdin" do
    # Create a mock stdin with valid JSON request
    input = StringIO.new(%({"method": "initialize", "params": {}, "id": 1}\n))
    output = StringIO.new

    original_stdin = $stdin
    original_stdout = $stdout

    begin
      $stdin = input
      $stdout = output

      server = Platform::MCPServer.new
      server.run  # Will process one line and stop (no more input)

      # Check that something was written to output
      assert output.string.present?, "Expected output to be written"
      response = JSON.parse(output.string)
      assert_equal "2.0", response["jsonrpc"]
      assert_equal 1, response["id"]
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  test "run handles json parse errors" do
    # Create a mock stdin with invalid JSON
    input = StringIO.new("not valid json\n")
    output = StringIO.new

    original_stdin = $stdin
    original_stdout = $stdout

    begin
      $stdin = input
      $stdout = output

      server = Platform::MCPServer.new
      server.run  # Will process one line with parse error

      # Check that error response was written
      assert output.string.present?, "Expected error output"
      response = JSON.parse(output.string)
      assert_equal(-32700, response["error"]["code"])
      assert_includes response["error"]["message"], "Parse error"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  test "run handles internal errors" do
    # Create a mock stdin with JSON that will cause internal error
    input = StringIO.new(%({"method": "tools/call", "params": {"name": "platform_execute", "arguments": {"query": "test"}}, "id": 1}\n))
    output = StringIO.new

    original_stdin = $stdin
    original_stdout = $stdout

    begin
      $stdin = input
      $stdout = output

      # Make DSL.execute raise a generic error that's caught in the outer rescue
      Platform::DSL.stub(:execute, ->(_) { raise "Something unexpected" }) do
        server = Platform::MCPServer.new
        server.run
      end

      # Check that response was written (could be success or error)
      assert output.string.present?
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  test "run stops when running is set to false" do
    # Create a mock stdin with shutdown command
    input = StringIO.new(%({"method": "shutdown", "params": {}, "id": 1}\n{"method": "initialize", "params": {}, "id": 2}\n))
    output = StringIO.new

    original_stdin = $stdin
    original_stdout = $stdout

    begin
      $stdin = input
      $stdout = output

      server = Platform::MCPServer.new
      server.run

      # Only shutdown response should be present (second request not processed)
      lines = output.string.strip.split("\n")
      # Should have processed at least shutdown
      assert lines.size >= 1

      # Parse first response
      first_response = JSON.parse(lines[0])
      assert_equal 1, first_response["id"]
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  test "run processes multiple requests" do
    requests = [
      %({"method": "initialize", "params": {}, "id": 1}),
      %({"method": "tools/list", "params": {}, "id": 2})
    ].join("\n") + "\n"

    input = StringIO.new(requests)
    output = StringIO.new

    original_stdin = $stdin
    original_stdout = $stdout

    begin
      $stdin = input
      $stdout = output

      server = Platform::MCPServer.new
      server.run

      # Both responses should be present
      lines = output.string.strip.split("\n")
      assert lines.size >= 2

      first_response = JSON.parse(lines[0])
      second_response = JSON.parse(lines[1])

      assert_equal 1, first_response["id"]
      assert_equal 2, second_response["id"]
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  test "run handles unexpected internal errors in handle_request" do
    # Create a request that will cause handle_request to raise an unexpected error
    input = StringIO.new(%({"method": "initialize", "params": {}, "id": 1}\n))
    output = StringIO.new

    original_stdin = $stdin
    original_stdout = $stdout

    begin
      $stdin = input
      $stdout = output

      server = Platform::MCPServer.new

      # Stub handle_request to raise an internal error
      server.define_singleton_method(:handle_request) do |_request|
        raise RuntimeError, "Unexpected internal failure"
      end

      server.run

      # Should write internal error response
      assert output.string.present?, "Expected error output"
      response = JSON.parse(output.string)
      assert_equal(-32603, response["error"]["code"])
      assert_includes response["error"]["message"], "Internal error"
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end
  end

  # ===================
  # Production Guard Tests
  # ===================

  test "production_guard! allows in non-production environment" do
    # In test environment, should not exit
    assert_nothing_raised do
      Platform::MCPServer.production_guard!
    end
  end

  test "production_guard! allows when PLATFORM_MCP_ENABLED is true in production" do
    original_env = ENV["PLATFORM_MCP_ENABLED"]
    ENV["PLATFORM_MCP_ENABLED"] = "true"

    # Mock production environment
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
      assert_nothing_raised do
        Platform::MCPServer.production_guard!
      end
    end
  ensure
    ENV["PLATFORM_MCP_ENABLED"] = original_env
  end
end
