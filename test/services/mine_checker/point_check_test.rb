require "test_helper"
require_relative "../../support/mine_checker_fixtures"

# SPEC §8 — point checks. Fixtures are derived from the live dataset at
# setup; see MineCheckerFixtures.
class MineChecker::PointCheckTest < ActiveSupport::TestCase
  setup do
    @points = MineCheckerFixtures.install!
  end

  test "point inside a suspected polygon is blocked" do
    result = MineChecker::PointCheck.call(**@points[:inside])
    assert_equal :blocked, result.verdict
    assert result.matches.any?
    assert_equal "2585-III", result.matches.first[:file_id]
    assert_equal 0.0, result.matches.first[:distance_m]
  end

  test "point within the buffer (near) is blocked with a distance" do
    result = MineChecker::PointCheck.call(**@points[:near])
    assert_equal :blocked, result.verdict
    assert result.matches.first[:distance_m].positive?
    assert result.matches.first[:distance_m] <= MineChecker::Config.buffer_m
  end

  test "clear point in BiH reports no known intersections — never 'safe'" do
    result = MineChecker::PointCheck.call(**@points[:clear])
    assert_equal :no_known_intersections, result.verdict
    assert_empty result.matches
    assert_instance_of Date, result.data_as_of
  end

  test "point outside the BiH bbox is out of coverage" do
    result = MineChecker::PointCheck.call(**@points[:offshore])
    assert_equal :out_of_coverage, result.verdict
  end

  test "stale data fails closed as :data_stale" do
    travel_to Date.current + MineChecker::Config.staleness_days.days + 1.day do
      result = MineChecker::PointCheck.call(**@points[:clear])
      assert_equal :data_stale, result.verdict
      assert result.blocked?, "data_stale must be treated as a block"
    end
  end

  test "empty dataset fails closed as :data_stale" do
    ActiveRecord::Base.connection.execute("TRUNCATE mine_areas RESTART IDENTITY")
    result = MineChecker::PointCheck.call(**@points[:clear])
    assert_equal :data_stale, result.verdict
  end

  test "degenerate ring imported as buffered area blocks its center" do
    result = MineChecker::PointCheck.call(**@points[:degenerate_center])
    assert_equal :blocked, result.verdict
  end

  test "every check writes an audit row, passed and blocked alike" do
    assert_difference -> { MineCheckAudit.count }, 2 do
      MineChecker::PointCheck.call(**@points[:inside])
      MineChecker::PointCheck.call(**@points[:clear])
    end
    blocked = MineCheckAudit.order(:id).last(2).first
    assert_equal "blocked", blocked.verdict
    assert blocked.matches.any?
  end

  test "result carries data_as_of and checked_at" do
    result = MineChecker::PointCheck.call(**@points[:clear])
    assert_instance_of Date, result.data_as_of
    assert result.checked_at.present?
  end
end
