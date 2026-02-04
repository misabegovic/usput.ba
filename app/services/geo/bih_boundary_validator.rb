# frozen_string_literal: true

module Geo
  # Validates whether geographic coordinates fall within Bosnia and Herzegovina.
  #
  # Uses a polygon approximation of the actual BiH borders instead of a simple
  # bounding box, which provides much more accurate validation especially along
  # the eastern border with Serbia (Drina river).
  #
  # The polygon is traced clockwise starting from the northwest corner near Bihać.
  #
  # Usage:
  #   Geo::BihBoundaryValidator.inside_bih?(43.8563, 18.4131) # => true (Sarajevo)
  #   Geo::BihBoundaryValidator.inside_bih?(44.82, 20.45)     # => false (Belgrade area)
  #   Geo::BihBoundaryValidator.inside_bih?(44.38, 19.20)     # => false (Loznica, Serbia)
  #
  class BihBoundaryValidator
    # BiH border polygon traced clockwise from northwest
    # These coordinates approximate the actual border with extra precision
    # along the eastern border with Serbia (Drina river) to prevent
    # locations from Serbia being incorrectly classified as BiH.
    #
    # The polygon includes approximately 45 points for accurate border tracing.
    BIH_BORDER_POLYGON = [
      # Northwest - Croatian border near Bihać
      [ 44.95, 15.73 ],
      [ 45.05, 15.78 ],
      [ 45.15, 15.95 ],
      [ 45.20, 16.10 ],

      # Northern border with Croatia - moving east
      [ 45.25, 16.35 ],
      [ 45.27, 16.60 ],
      [ 45.26, 16.85 ],
      [ 45.22, 17.15 ],
      [ 45.20, 17.45 ],
      [ 45.15, 17.75 ],
      [ 45.08, 18.05 ],
      [ 45.05, 18.35 ],
      [ 45.02, 18.55 ],

      # Northeast - Brčko district and Posavina
      [ 44.95, 18.75 ],
      [ 44.88, 18.85 ],
      [ 44.87, 18.95 ],

      # Northeast corner - Semberija region (includes Bijeljina)
      # Updated 2026-01-17: Extended polygon to include Bijeljina (44.75, 19.21)
      # The border follows the Sava river north, then turns south along Drina
      [ 44.90, 19.10 ],
      [ 44.88, 19.22 ],  # Along Sava towards Drina confluence
      [ 44.85, 19.28 ],  # Northeast corner - Sava-Drina confluence
      [ 44.80, 19.32 ],  # East of Bijeljina
      [ 44.75, 19.30 ],  # Bijeljina area (city at 44.75, 19.21)
      [ 44.70, 19.25 ],  # South of Bijeljina, towards Zvornik

      # Eastern border - Drina river (critical for excluding Serbia)
      # Updated 2026-01-16: Fixed to include Srebrenica and Potočari
      # The Drina river meanders significantly - traced from actual river course
      [ 44.65, 19.15 ],
      [ 44.60, 19.10 ],  # North of Zvornik
      [ 44.50, 19.10 ],  # Zvornik area - river is narrow here
      [ 44.40, 19.10 ],  # South of Zvornik - Drina at ~19.10-19.11
      [ 44.35, 19.18 ],  # Drina bends east toward Bratunac
      [ 44.30, 19.32 ],  # Near Bratunac - river bends significantly east
      [ 44.20, 19.35 ],  # Bratunac area
      [ 44.15, 19.37 ],  # Between Bratunac and Srebrenica
      [ 44.10, 19.38 ],  # Srebrenica area - include Potočari (19.30)
      [ 44.00, 19.40 ],  # Near Skelani
      [ 43.90, 19.40 ],
      [ 43.80, 19.38 ],  # Near Višegrad
      [ 43.70, 19.40 ],
      [ 43.60, 19.38 ],
      [ 43.50, 19.32 ],
      [ 43.40, 19.22 ],
      [ 43.30, 19.12 ],  # Near Foča

      # Southeast - border with Montenegro
      [ 43.20, 18.95 ],
      [ 43.10, 18.85 ],
      [ 43.00, 18.70 ],
      [ 42.90, 18.55 ],
      [ 42.80, 18.45 ],
      [ 42.70, 18.35 ],  # Near Trebinje
      [ 42.60, 18.20 ],
      [ 42.55, 18.05 ],

      # Southern border with Montenegro/Croatia
      [ 42.58, 17.85 ],
      [ 42.65, 17.65 ],
      [ 42.75, 17.50 ],
      [ 42.85, 17.40 ],

      # Southwest - Neum area (BiH coast)
      [ 42.92, 17.55 ],
      [ 42.95, 17.45 ],
      [ 43.00, 17.35 ],
      [ 43.08, 17.28 ],
      [ 43.18, 17.25 ],

      # Western border with Croatia - moving north
      [ 43.30, 17.15 ],
      [ 43.45, 17.00 ],
      [ 43.60, 16.85 ],
      [ 43.75, 16.75 ],
      [ 43.90, 16.60 ],
      [ 44.05, 16.45 ],
      [ 44.20, 16.30 ],
      [ 44.35, 16.15 ],
      [ 44.50, 16.00 ],
      [ 44.65, 15.88 ],
      [ 44.80, 15.78 ],

      # Close the polygon back to start
      [ 44.95, 15.73 ]
    ].freeze

    # Simple bounding box for quick pre-filtering
    # Slightly larger than the polygon to catch edge cases
    BOUNDING_BOX = {
      min_lat: 42.50,
      max_lat: 45.30,
      min_lng: 15.70,
      max_lng: 19.50  # Extended to cover Drina border accurately
    }.freeze

    class << self
      # Check if coordinates are inside Bosnia and Herzegovina
      #
      # @param lat [Float, String, Numeric] Latitude
      # @param lng [Float, String, Numeric] Longitude
      # @return [Boolean] true if coordinates are inside BiH
      def inside_bih?(lat, lng)
        return false if lat.blank? || lng.blank?

        lat = lat.to_f
        lng = lng.to_f

        # Quick bounding box check first (fast rejection)
        return false unless inside_bounding_box?(lat, lng)

        # Precise polygon check
        point_in_polygon?(lat, lng, BIH_BORDER_POLYGON)
      end

      # Check if coordinates are outside Bosnia and Herzegovina
      #
      # @param lat [Float, String, Numeric] Latitude
      # @param lng [Float, String, Numeric] Longitude
      # @return [Boolean] true if coordinates are outside BiH
      def outside_bih?(lat, lng)
        !inside_bih?(lat, lng)
      end

      # Get the distance to the nearest BiH border point (approximate)
      # Useful for debugging and edge cases
      #
      # @param lat [Float] Latitude
      # @param lng [Float] Longitude
      # @return [Float] Approximate distance in kilometers to nearest border point
      def distance_to_border(lat, lng)
        lat = lat.to_f
        lng = lng.to_f

        min_distance = Float::INFINITY

        BIH_BORDER_POLYGON.each do |point|
          distance = haversine_distance(lat, lng, point[0], point[1])
          min_distance = distance if distance < min_distance
        end

        min_distance
      end

      private

      # Quick bounding box check for fast rejection
      def inside_bounding_box?(lat, lng)
        lat >= BOUNDING_BOX[:min_lat] &&
          lat <= BOUNDING_BOX[:max_lat] &&
          lng >= BOUNDING_BOX[:min_lng] &&
          lng <= BOUNDING_BOX[:max_lng]
      end

      # Ray casting algorithm for point-in-polygon test
      # Casts a ray from the point to the right and counts intersections
      # with polygon edges. Odd count = inside, even count = outside.
      #
      # @param lat [Float] Point latitude (y coordinate)
      # @param lng [Float] Point longitude (x coordinate)
      # @param polygon [Array<Array<Float>>] Array of [lat, lng] pairs
      # @return [Boolean] true if point is inside polygon
      def point_in_polygon?(lat, lng, polygon)
        n = polygon.length
        inside = false

        j = n - 1
        (0...n).each do |i|
          yi, xi = polygon[i]
          yj, xj = polygon[j]

          # Check if the ray from (lat, lng) going right intersects this edge
          if ((yi > lat) != (yj > lat)) &&
             (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
            inside = !inside
          end

          j = i
        end

        inside
      end

      # Calculate distance between two points using Haversine formula
      # @return [Float] Distance in kilometers
      def haversine_distance(lat1, lng1, lat2, lng2)
        r = 6371 # Earth's radius in kilometers

        dlat = to_radians(lat2 - lat1)
        dlng = to_radians(lng2 - lng1)

        a = Math.sin(dlat / 2)**2 +
            Math.cos(to_radians(lat1)) * Math.cos(to_radians(lat2)) *
            Math.sin(dlng / 2)**2

        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

        r * c
      end

      def to_radians(degrees)
        degrees * Math::PI / 180
      end
    end
  end
end
