require "net/http"

# Minolovac — classic minesweeper played over scenic static-map backdrops of
# Bosnia and Herzegovina. Mine placement is random and fictional, generated
# client-side per game; this feature has no connection to any real mine data.
class MinolovacController < ApplicationController
  REGIONS = {
    "sarajevo" => { name: "Sarajevo", lat: 43.8563, lon: 18.4131, zoom: 12 },
    "mostar" => { name: "Mostar", lat: 43.3438, lon: 17.8078, zoom: 12 },
    "banja-luka" => { name: "Banja Luka", lat: 44.7722, lon: 17.1910, zoom: 12 },
    "jajce" => { name: "Jajce", lat: 44.3420, lon: 17.2703, zoom: 13 },
    "una" => { name: "NP Una", lat: 44.8169, lon: 15.8708, zoom: 11 },
    "sutjeska" => { name: "NP Sutjeska", lat: 43.3350, lon: 18.6900, zoom: 11 }
  }.freeze

  DIFFICULTIES = {
    "easy" => { rows: 9, cols: 9, mines: 10 },
    "medium" => { rows: 12, cols: 12, mines: 24 },
    "hard" => { rows: 14, cols: 14, mines: 40 }
  }.freeze

  MAP_CACHE_TTL = 30.days

  def show
    if params[:region].present? && !REGIONS.key?(params[:region])
      return redirect_to minolovac_path
    end

    @region_slug = params[:region] || "sarajevo"
    @region = REGIONS[@region_slug]
    @level = DIFFICULTIES.key?(params[:level]) ? params[:level] : "easy"
    @difficulty = DIFFICULTIES[@level]
  end

  # Proxies the Geoapify static map server-side so the API key never reaches
  # the client. Missing key or upstream failure returns 404 and the game
  # falls back to a plain backdrop.
  def map
    region = REGIONS[params[:region]]
    return head :not_found unless region

    api_key = Rails.application.config.geoapify.api_key
    return head :not_found if api_key.blank?

    png = Rails.cache.fetch("minolovac/map/#{params[:region]}", expires_in: MAP_CACHE_TTL, skip_nil: true) do
      fetch_static_map(region, api_key)
    end
    return head :not_found if png.blank?

    expires_in MAP_CACHE_TTL, public: true
    send_data png, type: "image/png", disposition: "inline"
  end

  private

  def fetch_static_map(region, api_key)
    uri = URI("https://maps.geoapify.com/v1/staticmap")
    uri.query = URI.encode_www_form(
      style: "osm-carto",
      width: 600,
      height: 600,
      center: "lonlat:#{region[:lon]},#{region[:lat]}",
      zoom: region[:zoom],
      apiKey: api_key
    )
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess) ? response.body : nil
  rescue StandardError => e
    Rails.logger.warn("Minolovac map fetch failed: #{e.class}: #{e.message}")
    nil
  end
end
