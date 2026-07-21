require "zlib"

# Builds synthetic static-engine artifacts for tests — pure Ruby, no PostGIS.
# The artifacts use the same format as scripts/mine_checker/build_static_artifacts.rb;
# "areas" are axis-aligned rectangles, and each mask marks cells intersecting
# the rectangle expanded by that band's radius (same conservative semantics
# as the real builder).
module StaticArtifacts
  BBOX = [ 15.5, 42.4, 19.7, 45.4 ].freeze # west, south, east, north
  CELL_SIZES = { "inside" => 50, "danger" => 100, "caution" => 200 }.freeze
  EXPAND_M = { "inside" => 36, "danger" => 571, "caution" => 2142 }.freeze

  # The default synthetic suspected area used across mine tests: a
  # ~600 x 800 m rectangle in central BiH, far from fixture locations.
  TEST_AREA = { south: 44.20, west: 17.30, north: 44.207, east: 17.31 }.freeze

  # Points with known truth relative to TEST_AREA.
  POINTS = {
    inside: { lat: 44.2035, lon: 17.305 },
    near: { lat: 44.2035, lon: 17.3135 },     # ~280 m east of the edge -> danger
    caution: { lat: 44.2035, lon: 17.325 },   # ~1.2 km east -> caution
    clear: { lat: 44.2035, lon: 17.50 },      # ~15 km east -> no_known
    offshore: { lat: 42.0, lon: 14.5 }
  }.freeze

  module_function

  # Build artifacts into `dir` and point the engine at them.
  # areas: array of {south:, west:, north:, east:} rectangles.
  def install!(dir:, data_as_of: Date.current, areas: [ TEST_AREA ])
    FileUtils.rm_rf(dir)
    FileUtils.mkdir_p(File.join(dir, "tiles"))
    west, south, east, north = BBOX
    mid_lat = (south + north) / 2.0

    grids = {}
    CELL_SIZES.each do |name, cell_m|
      dlat = cell_m / 111_320.0
      dlon = cell_m / (111_320.0 * Math.cos(mid_lat * Math::PI / 180))
      rows = ((north - south) / dlat).ceil
      cols = ((east - west) / dlon).ceil
      grids[name] = { "cell_m" => cell_m, "dlat" => dlat, "dlon" => dlon, "rows" => rows, "cols" => cols }

      bits = "\x00".b * ((rows * cols + 7) / 8)
      exp_lat = EXPAND_M[name] / 111_320.0
      exp_lon = EXPAND_M[name] / (111_320.0 * Math.cos(mid_lat * Math::PI / 180))
      areas.each do |area|
        r_min = [ ((area[:south] - exp_lat - south) / dlat).floor, 0 ].max
        r_max = [ ((area[:north] + exp_lat - south) / dlat).floor, rows - 1 ].min
        c_min = [ ((area[:west] - exp_lon - west) / dlon).floor, 0 ].max
        c_max = [ ((area[:east] + exp_lon - west) / dlon).floor, cols - 1 ].min
        r_min.upto(r_max) do |r|
          c_min.upto(c_max) do |c|
            idx = r * cols + c
            bits.setbyte(idx >> 3, bits.getbyte(idx >> 3) | (1 << (idx & 7)))
          end
        end
      end
      File.binwrite(File.join(dir, "#{name}.bin.gz"), Zlib.gzip(bits))
    end

    tile_deg = 0.25
    overview_features = []
    tiles = Hash.new { |h, k| h[k] = [] }
    areas.each do |area|
      feature = {
        type: "Feature",
        geometry: { type: "Polygon", coordinates: [ [
          [ area[:west], area[:south] ], [ area[:east], area[:south] ],
          [ area[:east], area[:north] ], [ area[:west], area[:north] ],
          [ area[:west], area[:south] ]
        ] ] },
        properties: {}
      }
      cx = ((area[:west] + area[:east]) / 2.0).round(2)
      cy = ((area[:south] + area[:north]) / 2.0).round(2)
      overview_features << { type: "Feature", geometry: { type: "Point", coordinates: [ cx, cy ] }, properties: {} }
      tx = ((area[:west] - west) / tile_deg).floor
      ty = ((area[:south] - south) / tile_deg).floor
      tiles[[ tx, ty ]] << feature
    end
    File.binwrite(File.join(dir, "overview.json.gz"),
                  Zlib.gzip(JSON.generate({ type: "FeatureCollection", features: overview_features })))
    tiles.each do |(tx, ty), features|
      File.binwrite(File.join(dir, "tiles", "#{tx}_#{ty}.json.gz"),
                    Zlib.gzip(JSON.generate({ type: "FeatureCollection", truncated: false, features: features })))
    end

    File.write(File.join(dir, "meta.json"), JSON.pretty_generate({
      "data_as_of" => data_as_of.iso8601,
      "bbox" => BBOX,
      "grids" => grids,
      "tile_deg" => tile_deg,
      "built_at" => Time.now.utc.iso8601,
      "source_count" => areas.size
    }))

    ENV["MINE_STATIC_DIR"] = dir
    MineChecker::StaticIndex.reset!
    POINTS
  end

  # Fresh default artifacts shared by the whole suite (built once per process).
  def default_dir
    @default_dir ||= begin
      dir = Rails.root.join("tmp", "static_artifacts_#{Process.pid}").to_s
      install!(dir: dir)
      dir
    end
  end

  def use_default!
    ENV["MINE_STATIC_DIR"] = default_dir
    MineChecker::StaticIndex.reset!
  end
end
