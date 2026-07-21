require "zlib"

module MineChecker
  # No-database engine: answers point-band, board-cell, overlay and
  # aggregate queries from precomputed artifacts (built offline by
  # scripts/mine_checker/build_static_artifacts.rb). All masks are dilated
  # by their cell half-diagonal at build time, so raster quantization can only
  # err toward the MORE dangerous answer, never the less dangerous one.
  class StaticIndex
    DEFAULT_DIR = "db/data/mine_checker/static".freeze

    class << self
      def instance
        @instance ||= new(dir)
      end

      def reset!
        @instance = nil
      end

      def dir
        ENV["MINE_STATIC_DIR"].presence || Rails.root.join(DEFAULT_DIR).to_s
      end
    end

    attr_reader :meta

    def initialize(dir)
      @dir = dir
      meta_path = File.join(dir, "meta.json")
      if File.exist?(meta_path)
        @meta = JSON.parse(File.read(meta_path))
        @masks = {}
      else
        @meta = nil
      end
    end

    def available?
      !@meta.nil?
    end

    def data_as_of
      return nil unless available?

      Date.parse(@meta["data_as_of"])
    end

    def stale?
      data_as_of.nil? || data_as_of < MineChecker::Config.staleness_days.days.ago.to_date
    end

    # "danger" | "caution" | "no_known" | "out_of_coverage" | "unavailable"
    def band_at(lat, lon)
      return "unavailable" unless available?
      return "out_of_coverage" unless bbox_contains?(lat, lon)
      return "danger" if bit_at?("danger", lat, lon) || bit_at?("inside", lat, lon)
      return "caution" if bit_at?("caution", lat, lon)

      "no_known"
    end

    # Mine cells for a geographic board grid: a cell is a mine iff any
    # 50 m "inside" raster cell within its rectangle is set.
    def mine_cells(south:, west:, dlat:, dlon:, rows:, cols:)
      return [] unless available?

      result = []
      rows.times do |r|
        cols.times do |c|
          if any_bit_in_rect?("inside",
                              south + r * dlat, west + c * dlon,
                              south + (r + 1) * dlat, west + (c + 1) * dlon)
            result << [ r, c ]
          end
        end
      end
      result
    end

    # km² of recorded suspected area within `radius_m` of the point,
    # counted from the 50 m inside mask.
    def suspected_km2_within(lat, lon, radius_m)
      return 0.0 unless available?

      grid = @meta["grids"]["inside"]
      cell_km2 = (grid["cell_m"] / 1000.0)**2
      r_cells_lat = (radius_m / (grid["dlat"] * 111_320.0)).ceil
      r_cells_lon = (radius_m / (grid["dlon"] * 111_320.0 * Math.cos(lat * Math::PI / 180))).ceil
      r0 = row_for(grid, lat)
      c0 = col_for(grid, lon)
      count = 0
      (r0 - r_cells_lat).upto(r0 + r_cells_lat) do |r|
        next if r.negative? || r >= grid["rows"]

        (c0 - r_cells_lon).upto(c0 + r_cells_lon) do |c|
          next if c.negative? || c >= grid["cols"]
          next unless ((r - r0) * 2.0 / (2 * r_cells_lat))**2 + ((c - c0) * 2.0 / (2 * r_cells_lon))**2 <= 1.0

          count += 1 if bit_set?("inside", r, c)
        end
      end
      (count * cell_km2).round(1)
    end

    # Raw gzipped-JSON artifacts for the overlay endpoints.
    def overview_json
      return nil unless available?

      @overview_json ||= Zlib.gunzip(File.binread(File.join(@dir, "overview.json.gz")))
    end

    # Merged, deduplicated features for a viewport from pre-built tiles.
    def tile_features(west, south, east, north)
      return nil unless available?

      tile_deg = @meta["tile_deg"]
      bbox_west, bbox_south, = @meta["bbox"]
      tx_range = (((west - bbox_west) / tile_deg).floor)..(((east - bbox_west) / tile_deg).floor)
      ty_range = (((south - bbox_south) / tile_deg).floor)..(((north - bbox_south) / tile_deg).floor)
      features = []
      seen = Set.new
      truncated = false
      tx_range.each do |tx|
        ty_range.each do |ty|
          tile = load_tile(tx, ty)
          next unless tile

          truncated ||= tile["truncated"]
          tile["features"].each do |f|
            key = f["geometry"].hash
            next if seen.include?(key)

            seen << key
            features << f
          end
        end
      end
      { "type" => "FeatureCollection", "truncated" => truncated, "features" => features }
    end

    # True if the segment passes through any danger-mask cell — exact
    # supercover traversal of the grid, no sampling gaps.
    def danger_on_segment?(lat1, lon1, lat2, lon2)
      return false unless available?

      grid = @meta["grids"]["danger"]
      r1 = row_for(grid, lat1)
      c1 = col_for(grid, lon1)
      r2 = row_for(grid, lat2)
      c2 = col_for(grid, lon2)
      steps = [ (r2 - r1).abs, (c2 - c1).abs, 1 ].max * 2
      0.upto(steps) do |i|
        t = i.to_f / steps
        r = (r1 + (r2 - r1) * t).round
        c = (c1 + (c2 - c1) * t).round
        next if r.negative? || c.negative? || r >= grid["rows"] || c >= grid["cols"]
        return true if bit_set_in?("danger", grid, r, c)
      end
      false
    end

    private

    def load_tile(tx, ty)
      @tiles ||= {}
      return @tiles[[ tx, ty ]] if @tiles.key?([ tx, ty ])

      path = File.join(@dir, "tiles", "#{tx}_#{ty}.json.gz")
      @tiles[[ tx, ty ]] = File.exist?(path) ? JSON.parse(Zlib.gunzip(File.binread(path))) : nil
    end

    def bbox_contains?(lat, lon)
      west, south, east, north = @meta["bbox"]
      lon.between?(west, east) && lat.between?(south, north)
    end

    def mask(name)
      @masks[name] ||= Zlib.gunzip(File.binread(File.join(@dir, "#{name}.bin.gz"))).freeze
    end

    def row_for(grid, lat)
      ((lat - @meta["bbox"][1]) / grid["dlat"]).floor
    end

    def col_for(grid, lon)
      ((lon - @meta["bbox"][0]) / grid["dlon"]).floor
    end

    def bit_at?(name, lat, lon)
      grid = @meta["grids"][name]
      r = row_for(grid, lat)
      c = col_for(grid, lon)
      return false if r.negative? || c.negative? || r >= grid["rows"] || c >= grid["cols"]

      bit_set_in?(name, grid, r, c)
    end

    def bit_set?(name, r, c)
      bit_set_in?(name, @meta["grids"][name], r, c)
    end

    def bit_set_in?(name, grid, r, c)
      idx = r * grid["cols"] + c
      byte = mask(name).getbyte(idx >> 3)
      byte && byte[idx & 7] == 1
    end

    def any_bit_in_rect?(name, south, west, north, east)
      grid = @meta["grids"][name]
      r_min = [ row_for(grid, south), 0 ].max
      r_max = [ row_for(grid, north), grid["rows"] - 1 ].min
      c_min = [ col_for(grid, west), 0 ].max
      c_max = [ col_for(grid, east), grid["cols"] - 1 ].min
      r_min.upto(r_max) do |r|
        c_min.upto(c_max) do |c|
          return true if bit_set_in?(name, grid, r, c)
        end
      end
      false
    end
  end
end
