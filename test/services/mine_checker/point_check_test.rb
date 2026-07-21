require "test_helper"
require_relative "../../support/static_artifacts"

# SPEC §5/§8 — point checks against the static engine, with synthetic
# artifacts whose truth is known exactly.
class MineChecker::PointCheckTest < ActiveSupport::TestCase
  setup do
    @dir = Rails.root.join("tmp/point_check_test").to_s
    @points = StaticArtifacts.install!(dir: @dir)
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "point inside a suspected area is blocked" do
    result = MineChecker::PointCheck.call(**@points[:inside])
    assert_equal :blocked, result.verdict
    assert result.blocked?
  end

  test "point within the danger buffer is blocked" do
    result = MineChecker::PointCheck.call(**@points[:near])
    assert_equal :blocked, result.verdict
  end

  test "clear point reports no known intersections, never safe" do
    result = MineChecker::PointCheck.call(**@points[:clear])
    assert_equal :no_known_intersections, result.verdict
    assert_not result.blocked?
  end

  test "point outside BiH is out of coverage" do
    result = MineChecker::PointCheck.call(**@points[:offshore])
    assert_equal :out_of_coverage, result.verdict
  end

  test "old data keeps answering — staleness does not block" do
    travel_to Date.current + MineChecker::Config.staleness_days.days + 1.day do
      assert_equal :no_known_intersections, MineChecker::PointCheck.call(**@points[:clear]).verdict
      assert_equal :blocked, MineChecker::PointCheck.call(**@points[:inside]).verdict
    end
  end

  test "missing artifacts fail closed" do
    ENV["MINE_STATIC_DIR"] = Rails.root.join("tmp/nonexistent_artifacts").to_s
    MineChecker::StaticIndex.reset!
    result = MineChecker::PointCheck.call(**@points[:clear])
    assert_equal :data_stale, result.verdict
    assert result.blocked?
  end

  test "every check is audited, blocked and passed alike" do
    assert_difference -> { MineCheckAudit.count }, 2 do
      MineChecker::PointCheck.call(**@points[:inside])
      MineChecker::PointCheck.call(**@points[:clear])
    end
    verdicts = MineCheckAudit.order(:id).last(2).map(&:verdict)
    assert_equal %w[blocked no_known_intersections], verdicts
  end

  test "results carry the data date and check time" do
    result = MineChecker::PointCheck.call(**@points[:clear])
    assert_equal Date.current, result.data_as_of
    assert result.checked_at.present?
  end
end
