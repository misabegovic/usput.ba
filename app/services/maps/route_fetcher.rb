module Maps
  # Fetches a walking route between two points from OpenRouteService.
  # Returns { points: [[lat, lng], ...], distance_m: Integer, duration_s: Integer }
  # or nil on any failure — callers draw nothing rather than guess a path.
  class RouteFetcher
    WALKING = "foot-walking".freeze
    DRIVING = "driving-car".freeze
    PROFILES = [ WALKING, DRIVING ].freeze

    def self.call(from_lat:, from_lng:, to_lat:, to_lng:, profile: WALKING)
      new.call(from_lat: from_lat, from_lng: from_lng, to_lat: to_lat, to_lng: to_lng, profile: profile)
    end

    def call(from_lat:, from_lng:, to_lat:, to_lng:, profile: WALKING)
      return nil if api_key.blank?
      profile = WALKING unless PROFILES.include?(profile)

      response = connection.post("/v2/directions/#{profile}/geojson") do |request|
        request.headers["Authorization"] = api_key
        request.headers["Content-Type"] = "application/json"
        request.body = { coordinates: [ [ from_lng, from_lat ], [ to_lng, to_lat ] ] }.to_json
      end
      return nil unless response.success?

      parse_with_profile(response.body, profile)
    rescue Faraday::Error, JSON::ParserError => error
      Rails.logger.warn("Maps::RouteFetcher failed: #{error.class}: #{error.message}")
      nil
    end

    private

    def parse(body)
      feature = JSON.parse(body).dig("features", 0)
      return nil unless feature

      {
        points: feature.dig("geometry", "coordinates").map { |lng, lat| [ lat, lng ] },
        distance_m: feature.dig("properties", "summary", "distance").to_i,
        duration_s: feature.dig("properties", "summary", "duration").to_i
      }
    end

    def parse_with_profile(body, profile)
      parsed = parse(body)
      parsed && parsed.merge(profile: profile)
    end

    def api_key
      ENV["OPENROUTESERVICE_API_KEY"]
    end

    def connection
      Faraday.new(url: "https://api.openrouteservice.org") do |faraday|
        faraday.options.timeout = 5
        faraday.options.open_timeout = 3
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
