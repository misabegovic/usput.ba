# Mine Checker data pipeline (docs/mine_checker/SPEC.md §3, §6).
#
# bin/rails mine_data:import DATA_AS_OF=2024-07-31
# bin/rails mine_data:audit_existing
#
# Hard rules encoded here:
# - DATA_AS_OF is mandatory — the import refuses to run without it, because
#   every verdict must carry the snapshot date and staleness must be honest.
# - Degenerate rings (<4 points — SVG extraction artifacts) are NEVER
#   dropped. They are converted to point/linestring and buffered 100 m into
#   an area: the artifact likely maps to a real hazard the extraction
#   mutilated. Fail-closed.
# - Post-import sanity gates abort (and roll back) on suspicious data.
namespace :mine_data do
  FILES = {
    "suspected" => "suspect_areas_original.geojson",
    "cleared" => "cleared_areas_original.geojson",
    "lifted" => "lifted_minefields.geojson",
    "incident" => "incidents.geojson"
  }.freeze

  DEGENERATE_BUFFER_M = 100

  desc "Import EUFOR/BHMAC-derived mine layers (requires DATA_AS_OF=YYYY-MM-DD)"
  task import: :environment do
    data_as_of = ENV["DATA_AS_OF"]
    abort("mine_data:import: DATA_AS_OF env var is required (e.g. DATA_AS_OF=2024-07-31)") if data_as_of.blank?
    data_as_of = Date.iso8601(data_as_of)

    dir = ENV["MINE_DATA_DIR"].presence || Rails.root.join("db/data/mine_checker").to_s
    imported_at = Time.current
    stats = Hash.new(0)

    ActiveRecord::Base.transaction do
      MineArea.connection.execute("TRUNCATE mine_areas RESTART IDENTITY")

      FILES.each do |kind, filename|
        path = File.join(dir, filename)
        abort("mine_data:import: missing #{path}") unless File.exist?(path)

        features = JSON.parse(File.read(path)).fetch("features")
        features.each do |feature|
          geometry = feature.fetch("geometry")
          props = feature["properties"] || {}
          wkt, category = mine_geometry_to_wkt(geometry)
          stats["#{kind}/#{category}"] += 1

          geom_sql = if category == :polygon
            # A "valid" polygon can still collapse to zero area under
            # ST_MakeValid (collinear/duplicated extraction artifacts).
            # Those are hazards too — buffer them, never import them flat.
            "(SELECT CASE WHEN ST_Area(g) > 0 THEN g " \
              "ELSE ST_Buffer(g, #{DEGENERATE_BUFFER_M}) END " \
              "FROM (SELECT ST_MakeValid(ST_GeomFromText(:wkt, 4326))::geography AS g) sub)"
          else
            "ST_Buffer(ST_GeomFromText(:wkt, 4326)::geography, #{DEGENERATE_BUFFER_M})"
          end
          insert_sql = "INSERT INTO mine_areas (kind, geom, source, file_id, data_as_of, imported_at, created_at, updated_at) " \
                       "VALUES (:kind, #{geom_sql}, :source, :file_id, :data_as_of, :imported_at, :now, :now)"
          MineArea.connection.execute(ActiveRecord::Base.sanitize_sql([ insert_sql, {
            kind:, wkt:,
            source: "eufor_micc_extract",
            file_id: props["fileId"],
            data_as_of:, imported_at:, now: imported_at
          } ]))
        end
        puts "  #{kind}: #{features.size} features"
      end

      mine_sanity_check!
    end

    puts "mine_data:import complete (data_as_of=#{data_as_of})"
    if Date.current - data_as_of > MineChecker::Config.staleness_days
      warn "=" * 72
      warn "WARNING: imported snapshot is #{(Date.current - data_as_of).to_i} days old — beyond the"
      warn "#{MineChecker::Config.staleness_days}-day staleness threshold. The checker will FAIL CLOSED: all BiH"
      warn "geo-content creation is blocked until fresher data is imported."
      warn "Refresh: scripts/mine_checker/scrape_eufor_pdfs.py + extraction pipeline."
      warn "=" * 72
    end
    stats.sort.each { |k, v| puts "  #{k}: #{v}" }
  end

  desc "One-off audit of existing geo content against the mine layer (no deletions)"
  task audit_existing: :environment do
    hits = []
    scope = Location.where.not(lat: nil).where.not(lng: nil)
    total = scope.count
    scope.find_each.with_index do |location, i|
      result = MineChecker::PointCheck.call(lat: location.lat, lon: location.lng, content: location)
      hits << [ location, result ] if result.verdict == :blocked
      print "\r  #{i + 1}/#{total}" if $stdout.tty? && (i % 50).zero?
    end
    puts "\nmine_data:audit_existing: #{total} locations checked, #{hits.size} blocked"
    hits.each do |location, result|
      nearest = result.matches.first
      puts "  Location##{location.id} #{location.name.to_s.truncate(40)} " \
           "(#{location.lat}, #{location.lng}) — nearest #{nearest[:distance_m]} m (#{nearest[:file_id]})"
    end
    puts "  Review the list above — nothing was deleted or modified." if hits.any?
  end

  def mine_geometry_to_wkt(geometry)
    type = geometry.fetch("type")
    coords = geometry.fetch("coordinates")
    case type
    when "Point"
      [ "POINT(#{coords[0]} #{coords[1]})", :point ]
    when "Polygon"
      ring = coords.first || []
      if ring.size >= 4
        # SVG extraction leaves some rings unclosed — close them; ST_MakeValid
        # downstream repairs the rest.
        closed = coords.map { |r| r.first == r.last ? r : r + [ r.first ] }
        rings = closed.map { |r| "(#{r.map { |c| "#{c[0]} #{c[1]}" }.join(', ')})" }.join(", ")
        [ "POLYGON(#{rings})", :polygon ]
      elsif ring.size == 1
        # Degenerate: single point extracted from the map — buffer, don't drop.
        [ "POINT(#{ring[0][0]} #{ring[0][1]})", :degenerate ]
      else
        pts = ring.map { |c| "#{c[0]} #{c[1]}" }.join(", ")
        [ "LINESTRING(#{pts})", :degenerate ]
      end
    else
      abort("mine_data:import: unsupported geometry type #{type}")
    end
  end

  def mine_sanity_check!(conn = MineArea.connection)
    suspected = MineArea.suspected.count
    abort("sanity: suspected count #{suspected} < 10000") if suspected < 10_000

    invalid = conn.select_value("SELECT COUNT(*) FROM mine_areas WHERE NOT ST_IsValid(geom::geometry)").to_i
    abort("sanity: #{invalid} invalid geometries") if invalid.positive?

    bbox = conn.select_one(<<~SQL)
      SELECT MIN(ST_XMin(geom::geometry)) AS xmin, MIN(ST_YMin(geom::geometry)) AS ymin,
             MAX(ST_XMax(geom::geometry)) AS xmax, MAX(ST_YMax(geom::geometry)) AS ymax
      FROM mine_areas
    SQL
    unless bbox["xmin"].to_f >= 15.5 && bbox["xmax"].to_f <= 19.7 &&
           bbox["ymin"].to_f >= 42.4 && bbox["ymax"].to_f <= 45.4
      abort("sanity: bounding box #{bbox.inspect} outside BiH bounds")
    end

    puts "  sanity: OK (suspected=#{suspected}, bbox within BiH, all geometries valid)"
  end
end
