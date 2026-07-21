#!/usr/bin/env ruby
# frozen_string_literal: true

# Offline builder for the static mine engine artifacts. This is the ONLY
# place PostGIS is used — the Rails app itself has no spatial dependency.
#
# Usage:
#   MINE_BUILD_DATABASE_URL=postgres://user:pass@host:port/scratch_db \
#   DATA_AS_OF=2024-07-31 \
#   ruby scripts/mine_checker/build_static_artifacts.rb
#
# Requires a scratch database on a PostGIS-enabled server (any throwaway
# instance, e.g. `docker run postgis/postgis`). Reads the vendored GeoJSON
# snapshot from db/data/mine_checker/, writes artifacts to
# db/data/mine_checker/static/.
#
# Hard rules preserved from the original import (docs/mine_checker/SPEC.md):
# - DATA_AS_OF is mandatory; every artifact carries the snapshot date.
# - Degenerate rings (<4 points) are NEVER dropped — buffered 100 m.
# - Polygons that collapse to zero area under ST_MakeValid are buffered too.
# - Sanity gates abort on suspicious data (count, validity, bbox).
# - Raster masks are dilated by band radius + cell half-diagonal, so
#   quantization can only widen a band, never narrow it.

require "json"
require "pg"
require "zlib"
require "date"
require "time"
require "fileutils"

ROOT = File.expand_path("../..", __dir__)
DATA_DIR = ENV.fetch("MINE_DATA_DIR", File.join(ROOT, "db/data/mine_checker"))
OUT_DIR = ENV.fetch("MINE_STATIC_DIR", File.join(DATA_DIR, "static"))
BBOX = [ 15.5, 42.4, 19.7, 45.4 ].freeze # west, south, east, north (config/mine_checker.yml)
DEGENERATE_BUFFER_M = 100
CELL_SIZES = { "inside" => 50, "danger" => 100, "caution" => 200 }.freeze
BUFFERS = { "inside" => 36, "danger" => 571, "caution" => 2142 }.freeze
SIMPLIFY_TOLERANCE = 0.0004
TILE_DEG = 0.25
TILE_FEATURE_CAP = 800

data_as_of = ENV["DATA_AS_OF"] or abort("DATA_AS_OF env var is required (e.g. DATA_AS_OF=2024-07-31)")
data_as_of = Date.iso8601(data_as_of)
db_url = ENV["MINE_BUILD_DATABASE_URL"] or abort("MINE_BUILD_DATABASE_URL is required (scratch PostGIS database)")

conn = PG.connect(db_url)
conn.exec("CREATE EXTENSION IF NOT EXISTS postgis")
conn.exec("DROP TABLE IF EXISTS mine_build")
conn.exec("CREATE TABLE mine_build (id serial, geom geography(Geometry,4326))")

def geometry_to_wkt(geometry)
  type = geometry.fetch("type")
  coords = geometry.fetch("coordinates")
  case type
  when "Point"
    [ "POINT(#{coords[0]} #{coords[1]})", :point ]
  when "Polygon"
    ring = coords.first || []
    if ring.size >= 4
      closed = coords.map { |r| r.first == r.last ? r : r + [ r.first ] }
      rings = closed.map { |r| "(#{r.map { |c| "#{c[0]} #{c[1]}" }.join(', ')})" }.join(", ")
      [ "POLYGON(#{rings})", :polygon ]
    elsif ring.size == 1
      [ "POINT(#{ring[0][0]} #{ring[0][1]})", :degenerate ]
    else
      pts = ring.map { |c| "#{c[0]} #{c[1]}" }.join(", ")
      [ "LINESTRING(#{pts})", :degenerate ]
    end
  else
    abort("unsupported geometry type #{type}")
  end
end

# --- Load the suspected layer (the only layer any runtime feature uses) ---
path = File.join(DATA_DIR, "suspect_areas_original.geojson")
abort("missing #{path}") unless File.exist?(path)
stats = Hash.new(0)
features = JSON.parse(File.read(path)).fetch("features")
insert_polygon = <<~SQL
  INSERT INTO mine_build (geom)
  SELECT CASE WHEN ST_Area(g) > 0 THEN g ELSE ST_Buffer(g, #{DEGENERATE_BUFFER_M}) END
  FROM (SELECT ST_MakeValid(ST_GeomFromText($1, 4326))::geography AS g) sub
SQL
insert_buffered = "INSERT INTO mine_build (geom) SELECT ST_Buffer(ST_GeomFromText($1, 4326)::geography, #{DEGENERATE_BUFFER_M})"
features.each do |feature|
  wkt, category = geometry_to_wkt(feature.fetch("geometry"))
  stats[category] += 1
  conn.exec_params(category == :polygon ? insert_polygon : insert_buffered, [ wkt ])
end
puts "loaded suspected layer: #{features.size} features (#{stats.map { |k, v| "#{k}=#{v}" }.join(', ')})"

# --- Sanity gates ---
count = conn.exec("SELECT COUNT(*) FROM mine_build").getvalue(0, 0).to_i
abort("sanity: suspected count #{count} < 10000") if count < 10_000
invalid = conn.exec("SELECT COUNT(*) FROM mine_build WHERE NOT ST_IsValid(geom::geometry)").getvalue(0, 0).to_i
abort("sanity: #{invalid} invalid geometries") if invalid.positive?
row = conn.exec(<<~SQL)[0]
  SELECT MIN(ST_XMin(geom::geometry)) AS xmin, MIN(ST_YMin(geom::geometry)) AS ymin,
         MAX(ST_XMax(geom::geometry)) AS xmax, MAX(ST_YMax(geom::geometry)) AS ymax
  FROM mine_build
SQL
unless row["xmin"].to_f >= BBOX[0] && row["xmax"].to_f <= BBOX[2] &&
       row["ymin"].to_f >= BBOX[1] && row["ymax"].to_f <= BBOX[3]
  abort("sanity: bounding box #{row.inspect} outside BiH bounds")
end
puts "sanity: OK (#{count} areas, bbox within BiH, all geometries valid)"

FileUtils.mkdir_p(OUT_DIR)
west, south, east, north = BBOX
mid_lat = (south + north) / 2.0

# --- Bitmask rasters ---
grids = {}
CELL_SIZES.each do |name, cell_m|
  dlat = cell_m / 111_320.0
  dlon = cell_m / (111_320.0 * Math.cos(mid_lat * Math::PI / 180))
  rows = ((north - south) / dlat).ceil
  cols = ((east - west) / dlon).ceil
  grids[name] = { "cell_m" => cell_m, "dlat" => dlat, "dlon" => dlon, "rows" => rows, "cols" => cols }

  puts "rasterizing #{name} (#{rows}x#{cols} @ #{cell_m}m, buffer #{BUFFERS[name]}m)..."
  bits = "\x00".b * ((rows * cols + 7) / 8)
  set = 0
  result = conn.exec_params(<<~SQL, [ BUFFERS[name], west, south, dlat, dlon, rows - 1, cols - 1 ])
    WITH g AS (SELECT ST_Buffer(geom, $1) AS bg FROM mine_build)
    SELECT r, c
    FROM g,
    LATERAL generate_series(
      GREATEST(0, FLOOR((ST_XMin(bg::geometry) - $2) / $5)::int),
      LEAST($7, FLOOR((ST_XMax(bg::geometry) - $2) / $5)::int)
    ) AS c,
    LATERAL generate_series(
      GREATEST(0, FLOOR((ST_YMin(bg::geometry) - $3) / $4)::int),
      LEAST($6, FLOOR((ST_YMax(bg::geometry) - $3) / $4)::int)
    ) AS r
    WHERE ST_Intersects(bg, ST_MakeEnvelope(
      $2 + c * $5, $3 + r * $4, $2 + (c + 1) * $5, $3 + (r + 1) * $4, 4326)::geography)
  SQL
  result.each_row do |(r, c)|
    idx = r.to_i * cols + c.to_i
    byte = idx >> 3
    next if bits.getbyte(byte)[idx & 7] == 1

    bits.setbyte(byte, bits.getbyte(byte) | (1 << (idx & 7)))
    set += 1
  end
  File.binwrite(File.join(OUT_DIR, "#{name}.bin.gz"), Zlib.gzip(bits, level: 9))
  puts "  #{set} cells set (#{(100.0 * set / (rows * cols)).round(2)}%)"
end

# --- Overview dots (national zoom): deduplicated coarse centroids ---
rows = conn.exec(<<~SQL)
  SELECT DISTINCT round(ST_X(ST_Centroid(geom::geometry))::numeric, 2),
                  round(ST_Y(ST_Centroid(geom::geometry))::numeric, 2)
  FROM mine_build
SQL
overview = {
  type: "FeatureCollection",
  features: rows.values.map do |lon, lat|
    { type: "Feature", geometry: { type: "Point", coordinates: [ lon.to_f, lat.to_f ] }, properties: {} }
  end
}
File.binwrite(File.join(OUT_DIR, "overview.json.gz"), Zlib.gzip(JSON.generate(overview), level: 9))
puts "overview: #{overview[:features].size} dots"

# --- Boundary tiles (zoomed-in overlay): simplified, no metadata ---
tiles_dir = File.join(OUT_DIR, "tiles")
FileUtils.rm_rf(tiles_dir)
FileUtils.mkdir_p(tiles_dir)
tile_count = 0
feature_count = 0
tx_max = ((east - west) / TILE_DEG).ceil - 1
ty_max = ((north - south) / TILE_DEG).ceil - 1
(0..tx_max).each do |tx|
  (0..ty_max).each do |ty|
    t_west = west + tx * TILE_DEG
    t_south = south + ty * TILE_DEG
    result = conn.exec_params(<<~SQL, [ SIMPLIFY_TOLERANCE, t_west, t_south, t_west + TILE_DEG, t_south + TILE_DEG, TILE_FEATURE_CAP + 1 ])
      SELECT ST_AsGeoJSON(ST_SimplifyPreserveTopology(geom::geometry, $1::float8), 5)
      FROM mine_build
      WHERE ST_Intersects(geom, ST_MakeEnvelope($2, $3, $4, $5, 4326)::geography)
      ORDER BY ST_Area(geom) DESC
      LIMIT $6
    SQL
    next if result.ntuples.zero?

    geojsons = result.column_values(0)
    payload = {
      type: "FeatureCollection",
      truncated: geojsons.size > TILE_FEATURE_CAP,
      features: geojsons.first(TILE_FEATURE_CAP).map do |gj|
        { type: "Feature", geometry: JSON.parse(gj), properties: {} }
      end
    }
    File.binwrite(File.join(tiles_dir, "#{tx}_#{ty}.json.gz"), Zlib.gzip(JSON.generate(payload), level: 9))
    tile_count += 1
    feature_count += payload[:features].size
  end
end
puts "tiles: #{tile_count} non-empty tiles, #{feature_count} features"

# --- Meta ---
meta = {
  "data_as_of" => data_as_of.iso8601,
  "bbox" => BBOX,
  "grids" => grids,
  "tile_deg" => TILE_DEG,
  "built_at" => Time.now.utc.iso8601,
  "source_count" => count
}
File.write(File.join(OUT_DIR, "meta.json"), JSON.pretty_generate(meta))
conn.exec("DROP TABLE mine_build")
puts "done: artifacts in #{OUT_DIR} (data_as_of=#{data_as_of})"
if Date.today - data_as_of > 365
  warn "NOTE: snapshot is #{(Date.today - data_as_of).to_i} days old — beyond the staleness"
  warn "threshold. Checks still run (old data does not block), but every answer"
  warn "carries this date and the UI shows a staleness caveat. Consider refreshing."
end
