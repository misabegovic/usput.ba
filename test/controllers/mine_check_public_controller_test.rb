require "test_helper"
require_relative "../support/mine_checker_fixtures"

# Public mine-proximity check. The contract under test: coarse bands only,
# no distances or geometry in responses, warnings never suppressed, audits
# recorded, fail-closed without data.
class MineCheckPublicControllerTest < ActionDispatch::IntegrationTest
  setup do
    @points = MineCheckerFixtures.install!
  end

  test "page renders with the warning block" do
    get mine_check_path
    assert_response :success
    assert_match I18n.t("mine_check_public.warning_title"), response.body
    assert_match "bhmac.org", response.body
  end

  test "point inside a suspected area returns the danger band" do
    post mine_check_query_path, params: { lat: @points[:inside][:lat], lon: @points[:inside][:lon] }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "danger", body["band"]
    assert_not body["stale"], "fixtures carry a fresh data_as_of"
  end

  test "stale data never suppresses a danger warning" do
    travel_to Date.current + MineChecker::Config.staleness_days.days + 1.day do
      post mine_check_query_path, params: { lat: @points[:inside][:lat], lon: @points[:inside][:lon] }, as: :json
      body = response.parsed_body
      assert_equal "danger", body["band"], "warnings must fire regardless of staleness"
      assert body["stale"]
    end
  end

  test "point 500m-2km away returns the caution band" do
    conn = ActiveRecord::Base.connection
    caution = nil
    point = @points[:near].dup
    30.times do
      point = { lat: point[:lat], lon: point[:lon] + 0.002 }
      d = MineCheckerFixtures.distance_to_rich(conn, point)
      if d > 600 && d < 1_900
        caution = point
        break
      end
    end
    assert caution, "could not derive a 500m-2km test point"

    post mine_check_query_path, params: { lat: caution[:lat], lon: caution[:lon] }, as: :json
    assert_response :success
    assert_equal "caution", response.parsed_body["band"]
  end

  test "clear point returns no_known with data date, never a distance" do
    post mine_check_query_path, params: { lat: @points[:clear][:lat], lon: @points[:clear][:lon] }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "no_known", body["band"]
    assert body.key?("data_as_of")
    assert_nil body["distance"]
    assert_nil body["distance_m"]
    refute_match(/matches|geom|polygon/i, response.body)
  end

  test "offshore point is out of coverage" do
    post mine_check_query_path, params: { lat: 42.0, lon: 14.5 }, as: :json
    assert_equal "out_of_coverage", response.parsed_body["band"]
  end

  test "empty dataset fails closed as unavailable" do
    MineArea.delete_all
    post mine_check_query_path, params: { lat: 44.0, lon: 17.5 }, as: :json
    assert_equal "unavailable", response.parsed_body["band"]
  end

  test "invalid coordinates are rejected" do
    post mine_check_query_path, params: { lat: "abc", lon: "def" }, as: :json
    assert_response :unprocessable_entity
  end

  test "every check is audited with the band as verdict" do
    assert_difference -> { MineCheckAudit.count }, 1 do
      post mine_check_query_path, params: { lat: @points[:inside][:lat], lon: @points[:inside][:lon] }, as: :json
    end
    audit = MineCheckAudit.order(:id).last
    assert_equal "PublicMineCheck", audit.content_type
    assert_equal "danger", audit.verdict
  end
end
