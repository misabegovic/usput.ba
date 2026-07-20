# Route-vs-suspected-areas check (docs/mine_checker/SPEC.md §5, §8).
#
#   result = MineChecker::RouteCheck.call(points: [[lat, lon], ...])
#
# The whole LineString is tested, so a segment that crosses a buffer blocks
# even when every vertex individually lies clear. Coverage is decided by the
# LINE, not the endpoints: a route that transits BiH between two points
# outside the bbox is still checked (conservative — see SPEC asymmetry rule).
module MineChecker
  class RouteCheck < BaseCheck
    def initialize(points:)
      @points = Array(points).map { |(lat, lon)| [ Float(lat), Float(lon) ] }
      raise ArgumentError, "route needs at least 2 points" if @points.size < 2

      super()
    end

    private

    def wkt
      coords = @points.map { |(lat, lon)| "#{lon} #{lat}" }.join(", ")
      "SRID=4326;LINESTRING(#{coords})"
    end

    def out_of_coverage?
      lon_min, lat_min, lon_max, lat_max = Config.bih_bbox
      bbox_wkt = "SRID=4326;POLYGON((#{lon_min} #{lat_min}, #{lon_max} #{lat_min}, " \
                 "#{lon_max} #{lat_max}, #{lon_min} #{lat_max}, #{lon_min} #{lat_min}))"
      sql = ActiveRecord::Base.sanitize_sql(
        [ "SELECT ST_Intersects(ST_GeogFromText(:line)::geometry, ST_GeogFromText(:bbox)::geometry) AS hit",
         { line: wkt, bbox: bbox_wkt } ]
      )
      !ActiveRecord::Base.connection.select_value(sql)
    end
  end
end
