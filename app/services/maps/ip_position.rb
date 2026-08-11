# frozen_string_literal: true

module Maps
  # An approximate position from the request's IP, for the moment before the
  # browser has answered — and for the traveller whose browser never will.
  # Accurate to a city at best; it orders a deck honestly and decides nothing.
  class IpPosition
    ENDPOINT = "http://ip-api.com/json"
    TIMEOUT = 2
    CACHE_TTL = 12.hours

    def self.call(ip)
      new(ip).call
    end

    def initialize(ip)
      @ip = ip
    end

    # A private address is the developer's own machine or a misconfigured proxy;
    # either way the lookup would describe the server, not the traveller.
    def call
      return nil if @ip.blank? || private_address?

      Rails.cache.fetch("ip_position/#{@ip}", expires_in: CACHE_TTL, skip_nil: true) { lookup }
    end

    private

    def private_address?
      address = IPAddr.new(@ip)
      address.loopback? || address.private? || address.link_local?
    rescue IPAddr::InvalidAddressError
      true
    end

    def lookup
      response = Net::HTTP.get_response(URI("#{ENDPOINT}/#{@ip}?fields=status,lat,lon"),
                                        nil, open_timeout: TIMEOUT, read_timeout: TIMEOUT)
      return nil unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      return nil unless body["status"] == "success" && body["lat"] && body["lon"]

      [ body["lat"].to_f, body["lon"].to_f ]
    # Never a failure the traveller sees: a deck dealt from the country default
    # beats a deck that did not load.
    rescue StandardError => e
      Rails.logger.info("[Maps::IpPosition] lookup failed for #{@ip}: #{e.class}")
      nil
    end
  end
end
