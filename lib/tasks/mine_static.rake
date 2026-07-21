require "zlib"

# Offline pipeline for the no-database ("static") mine engine.
#
# mine_static:build rasterizes the imported PostGIS dataset into three
# conservative bitmasks committed to db/data/mine_checker/static/:
#   inside  (50 m)  — cells intersecting a suspected area (board truth)
#   danger  (100 m) — cells within the 500 m danger radius
#   caution (200 m) — cells within the 2 km caution radius
# Every mask is built from geometries buffered by the band radius PLUS the
# cell half-diagonal, so quantization can only widen a band, never narrow it.
#
# mine_static:compare samples random points and reports agreement between
# the live PostGIS engine and the static engine.
namespace :mine_static do
  CELL_SIZES = { "inside" => 50, "danger" => 100, "caution" => 200 }.freeze
  # band radius + half-diagonal of the mask's cell (m), rounded up
  BUFFERS = { "inside" => 36, "danger" => 571, "caution" => 2142 }.freeze

  desc "Build static engine artifacts from the imported mine dataset"
  task build: :environment do
    abort("mine_static:build: no imported mine data") if MineArea.suspected.none?

    west, south, east, north = MineChecker::Config.bih_bbox
    mid_lat = (south + north) / 2.0
    data_as_of = MineArea.suspected.maximum(:data_as_of)
    dir = ENV["MINE_STATIC_DIR"].presence || Rails.root.join("db/data/mine_checker/static").to_s
    FileUtils.mkdir_p(dir)

    grids = {}
    CELL_SIZES.each do |name, cell_m|
      dlat = cell_m / 111_320.0
      dlon = cell_m / (111_320.0 * Math.cos(mid_lat * Math::PI / 180))
      rows = ((north - south) / dlat).ceil
      cols = ((east - west) / dlon).ceil
      grids[name] = { "cell_m" => cell_m, "dlat" => dlat, "dlon" => dlon, "rows" => rows, "cols" => cols }

      puts "mine_static: rasterizing #{name} (#{rows}x#{cols} @ #{cell_m}m, buffer #{BUFFERS[name]}m)..."
      bits = "\x00".b * ((rows * cols + 7) / 8)
      set = 0

      sql = ActiveRecord::Base.sanitize_sql([ <<~SQL, { buf: BUFFERS[name], west: west, south: south, dlat: dlat, dlon: dlon, rmax: rows - 1, cmax: cols - 1 } ])
        WITH g AS (
          SELECT ST_Buffer(geom, :buf) AS bg
          FROM mine_areas WHERE kind = 'suspected'
        )
        SELECT r, c
        FROM g,
        LATERAL generate_series(
          GREATEST(0, FLOOR((ST_XMin(bg::geometry) - :west) / :dlon)::int),
          LEAST(:cmax, FLOOR((ST_XMax(bg::geometry) - :west) / :dlon)::int)
        ) AS c,
        LATERAL generate_series(
          GREATEST(0, FLOOR((ST_YMin(bg::geometry) - :south) / :dlat)::int),
          LEAST(:rmax, FLOOR((ST_YMax(bg::geometry) - :south) / :dlat)::int)
        ) AS r
        WHERE ST_Intersects(bg, ST_MakeEnvelope(
          :west + c * :dlon, :south + r * :dlat,
          :west + (c + 1) * :dlon, :south + (r + 1) * :dlat, 4326)::geography)
      SQL
      ActiveRecord::Base.connection.select_rows(sql).each do |r, c|
        idx = r.to_i * cols + c.to_i
        byte = idx >> 3
        next if bits.getbyte(byte)[idx & 7] == 1

        bits.setbyte(byte, bits.getbyte(byte) | (1 << (idx & 7)))
        set += 1
      end
      File.binwrite(File.join(dir, "#{name}.bin.gz"), Zlib.gzip(bits, level: 9))
      puts "  #{set} cells set (#{(100.0 * set / (rows * cols)).round(2)}% of grid)"
    end

    meta = {
      "data_as_of" => data_as_of.iso8601,
      "bbox" => [ west, south, east, north ],
      "grids" => grids,
      "built_at" => Time.current.iso8601,
      "source_count" => MineArea.suspected.count
    }
    File.write(File.join(dir, "meta.json"), JSON.pretty_generate(meta))
    puts "mine_static: artifacts written to #{dir} (data_as_of=#{data_as_of})"
  end

  desc "Compare static engine answers against the PostGIS engine on random points"
  task :compare, [ :n ] => :environment do |_, args|
    n = (args[:n] || 2000).to_i
    index = MineChecker::StaticIndex.instance
    abort("mine_static:compare: no static artifacts — run mine_static:build") unless index.available?

    west, south, east, north = MineChecker::Config.bih_bbox
    rng = Random.new(42)
    matrix = Hash.new(0)
    db_times = []
    static_times = []
    severity = { "no_known" => 0, "caution" => 1, "danger" => 2 }
    regressions = []

    n.times do
      lat = south + rng.rand * (north - south)
      lon = west + rng.rand * (east - west)

      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      db_band = MineChecker::Bands.db_band_at(lat, lon)
      t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      static_band = index.band_at(lat, lon)
      t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      db_times << (t1 - t0) * 1000
      static_times << (t2 - t1) * 1000
      matrix[[ db_band, static_band ]] += 1
      if severity.fetch(static_band, 0) < severity.fetch(db_band, 0)
        regressions << [ lat.round(5), lon.round(5), db_band, static_band ]
      end
    end

    agree = matrix.sum { |(a, b), count| a == b ? count : 0 }
    puts "\nmine_static:compare over #{n} random points"
    puts "  agreement: #{agree}/#{n} (#{(100.0 * agree / n).round(2)}%)"
    matrix.sort.each { |(a, b), count| puts "  db=#{a} static=#{b}: #{count}" }
    pct = ->(arr, p) { arr.sort[(arr.size * p).floor.clamp(0, arr.size - 1)] }
    puts "  db timing ms: p50=#{pct.call(db_times, 0.5).round(3)} p95=#{pct.call(db_times, 0.95).round(3)}"
    puts "  static timing ms: p50=#{pct.call(static_times, 0.5).round(4)} p95=#{pct.call(static_times, 0.95).round(4)}"
    if regressions.any?
      puts "  !!! #{regressions.size} NON-CONSERVATIVE mismatches (static milder than db) — MUST be zero:"
      regressions.first(10).each { |r| puts "    #{r.inspect}" }
    else
      puts "  conservative property holds: static is never milder than db"
    end
  end
end
