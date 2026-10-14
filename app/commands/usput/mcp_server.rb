# frozen_string_literal: true

module Usput
  # The usput commands as MCP tools, on the official Ruby SDK. One server is
  # built per caller, acting as that caller: over stdio for a local agent
  # (bin/usput mcp), over HTTP for a remote one (MCPController). Over HTTP
  # only reading commands are offered (wiki/initiatives/cli-and-mcp.md).
  module MCPServer
    NAME = "usput"
    VERSION = "1.0.0"
    BRAIN_PAGES = { "usput://brain/index" => "wiki/index.md", "usput://brain/state" => "wiki/state.md",
                    "usput://brain/features" => "wiki/product/features.md" }.freeze

    module_function

    def build(actor:, decides: false)
      commands = Commands.all.select { |command| decides || command.reads? }
      server = ::MCP::Server.new(name: NAME, title: "Usput.ba", version: VERSION,
                                 instructions: instructions(actor, decides), resources: brain_resources)
      commands.each { |command| define(server, command, actor) }
      server.resources_read_handler do |params|
        path = BRAIN_PAGES[params[:uri]] or raise ::MCP::Server::ResourceNotFoundError.new(params[:uri], params)
        [ { uri: params[:uri], mimeType: "text/markdown", text: Rails.root.join(path).read } ]
      end
      server
    end

    def define(server, command, actor)
      server.define_tool(name: command.tool_name, description: command.summary,
                         input_schema: command.input_schema,
                         annotations: { read_only_hint: command.reads?, destructive_hint: false,
                                        idempotent_hint: true, open_world_hint: false }) do |server_context:, **args|
        MCPServer.respond(command, actor, args)
      end
    end

    def respond(command, actor, args)
      result = I18n.with_locale(:bs) { command.call(actor:, **args) }
      ::MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(result) } ])
    rescue Command::Denied, Command::Invalid, ActiveRecord::RecordNotFound => e
      ::MCP::Tool::Response.new([ { type: "text", text: e.message } ], error: true)
    end

    def brain_resources
      BRAIN_PAGES.map do |uri, path|
        ::MCP::Resource.new(uri:, name: File.basename(path, ".md"), title: "Brain: #{path}", mime_type: "text/markdown")
      end
    end

    def instructions(actor, decides)
      who = actor ? "#{actor.username} (#{actor.user_type})" : "nobody signed in, so only public reads"
      "Usput.ba, a tourism platform for Bosnia and Herzegovina. Ids are uuids. Content is in Bosnian. " \
        "Acting as #{who}. #{decides ? 'Deciding tools are offered; each decision is recorded.' : 'Read-only tools.'}"
    end
  end
end
