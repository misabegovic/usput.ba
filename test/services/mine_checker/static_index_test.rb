require "test_helper"
require_relative "../../support/static_artifacts"

# The static engine against synthetic artifacts with exactly known truth.
class MineChecker::StaticIndexTest < ActiveSupport::TestCase
  setup do
    # One directory per test worker: tests of one class run in several processes.
    @dir = Rails.root.join("tmp/static_index_test-#{Process.pid}").to_s
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

  test "km2 by row spans counts exactly what the cell-by-cell walk counts" do
    grid = @index.meta["grids"]["inside"]
    lat = (@area[:south] + @area[:north]) / 2.0
    lon = (@area[:west] + @area[:east]) / 2.0

    [ [ lat, lon ], [ @area[:north], @area[:east] ], [ lat + 0.004, lon - 0.006 ] ].each do |point_lat, point_lon|
      [ 300, 700, 5_000 ].each do |radius|
        assert_equal cell_by_cell_km2(grid, point_lat, point_lon, radius),
                     @index.suspected_km2_within(point_lat, point_lon, radius),
                     "at #{point_lat},#{point_lon} within #{radius} m"
      end
    end
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

  private

  # The walk suspected_km2_within replaced, kept as the oracle.
  def cell_by_cell_km2(grid, lat, lon, radius_m)
    r_lat = (radius_m / (grid["dlat"] * 111_320.0)).ceil
    r_lon = (radius_m / (grid["dlon"] * 111_320.0 * Math.cos(lat * Math::PI / 180))).ceil
    r0 = @index.send(:row_for, grid, lat)
    c0 = @index.send(:col_for, grid, lon)
    count = 0
    (r0 - r_lat).upto(r0 + r_lat) do |r|
      next if r.negative? || r >= grid["rows"]

      (c0 - r_lon).upto(c0 + r_lon) do |c|
        next if c.negative? || c >= grid["cols"]
        next unless ((r - r0) * 2.0 / (2 * r_lat))**2 + ((c - c0) * 2.0 / (2 * r_lon))**2 <= 1.0

        count += 1 if @index.send(:bit_set_in?, "inside", grid, r, c)
      end
    end
    (count * (grid["cell_m"] / 1000.0)**2).round(1)
  end
end
