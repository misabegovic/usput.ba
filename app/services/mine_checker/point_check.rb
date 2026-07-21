# Point-vs-danger-band check (docs/mine_checker/SPEC.md §5), static engine.
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

    def out_of_coverage? = !bbox_contains?(@lat, @lon)

    def dangerous? = index.band_at(@lat, @lon) == "danger"
  end
end
