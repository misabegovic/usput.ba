# frozen_string_literal: true

# The address of the person, not of the machine that relayed them.
#
# Requests arrive through Cloudflare and a CDN, and the forwarding chain that
# reaches Rails carries only those hops — so remote_ip names an edge server,
# often in another country, for every visitor behind it. Cloudflare puts the
# real one in CF-Connecting-IP.
#
# Not used for rate limiting: a request reaching the origin directly can set
# this header to anything, and a throttle must not be steerable by the person
# being throttled.
class VisitorIp
  HEADER = "HTTP_CF_CONNECTING_IP"

  def self.from(request)
    return nil unless request

    forwarded = request.get_header(HEADER).presence
    return forwarded if forwarded && valid?(forwarded)

    request.remote_ip
  end

  def self.valid?(value)
    IPAddr.new(value)
    true
  rescue IPAddr::InvalidAddressError
    false
  end
  private_class_method :valid?
end
