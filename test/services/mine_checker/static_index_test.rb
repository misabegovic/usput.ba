require "test_helper"
require_relative "../../support/static_artifacts"

# The static engine against synthetic artifacts with exactly known truth.
class MineChecker::StaticIndexTest < ActiveSupport::TestCase
  setup do
    @dir = Rails.root.join("tmp/static_index_test").to_s
    @points = StaticArtifacts.install!(dir: @dir)
    @area = StaticArtifacts::TEST_AREA
    @index = MineChecker::StaticIndex.instance
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "bands match the known truth" do
    assert_equal "danger", @index.band_at(@points[:inside][:lat], @points[:inside][:lon])
    assert_equal "danger", @index.band_at(@points[:near][:lat], @points[:near][:lon])
    assert_equal "caution", @index.band_at(@points[:caution][:lat], @points[:caution][:lon])
    assert_equal "no_known", @index.band_at(@points[:clear][:lat], @points[:clear][:lon])
    assert_equal "out_of_coverage", @index.band_at(@points[:offshore][:lat], @points[:offshore][:lon])
  end

  test "board mine cells cover the area and only its neighbourhood" do
    lat = (@area[:south] + @area[:north]) / 2.0
    lon = (@area[:west] + @area[:east]) / 2.0
    dlat = 100 / 111_320.0
    dlon = 100 / (111_320.0 * Math.cos(lat * Math::PI / 180))
    cells = @index.mine_cells(south: lat - 7 * dlat, west: lon - 7 * dlon,
                              dlat: dlat, dlon: dlon, rows: 14, cols: 14)
    assert cells.any?, "board over the area must contain mine cells"
    assert_includes cells, [ 7, 7 ], "the center cell sits inside the area"
    assert_operator cells.size, :<, 14 * 14, "a far corner must stay clear"
  end

  test "segment traversal detects a crossing that misses every vertex" do
    lat = (@area[:south] + @area[:north]) / 2.0
    assert @index.danger_on_segment?(lat, @area[:west] - 0.05, lat, @area[:east] + 0.05)
    assert_not @index.danger_on_segment?(@area[:north] + 0.1, @area[:west] - 0.05,
                                         @area[:north] + 0.1, @area[:east] + 0.05)
  end

  test "km2 aggregate reflects the synthetic area size" do
    lat = (@area[:south] + @area[:north]) / 2.0
    lon = (@area[:west] + @area[:east]) / 2.0
    km2 = @index.suspected_km2_within(lat, lon, 5_000)
    # ~780 m x ~800 m rectangle ≈ 0.6 km², dilated by the 36 m build margin
    assert_in_delta 0.7, km2, 0.3
  end

  test "overlay artifacts serve overview dots and boundary tiles" do
    overview = JSON.parse(@index.overview_json)
    assert_equal 1, overview["features"].size
    tiles = @index.tile_features(@area[:west] - 0.1, @area[:south] - 0.1,
                                 @area[:east] + 0.1, @area[:north] + 0.1)
    assert_equal 1, tiles["features"].size
    assert_equal({}, tiles["features"].first["properties"])
  end

  test "missing artifacts fail closed as unavailable" do
    ENV["MINE_STATIC_DIR"] = Rails.root.join("tmp/definitely_missing_static").to_s
    MineChecker::StaticIndex.reset!
    assert_equal "unavailable", MineChecker::StaticIndex.instance.band_at(44.0, 17.5)
  end
end
