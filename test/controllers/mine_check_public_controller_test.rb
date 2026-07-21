require "test_helper"
require_relative "../support/static_artifacts"

# Public mine-proximity check on the static engine: coarse bands only, no
# distances or metadata in responses, warnings never suppressed, audits
# recorded, fail-closed without artifacts.
class MineCheckPublicControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dir = Rails.root.join("tmp/mine_check_public_test").to_s
    @points = StaticArtifacts.install!(dir: @dir)
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "page renders with the warning block" do
    get mine_check_path
    assert_response :success
    assert_match I18n.t("mine_check_public.warning_title"), response.body
    assert_match "bhmac.org", response.body
  end

  test "bands for known points" do
    { inside: "danger", near: "danger", caution: "caution", clear: "no_known" }.each do |key, band|
      post mine_check_query_path, params: @points[key], as: :json
      assert_equal band, response.parsed_body["band"], "point #{key}"
    end
  end

  test "clear point carries data date but never distances" do
    post mine_check_query_path, params: @points[:clear], as: :json
    body = response.parsed_body
    assert_equal "no_known", body["band"]
    assert body.key?("data_as_of")
    assert_not body["stale"]
    assert_nil body["distance"]
    refute_match(/matches|geom|polygon/i, response.body)
  end

  test "offshore point is out of coverage" do
    post mine_check_query_path, params: @points[:offshore], as: :json
    assert_equal "out_of_coverage", response.parsed_body["band"]
  end

  test "stale artifacts never suppress a danger warning" do
    travel_to Date.current + MineChecker::Config.staleness_days.days + 1.day do
      post mine_check_query_path, params: @points[:inside], as: :json
      body = response.parsed_body
      assert_equal "danger", body["band"]
      assert body["stale"]
    end
  end

  test "missing artifacts fail closed as unavailable" do
    ENV["MINE_STATIC_DIR"] = Rails.root.join("tmp/missing_artifacts").to_s
    MineChecker::StaticIndex.reset!
    post mine_check_query_path, params: { lat: 44.0, lon: 17.5 }, as: :json
    assert_equal "unavailable", response.parsed_body["band"]
  end

  test "invalid coordinates are rejected" do
    post mine_check_query_path, params: { lat: "abc", lon: "def" }, as: :json
    assert_response :unprocessable_entity
  end

  test "areas serves boundary tiles without metadata" do
    area = StaticArtifacts::TEST_AREA
    get mine_check_areas_path(west: area[:west] - 0.1, south: area[:south] - 0.1,
                              east: area[:east] + 0.1, north: area[:north] + 0.1)
    assert_response :success
    body = response.parsed_body
    assert body["features"].any?
    assert_equal({}, body["features"].first["properties"])
  end

  test "areas serves the overview dots" do
    get mine_check_areas_path(overview: 1)
    assert_response :success
    assert_equal "Point", response.parsed_body["features"].first["geometry"]["type"]
  end

  test "areas rejects an oversized viewport" do
    get mine_check_areas_path(west: 15.0, south: 42.0, east: 20.0, north: 46.0)
    assert_response :unprocessable_entity
  end

  test "every check is audited with the band as verdict" do
    assert_difference -> { MineCheckAudit.count }, 1 do
      post mine_check_query_path, params: @points[:inside], as: :json
    end
    audit = MineCheckAudit.order(:id).last
    assert_equal "PublicMineCheck", audit.content_type
    assert_equal "danger", audit.verdict
  end
end
