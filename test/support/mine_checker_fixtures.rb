# Programmatic mine-check fixtures (docs/mine_checker/SPEC.md §8).
#
# Geometries are DERIVED from the real dataset at setup time — never
# hardcoded — so a dataset refresh keeps the tests honest. Only the chosen
# fixtures are inserted (not the full 20k-feature import) to keep the suite
# fast; the full import path has its own dedicated test.
module MineCheckerFixtures
  DATA_FILE = Rails.root.join("db/data/mine_checker/suspect_areas_original.geojson")

  module_function

  def dataset
    @dataset ||= JSON.parse(File.read(DATA_FILE)).fetch("features")
  end

  # A rich suspected polygon (≥20 points, fileId 2585-III per SPEC §8).
  def rich_polygon_feature
    @rich_polygon_feature ||= dataset.find do |f|
      f["geometry"]["type"] == "Polygon" &&
        f.dig("properties", "fileId") == "2585-III" &&
        (f["geometry"]["coordinates"].first || []).size >= 20
    end || raise("no rich 2585-III polygon in dataset — SPEC §8 fixture broken")
  end

  # A degenerate ring (<4 points) — SVG extraction artifact (SPEC §3).
  def degenerate_feature
    @degenerate_feature ||= dataset.find do |f|
      f["geometry"]["type"] == "Polygon" &&
        (f["geometry"]["coordinates"].first || []).size.between?(1, 3)
    end || raise("no degenerate ring in dataset — SPEC §3 premise broken")
  end

  def polygon_wkt(feature)
    rings = feature["geometry"]["coordinates"].map do |ring|
      closed = ring.first == ring.last ? ring : ring + [ ring.first ]
      "(#{closed.map { |c| "#{c[0]} #{c[1]}" }.join(', ')})"
    end
    "POLYGON(#{rings.join(', ')})"
  end

  # Insert the two fixture geometries; returns a hash of derived test points.
  def install!(data_as_of: Date.current)
    conn = ActiveRecord::Base.connection
    conn.execute("TRUNCATE mine_areas RESTART IDENTITY")

    insert_polygon(conn, rich_polygon_feature, data_as_of)
    insert_degenerate(conn, degenerate_feature, data_as_of)

    inside = centroid_of_rich(conn)
    verify_inside!(conn, inside)

    {
      inside: inside,
      near: derive_near_point(conn, inside),
      clear: derive_clear_point(conn),
      # NOTE: SPEC §8 samples (16.0, 42.9) as the offshore point, but that
      # falls INSIDE the §4 bbox — the bbox is authoritative (running the
      # check there is the conservative outcome). Use a genuinely-outside
      # Adriatic point instead.
      offshore: { lat: 42.0, lon: 14.5 },
      degenerate_center: degenerate_center
    }
  end

  def insert_polygon(conn, feature, data_as_of)
    conn.execute(ActiveRecord::Base.sanitize_sql([ <<~SQL, { wkt: polygon_wkt(feature), d: data_as_of } ]))
      INSERT INTO mine_areas (kind, geom, source, file_id, data_as_of, imported_at, created_at, updated_at)
      VALUES ('suspected', ST_MakeValid(ST_GeomFromText(:wkt, 4326))::geography,
              'eufor_micc_extract', '2585-III', :d, NOW(), NOW(), NOW())
    SQL
  end

  def insert_degenerate(conn, feature, data_as_of)
    ring = feature["geometry"]["coordinates"].first
    wkt = if ring.size == 1
      "POINT(#{ring[0][0]} #{ring[0][1]})"
    else
      "LINESTRING(#{ring.map { |c| "#{c[0]} #{c[1]}" }.join(', ')})"
    end
    conn.execute(ActiveRecord::Base.sanitize_sql([ <<~SQL, { wkt:, d: data_as_of } ]))
      INSERT INTO mine_areas (kind, geom, source, file_id, data_as_of, imported_at, created_at, updated_at)
      VALUES ('suspected', ST_Buffer(ST_GeomFromText(:wkt, 4326)::geography, 100),
              'eufor_micc_extract', 'degenerate-fixture', :d, NOW(), NOW(), NOW())
    SQL
  end

  def degenerate_center
    ring = degenerate_feature["geometry"]["coordinates"].first
    { lat: ring[0][1], lon: ring[0][0] }
  end

  def centroid_of_rich(conn)
    row = conn.select_one(
      "SELECT ST_Y(ST_PointOnSurface(geom::geometry)) AS lat, ST_X(ST_PointOnSurface(geom::geometry)) AS lon " \
      "FROM mine_areas WHERE file_id = '2585-III' LIMIT 1"
    )
    { lat: row["lat"].to_f, lon: row["lon"].to_f }
  end

  def verify_inside!(conn, point)
    hit = conn.select_value(ActiveRecord::Base.sanitize_sql([
      "SELECT ST_Contains(geom::geometry, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)) " \
      "FROM mine_areas WHERE file_id = '2585-III' LIMIT 1",
      point
    ]))
    raise "derived inside-point is not contained — fixture derivation broken" unless hit
  end

  # A point outside the polygon but well inside the 500 m buffer (~300 m).
  def derive_near_point(conn, inside)
    (0.002..0.02).step(0.001) do |dx|
      cand = { lat: inside[:lat], lon: inside[:lon] + dx }
      d = distance_to_rich(conn, cand)
      return cand if d.positive? && d <= 450
    end
    raise "could not derive a near-point within the buffer"
  end

  # A point in BiH verified >2 km from every suspected fixture geometry.
  def derive_clear_point(conn)
    [ 0.3, 0.5, 0.8, -0.5 ].each do |dx|
      cand = { lat: 44.2, lon: 17.8 + dx }
      d = conn.select_value(ActiveRecord::Base.sanitize_sql([
        "SELECT MIN(ST_Distance(geom, ST_GeogFromText('SRID=4326;POINT(' || :lon || ' ' || :lat || ')'))) FROM mine_areas",
        cand
      ]))
      return cand if d.to_f > 2000
    end
    raise "could not derive a clear point"
  end

  def distance_to_rich(conn, point)
    conn.select_value(ActiveRecord::Base.sanitize_sql([
      "SELECT ST_Distance(geom, ST_GeogFromText('SRID=4326;POINT(' || :lon || ' ' || :lat || ')')) " \
      "FROM mine_areas WHERE file_id = '2585-III' LIMIT 1",
      point
    ])).to_f
  end
  # Minimal fresh baseline so ordinary tests can create BiH content under the
  # fail-closed regime: one small suspected polygon tucked in the far SW
  # corner of the bbox (nowhere near real content coordinates) with a current
  # data_as_of. Installed by test_helper before every test.
  def baseline!
    conn = ActiveRecord::Base.connection
    conn.execute("TRUNCATE mine_areas RESTART IDENTITY")
    conn.execute(<<~SQL)
      INSERT INTO mine_areas (kind, geom, source, file_id, data_as_of, imported_at, created_at, updated_at)
      VALUES ('suspected',
              ST_GeomFromText('POLYGON((15.55 42.45, 15.56 42.45, 15.56 42.46, 15.55 42.46, 15.55 42.45))', 4326)::geography,
              'test-baseline', 'baseline', '#{Date.current.iso8601}', NOW(), NOW(), NOW())
    SQL
  end
end
