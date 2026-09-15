# frozen_string_literal: true

require "test_helper"

class VisitorIpTest < ActiveSupport::TestCase
  # The shape of the Rollbar report on 2026-08-27: a German mobile visitor whose
  # forwarding chain named only a Paris CDN edge.
  test "prefers the Cloudflare address over the relaying edge" do
    request = build_request("80.187.102.76", forwarded_for: "104.23.225.85, 79.127.178.82")

    assert_equal "80.187.102.76", VisitorIp.from(request)
  end

  test "falls back to remote_ip when Cloudflare set no header" do
    request = build_request(nil, forwarded_for: "79.127.178.82")

    assert_equal "79.127.178.82", VisitorIp.from(request)
  end

  test "falls back when the header is not an address" do
    request = build_request("not-an-ip", forwarded_for: "79.127.178.82")

    assert_equal "79.127.178.82", VisitorIp.from(request)
  end

  test "returns nil without a request" do
    assert_nil VisitorIp.from(nil)
  end

  private

  def build_request(cf_connecting_ip, forwarded_for:)
    env = {
      "REMOTE_ADDR" => "10.0.0.1",
      "HTTP_X_FORWARDED_FOR" => forwarded_for
    }
    env["HTTP_CF_CONNECTING_IP"] = cf_connecting_ip if cf_connecting_ip
    ActionDispatch::Request.new(env)
  end
end
