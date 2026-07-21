# Public mine-proximity check (owner-authorized Phase 2 — see
# docs/mine_checker/README.md), served entirely by the static engine.
# Fail-safe properties, non-negotiable:
# - Verdicts are coarse BANDS only; no distances or exact geometry.
# - There is no "safe" answer — best case is "no known intersections",
#   always with the data date and the not-a-guarantee caveat.
# - Warnings fire regardless of data staleness; staleness only adds
#   caveats, it never suppresses a warning.
# - Missing artifacts fail closed: band "unavailable", pointing to BHMAC.
class MineCheckPublicController < ApplicationController
  AREAS_MAX_SPAN = { lon: 4.0, lat: 3.0 }.freeze

  def show
    @data_as_of = index.available? ? index.data_as_of : nil
  end

  def check
    lat = params[:lat].to_f
    lon = params[:lon].to_f
    unless lat.between?(-90.0, 90.0) && lon.between?(-180.0, 180.0) && (lat != 0.0 || lon != 0.0)
      return render json: { error: "invalid_coordinates" }, status: :unprocessable_entity
    end

    band = index.band_at(lat, lon)
    audit(band, lat, lon)
    render json: {
      band: band,
      data_as_of: index.available? ? index.data_as_of.iso8601 : nil,
      stale: !index.available? || index.stale?
    }
  end

  def areas
    return render_overview if params[:overview].present?

    west = params[:west].to_f
    south = params[:south].to_f
    east = params[:east].to_f
    north = params[:north].to_f
    unless west < east && south < north &&
           (east - west) <= AREAS_MAX_SPAN[:lon] && (north - south) <= AREAS_MAX_SPAN[:lat]
      return render json: { error: "invalid_bbox" }, status: :unprocessable_entity
    end

    payload = index.tile_features(west, south, east, north)
    return head :not_found unless payload

    render json: payload
  end

  private

  def index
    MineChecker::StaticIndex.instance
  end

  def render_overview
    json = index.overview_json
    return head :not_found unless json

    render json: json
  end

  # Exact coordinates go to the internal audit log only — never echoed back.
  def audit(band, lat, lon)
    MineCheckAudit.create!(
      content_type: "PublicMineCheck",
      verdict: band,
      matches: [ { lat: lat.round(5), lon: lon.round(5) } ],
      data_as_of: index.available? ? index.data_as_of : nil
    )
  rescue StandardError => e
    Rails.logger.error("PublicMineCheck audit failed: #{e.class}: #{e.message}")
  end
end
