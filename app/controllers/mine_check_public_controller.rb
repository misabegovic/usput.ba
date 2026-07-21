# Public mine-proximity check (owner-authorized Phase 2 — see
# docs/mine_checker/README.md). Fail-safe properties, non-negotiable:
# - Verdicts are coarse BANDS only. No distances, bearings, or geometry
#   ever leave the server; exact match details go to the internal audit log.
# - There is no "safe" answer. The best case is "no known intersections",
#   always delivered with the data date and the not-a-guarantee caveat.
# - Warnings (danger/caution) fire regardless of data staleness; staleness
#   only ever adds caveats, it never suppresses a warning.
# - Missing data fails closed: band "unavailable", pointing to BHMAC.
class MineCheckPublicController < ApplicationController
  DANGER_M = MineChecker::Bands::DANGER_M
  CAUTION_M = MineChecker::Bands::CAUTION_M

  # Visual overlay (owner decision 2026-07-21): boundaries are generalized
  # (simplified ~40 m) and explicitly labeled approximate; no metadata
  # (fileId etc.) is included. Viewport span is capped and rate-limited.
  AREAS_LIMIT = 800
  AREAS_SIMPLIFY_TOLERANCE = 0.0004
  AREAS_MAX_SPAN = { lon: 4.0, lat: 3.0 }.freeze

  def show
    @data_as_of = MineArea.suspected.maximum(:data_as_of)
  end

  def areas
    return render json: areas_overview if params[:overview].present?

    west = params[:west].to_f
    south = params[:south].to_f
    east = params[:east].to_f
    north = params[:north].to_f
    unless west < east && south < north &&
           (east - west) <= AREAS_MAX_SPAN[:lon] && (north - south) <= AREAS_MAX_SPAN[:lat]
      return render json: { error: "invalid_bbox" }, status: :unprocessable_entity
    end

    key = "mine_check/areas/#{west.round(2)}/#{south.round(2)}/#{east.round(2)}/#{north.round(2)}"
    payload = Rails.cache.fetch(key, expires_in: 1.day) do
      sql = ActiveRecord::Base.sanitize_sql([ <<~SQL, { w: west, s: south, e: east, n: north, tol: AREAS_SIMPLIFY_TOLERANCE, lim: AREAS_LIMIT + 1 } ])
        SELECT ST_AsGeoJSON(ST_SimplifyPreserveTopology(geom::geometry, (:tol)::float8), 5)
        FROM mine_areas
        WHERE kind = 'suspected'
          AND ST_Intersects(geom, ST_MakeEnvelope(:w, :s, :e, :n, 4326)::geography)
        ORDER BY ST_Area(geom) DESC
        LIMIT :lim
      SQL
      rows = ActiveRecord::Base.connection.select_values(sql)
      {
        type: "FeatureCollection",
        truncated: rows.size > AREAS_LIMIT,
        features: rows.first(AREAS_LIMIT).map do |gj|
          { type: "Feature", geometry: JSON.parse(gj), properties: {} }
        end
      }
    end
    render json: payload
  end

  def check
    lat = params[:lat].to_f
    lon = params[:lon].to_f
    unless lat.between?(-90.0, 90.0) && lon.between?(-180.0, 180.0) && (lat != 0.0 || lon != 0.0)
      return render json: { error: "invalid_coordinates" }, status: :unprocessable_entity
    end

    engine = params[:engine] == "static" ? "static" : "db"
    if engine == "static"
      index = MineChecker::StaticIndex.instance
      band = index.band_at(lat, lon)
      data_as_of = index.data_as_of
    else
      data_as_of = MineArea.suspected.maximum(:data_as_of)
      band =
        if data_as_of.nil?
          "unavailable"
        elsif !bbox_contains?(lat, lon)
          "out_of_coverage"
        else
          MineChecker::Bands.db_band_at(lat, lon)
        end
    end

    audit(band, lat, lon, data_as_of, engine)
    render json: {
      band: band,
      engine: engine,
      data_as_of: data_as_of&.iso8601,
      stale: data_as_of.nil? || data_as_of < MineChecker::Config.staleness_days.days.ago.to_date
    }
  end

  private

  # National-zoom overview: one dot per ~1 km grid cell (centroids rounded
  # to 2 decimals, deduplicated) — shows where areas are without shipping
  # boundary geometry at a zoom where boundaries would be dishonest anyway.
  def areas_overview
    Rails.cache.fetch("mine_check/areas_overview", expires_in: 1.day) do
      rows = ActiveRecord::Base.connection.select_rows(<<~SQL)
        SELECT DISTINCT round(ST_X(ST_Centroid(geom::geometry))::numeric, 2),
                        round(ST_Y(ST_Centroid(geom::geometry))::numeric, 2)
        FROM mine_areas
        WHERE kind = 'suspected'
      SQL
      {
        type: "FeatureCollection",
        features: rows.map do |lon, lat|
          { type: "Feature",
            geometry: { type: "Point", coordinates: [ lon.to_f, lat.to_f ] },
            properties: {} }
        end
      }
    end
  end

  def bbox_contains?(lat, lon)
    west, south, east, north = MineChecker::Config.bih_bbox
    lon.between?(west, east) && lat.between?(south, north)
  end

  # Exact coordinates go to the internal audit log only — never echoed back.
  def audit(band, lat, lon, data_as_of, engine)
    MineCheckAudit.create!(
      content_type: "PublicMineCheck",
      verdict: band,
      matches: [ { lat: lat.round(5), lon: lon.round(5), engine: engine } ],
      data_as_of: data_as_of
    )
  rescue StandardError => e
    Rails.logger.error("PublicMineCheck audit failed: #{e.class}: #{e.message}")
  end
end
