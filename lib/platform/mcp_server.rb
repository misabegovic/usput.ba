# frozen_string_literal: true

require "json"

module Platform
  # MCPServer - Model Context Protocol server for Platform
  #
  # Implements the MCP protocol to expose Platform DSL as tools for Claude Desktop
  # and other MCP-compatible clients.
  #
  # @example Run the MCP server
  #   Platform::MCPServer.run
  #
  # @see https://modelcontextprotocol.io/
  #
  class MCPServer
    PROTOCOL_VERSION = "2024-11-05"
    SERVER_NAME = "platform-mcp"
    SERVER_VERSION = "1.0.0"

    class << self
      def run
        production_guard!
        server = new
        server.run
      end

      # Check if MCP server is allowed in current environment
      def production_guard!
        return unless defined?(Rails) && Rails.env.production?
        return if ENV["PLATFORM_MCP_ENABLED"] == "true"

        $stderr.puts "❌ Platform MCP server nije dostupan u produkciji."
        $stderr.puts "   Postavi PLATFORM_MCP_ENABLED=true za omogućavanje."
        exit 1
      end
    end

    def initialize
      @running = true
    end

    def run
      # MCP uses stdio for communication
      $stdin.each_line do |line|
        break unless @running

        begin
          request = JSON.parse(line)
          response = handle_request(request)
          write_response(response) if response
        rescue JSON::ParserError => e
          write_error(-32700, "Parse error: #{e.message}")
        rescue => e
          write_error(-32603, "Internal error: #{e.message}")
        end
      end
    end

    private

    def handle_request(request)
      method = request["method"]
      params = request["params"] || {}
      id = request["id"]

      result = case method
      when "initialize"
                 handle_initialize(params)
      when "initialized"
                 nil # Notification, no response needed
      when "tools/list"
                 handle_tools_list
      when "tools/call"
                 handle_tools_call(params)
      when "resources/list"
                 handle_resources_list
      when "resources/read"
                 handle_resources_read(params)
      when "prompts/list"
                 handle_prompts_list
      when "prompts/get"
                 handle_prompts_get(params)
      when "shutdown"
                 @running = false
                 {}
      else
                 { error: { code: -32601, message: "Method not found: #{method}" } }
      end

      return nil unless id # Notifications don't get responses

      if result.is_a?(Hash) && result[:error]
        { jsonrpc: "2.0", id: id, error: result[:error] }
      else
        { jsonrpc: "2.0", id: id, result: result }
      end
    end

    def handle_initialize(params)
      {
        protocolVersion: PROTOCOL_VERSION,
        serverInfo: {
          name: SERVER_NAME,
          version: SERVER_VERSION
        },
        capabilities: {
          tools: {},
          resources: {},
          prompts: {}
        }
      }
    end

    def handle_tools_list
      {
        tools: [
          {
            name: "platform_execute",
            description: "Execute a Platform DSL query. Use this to query and manipulate data in the Usput.ba tourism platform.",
            inputSchema: {
              type: "object",
              properties: {
                query: {
                  type: "string",
                  description: "The DSL query to execute. Examples: 'locations { city: \"Mostar\" } | count', 'schema | stats', 'infrastructure | health'"
                }
              },
              required: [ "query" ]
            }
          },
          {
            name: "platform_status",
            description: "Get the current status of the Platform system",
            inputSchema: {
              type: "object",
              properties: {}
            }
          },
          {
            name: "platform_prompts",
            description: "List prepared prompts for fixes and features",
            inputSchema: {
              type: "object",
              properties: {
                status: {
                  type: "string",
                  enum: [ "pending", "in_progress", "applied", "rejected" ],
                  description: "Filter by prompt status"
                }
              }
            }
          },
          {
            name: "prepare_fix",
            description: "Prepare a fix prompt for later implementation",
            inputSchema: {
              type: "object",
              properties: {
                description: {
                  type: "string",
                  description: "Description of the issue to fix"
                },
                severity: {
                  type: "string",
                  enum: [ "critical", "high", "medium", "low" ],
                  description: "Severity of the issue"
                },
                file: {
                  type: "string",
                  description: "Target file path"
                }
              },
              required: [ "description" ]
            }
          },
          {
            name: "prepare_feature",
            description: "Prepare a feature request for later implementation",
            inputSchema: {
              type: "object",
              properties: {
                description: {
                  type: "string",
                  description: "Description of the feature to add"
                }
              },
              required: [ "description" ]
            }
          }
        ]
      }
    end

    def handle_tools_call(params)
      tool_name = params["name"]
      arguments = params["arguments"] || {}

      case tool_name
      when "platform_execute"
        execute_dsl(arguments["query"])
      when "platform_status"
        get_status
      when "platform_prompts"
        list_prompts(arguments["status"])
      when "prepare_fix"
        prepare_fix(arguments)
      when "prepare_feature"
        prepare_feature(arguments)
      else
        { error: { code: -32602, message: "Unknown tool: #{tool_name}" } }
      end
    end

    def handle_resources_list
      {
        resources: [
          {
            uri: "platform://schema",
            name: "Database Schema",
            description: "Current database schema and statistics",
            mimeType: "application/json"
          },
          {
            uri: "platform://prompts",
            name: "Prepared Prompts",
            description: "List of prepared fix and feature prompts",
            mimeType: "application/json"
          },
          {
            uri: "platform://infrastructure",
            name: "Infrastructure Status",
            description: "Current infrastructure health and status",
            mimeType: "application/json"
          }
        ]
      }
    end

    def handle_resources_read(params)
      uri = params["uri"]

      case uri
      when "platform://schema"
        read_schema
      when "platform://prompts"
        read_prompts
      when "platform://infrastructure"
        read_infrastructure
      else
        { error: { code: -32602, message: "Unknown resource: #{uri}" } }
      end
    end

    def handle_prompts_list
      {
        prompts: [
          {
            name: "analyze_location",
            description: "Analyze a location by ID or name",
            arguments: [
              { name: "location", description: "Location ID or name", required: true }
            ]
          },
          {
            name: "city_report",
            description: "Generate a report for a city",
            arguments: [
              { name: "city", description: "City name", required: true }
            ]
          }
        ]
      }
    end

    def handle_prompts_get(params)
      name = params["name"]
      arguments = params["arguments"] || {}

      case name
      when "analyze_location"
        {
          messages: [
            {
              role: "user",
              content: {
                type: "text",
                text: "Analyze this location: #{arguments['location']}. Use platform_execute to get details."
              }
            }
          ]
        }
      when "city_report"
        {
          messages: [
            {
              role: "user",
              content: {
                type: "text",
                text: "Generate a report for #{arguments['city']}. Include location count, experiences, and issues."
              }
            }
          ]
        }
      else
        { error: { code: -32602, message: "Unknown prompt: #{name}" } }
      end
    end

    # Tool implementations

    def execute_dsl(query)
      return { content: [ { type: "text", text: "Error: query is required" } ], isError: true } if query.blank?

      begin
        result = Platform::DSL.execute(query)
        {
          content: [
            { type: "text", text: JSON.pretty_generate(result) }
          ]
        }
      rescue Platform::DSL::ParseError => e
        { content: [ { type: "text", text: "Parse Error: #{e.message}" } ], isError: true }
      rescue Platform::DSL::ExecutionError => e
        { content: [ { type: "text", text: "Execution Error: #{e.message}" } ], isError: true }
      rescue => e
        { content: [ { type: "text", text: "Error: #{e.message}" } ], isError: true }
      end
    end

    def get_status
      result = Platform::DSL.execute("infrastructure")
      {
        content: [
          { type: "text", text: JSON.pretty_generate(result) }
        ]
      }
    rescue => e
      { content: [ { type: "text", text: "Error: #{e.message}" } ], isError: true }
    end

    def list_prompts(status)
      query = status.present? ? "prompts { status: \"#{status}\" } | list" : "prompts | list"
      result = Platform::DSL.execute(query)
      {
        content: [
          { type: "text", text: JSON.pretty_generate(result) }
        ]
      }
    rescue => e
      { content: [ { type: "text", text: "Error: #{e.message}" } ], isError: true }
    end

    def prepare_fix(arguments)
      description = arguments["description"]
      severity = arguments["severity"]
      file = arguments["file"]

      query = "prepare fix for \"#{description}\""
      query += " severity \"#{severity}\"" if severity.present?
      query += " file \"#{file}\"" if file.present?

      result = Platform::DSL.execute(query)
      {
        content: [
          { type: "text", text: JSON.pretty_generate(result) }
        ]
      }
    rescue => e
      { content: [ { type: "text", text: "Error: #{e.message}" } ], isError: true }
    end

    def prepare_feature(arguments)
      description = arguments["description"]

      result = Platform::DSL.execute("prepare feature \"#{description}\"")
      {
        content: [
          { type: "text", text: JSON.pretty_generate(result) }
        ]
      }
    rescue => e
      { content: [ { type: "text", text: "Error: #{e.message}" } ], isError: true }
    end

    # Resource readers

    def read_schema
      result = Platform::DSL.execute("schema | stats")
      {
        contents: [
          {
            uri: "platform://schema",
            mimeType: "application/json",
            text: JSON.pretty_generate(result)
          }
        ]
      }
    rescue => e
      { error: { code: -32603, message: e.message } }
    end

    def read_prompts
      result = Platform::DSL.execute("prompts | list")
      {
        contents: [
          {
            uri: "platform://prompts",
            mimeType: "application/json",
            text: JSON.pretty_generate(result)
          }
        ]
      }
    rescue => e
      { error: { code: -32603, message: e.message } }
    end

    def read_infrastructure
      result = Platform::DSL.execute("infrastructure | health")
      {
        contents: [
          {
            uri: "platform://infrastructure",
            mimeType: "application/json",
            text: JSON.pretty_generate(result)
          }
        ]
      }
    rescue => e
      { error: { code: -32603, message: e.message } }
    end

    def write_response(response)
      $stdout.puts JSON.generate(response)
      $stdout.flush
    end

    def write_error(code, message, id = nil)
      response = {
        jsonrpc: "2.0",
        id: id,
        error: { code: code, message: message }
      }
      write_response(response)
    end
  end
end
