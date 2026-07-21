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
  DANGER_M = 500
  CAUTION_M = 2000

  def show
    @data_as_of = MineArea.suspected.maximum(:data_as_of)
  end

  def check
    lat = params[:lat].to_f
    lon = params[:lon].to_f
    unless lat.between?(-90.0, 90.0) && lon.between?(-180.0, 180.0) && (lat != 0.0 || lon != 0.0)
      return render json: { error: "invalid_coordinates" }, status: :unprocessable_entity
    end

    data_as_of = MineArea.suspected.maximum(:data_as_of)
    band =
      if data_as_of.nil?
        "unavailable"
      elsif !bbox_contains?(lat, lon)
        "out_of_coverage"
      else
        band_for(lat, lon)
      end

    audit(band, lat, lon, data_as_of)
    render json: {
      band: band,
      data_as_of: data_as_of&.iso8601,
      stale: data_as_of.nil? || data_as_of < MineChecker::Config.staleness_days.days.ago.to_date
    }
  end

  private

  def band_for(lat, lon)
    min_distance = MineArea.suspected
      .where("ST_DWithin(geom, ST_GeogFromText(:pt), :radius)", pt: wkt(lat, lon), radius: CAUTION_M)
      .pick(Arel.sql(ActiveRecord::Base.sanitize_sql([ "MIN(ST_Distance(geom, ST_GeogFromText(?)))", wkt(lat, lon) ])))

    if min_distance.nil?
      "no_known"
    elsif min_distance <= DANGER_M
      "danger"
    else
      "caution"
    end
  end

  def wkt(lat, lon)
    "SRID=4326;POINT(#{lon} #{lat})"
  end

  def bbox_contains?(lat, lon)
    west, south, east, north = MineChecker::Config.bih_bbox
    lon.between?(west, east) && lat.between?(south, north)
  end

  # Exact coordinates go to the internal audit log only — never echoed back.
  def audit(band, lat, lon, data_as_of)
    MineCheckAudit.create!(
      content_type: "PublicMineCheck",
      verdict: band,
      matches: [ { lat: lat.round(5), lon: lon.round(5) } ],
      data_as_of: data_as_of
    )
  rescue StandardError => e
    Rails.logger.error("PublicMineCheck audit failed: #{e.class}: #{e.message}")
  end
end
