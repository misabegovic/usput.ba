require "test_helper"
require_relative "../../support/mine_checker_fixtures"

# SPEC §8 — route checks. The crucial case: a segment that crosses a buffer
# blocks even when both endpoints are individually clear.
class MineChecker::RouteCheckTest < ActiveSupport::TestCase
  setup do
    @points = MineCheckerFixtures.install!
  end

  test "route whose segment crosses a suspected area blocks despite clear endpoints" do
    inside = @points[:inside]
    west = { lat: inside[:lat], lon: inside[:lon] - 0.15 }
    east = { lat: inside[:lat], lon: inside[:lon] + 0.15 }
    # Endpoints individually clear of the fixture polygon (>buffer away):
    assert_operator MineCheckerFixtures.distance_to_rich(ActiveRecord::Base.connection, west),
                    :>, MineChecker::Config.buffer_m
    assert_operator MineCheckerFixtures.distance_to_rich(ActiveRecord::Base.connection, east),
                    :>, MineChecker::Config.buffer_m

    result = MineChecker::RouteCheck.call(points: [ [ west[:lat], west[:lon] ], [ east[:lat], east[:lon] ] ])
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
    inside = @points[:inside]
    # Endpoints far west/east outside the bbox, line passes through the polygon.
    result = MineChecker::RouteCheck.call(points: [
      [ inside[:lat], 15.0 ], [ inside[:lat], inside[:lon] ], [ inside[:lat], 20.0 ]
    ])
    assert_equal :blocked, result.verdict
  end

  test "route with fewer than 2 points is rejected" do
    assert_raises(ArgumentError) { MineChecker::RouteCheck.call(points: [ [ 44.0, 17.0 ] ]) }
  end

  test "stale data fails closed for routes too" do
    c = @points[:clear]
    travel_to Date.current + MineChecker::Config.staleness_days.days + 1.day do
      result = MineChecker::RouteCheck.call(points: [ [ c[:lat], c[:lon] ], [ c[:lat] + 0.01, c[:lon] ] ])
      assert_equal :data_stale, result.verdict
    end
  end
end
