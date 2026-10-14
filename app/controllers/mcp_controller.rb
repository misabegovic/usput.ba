# frozen_string_literal: true

# The MCP server over HTTP, for remote agents. A caller presents a personal
# access token (bin/usput tokens issue) as a bearer token and acts as its
# user. In this first release only admins may call it and only reading tools
# are offered (wiki/initiatives/cli-and-mcp.md). Each POST is one JSON-RPC
# message answered in full: no session, no stream.
class MCPController < ActionController::API
  ROLES = %w[admin].freeze

  before_action :authenticate

  def create
    response_body = Usput::MCPServer.build(actor: @token.user).handle_json(request.raw_post)
    Rails.logger.info("[mcp] #{@token.user.uuid} token=#{@token.id} #{rpc_method}")
    response_body ? render(json: response_body) : head(:accepted)
  end

  # Streamable HTTP's GET opens a server-to-client stream, which this server
  # does not keep.
  def stream
    head :method_not_allowed, allow: "POST"
  end

  private

  def authenticate
    @token = APIToken.authenticate(request.authorization.to_s.delete_prefix("Bearer "))
    return head(:unauthorized, "WWW-Authenticate" => "Bearer") if @token.nil?
    return head(:forbidden) unless ROLES.include?(@token.user.user_type) && !@token.user.blocked?

    @token.touch_used!
  end

  def rpc_method
    JSON.parse(request.raw_post)["method"]
  rescue JSON::ParserError, TypeError, NoMethodError
    "unparsed"
  end
end
