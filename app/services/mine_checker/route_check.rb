# Route-vs-danger-band check (docs/mine_checker/SPEC.md §5, §8), static
# engine. The whole polyline is tested via grid traversal, so a segment that
# crosses the danger band blocks even when every vertex individually lies
# clear. Coverage is decided by the LINE, not the endpoints: a route that
# transits BiH between two points outside the bbox is still checked
# (conservative — see SPEC asymmetry rule).
module MineChecker
  class RouteCheck < BaseCheck
    def initialize(points:)
      @points = Array(points).map { |(lat, lon)| [ Float(lat), Float(lon) ] }
      raise ArgumentError, "route needs at least 2 points" if @points.size < 2

      super()
    end

    private

    def out_of_coverage?
      return false if @points.any? { |(lat, lon)| bbox_contains?(lat, lon) }

      @points.each_cons(2).none? { |a, b| segment_touches_bbox?(a, b) }
    end

    def dangerous?
      @points.each_cons(2).any? do |(lat1, lon1), (lat2, lon2)|
        index.danger_on_segment?(lat1, lon1, lat2, lon2)
      end
    end

    # Conservative segment-vs-bbox test: sample densely along the segment.
    def segment_touches_bbox?(a, b)
      50.times do |i|
        t = i / 49.0
        lat = a[0] + (b[0] - a[0]) * t
        lon = a[1] + (b[1] - a[1]) * t
        return true if bbox_contains?(lat, lon)
      end
      false
    end
  end
end
