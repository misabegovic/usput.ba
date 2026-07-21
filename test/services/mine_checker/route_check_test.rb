require "test_helper"
require_relative "../../support/static_artifacts"

# SPEC §8 — route checks. The crucial case: a segment that crosses the
# danger band blocks even when both endpoints are individually clear.
class MineChecker::RouteCheckTest < ActiveSupport::TestCase
  setup do
    @dir = Rails.root.join("tmp/route_check_test").to_s
    @points = StaticArtifacts.install!(dir: @dir)
    @area = StaticArtifacts::TEST_AREA
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "route whose segment crosses the danger band blocks despite clear endpoints" do
    lat = (@area[:south] + @area[:north]) / 2.0
    west_pt = [ lat, @area[:west] - 0.05 ]
    east_pt = [ lat, @area[:east] + 0.05 ]
    assert_equal :no_known_intersections, MineChecker::PointCheck.call(lat: west_pt[0], lon: west_pt[1]).verdict
    assert_equal :no_known_intersections, MineChecker::PointCheck.call(lat: east_pt[0], lon: east_pt[1]).verdict

    result = MineChecker::RouteCheck.call(points: [ west_pt, east_pt ])
    assert_equal :blocked, result.verdict
  end

  test "route fully clear reports no known intersections" do
    c = @points[:clear]
    result = MineChecker::RouteCheck.call(points: [ [ c[:lat], c[:lon] ], [ c[:lat] + 0.01, c[:lon] + 0.01 ] ])
    assert_equal :no_known_intersections, result.verdict
  end

  test "route entirely outside BiH is out of coverage" do
    result = MineChecker::RouteCheck.call(points: [ [ 42.0, 14.5 ], [ 41.9, 14.4 ] ])
    assert_equal :out_of_coverage, result.verdict
  end

  test "route transiting BiH between two out-of-bbox endpoints is still checked" do
    lat = (@area[:south] + @area[:north]) / 2.0
    result = MineChecker::RouteCheck.call(points: [ [ lat, 15.0 ], [ lat, 20.0 ] ])
    assert_equal :blocked, result.verdict
  end

  test "route with fewer than 2 points is rejected" do
    assert_raises(ArgumentError) { MineChecker::RouteCheck.call(points: [ [ 44.0, 17.0 ] ]) }
  end

  test "old data keeps answering for routes — staleness does not block" do
    c = @points[:clear]
    travel_to Date.current + MineChecker::Config.staleness_days.days + 1.day do
      result = MineChecker::RouteCheck.call(points: [ [ c[:lat], c[:lon] ], [ c[:lat] + 0.01, c[:lon] ] ])
      assert_equal :no_known_intersections, result.verdict
    end
  end
end
