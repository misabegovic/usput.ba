# Point-vs-suspected-areas check (docs/mine_checker/SPEC.md §5).
#
#   result = MineChecker::PointCheck.call(lat: 44.5, lon: 17.3)
module MineChecker
  class PointCheck < BaseCheck
    def initialize(lat:, lon:)
      @lat = Float(lat)
      @lon = Float(lon)
      super()
    end

    private

    def wkt = "SRID=4326;POINT(#{@lon} #{@lat})"

    def out_of_coverage? = !bbox_contains?(@lat, @lon)
  end
end
