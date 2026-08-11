class MapRoutesController < ApplicationController
  CACHE_TTL = 1.hour
  # ~110 m. At 11 m no two travellers ever shared an entry, so every request was
  # a 5 s upstream call. Snapped before fetching too, so the line matches the key.
  ORIGIN_PRECISION = 3

  def show
    coordinates = coordinate_params
    return head :bad_request unless coordinates
    return head :service_unavailable if ENV["OPENROUTESERVICE_API_KEY"].blank?

    profile = requested_profile
    # A nil is a timeout, not an answer; caching it pins a 502 for an hour.
    route = Rails.cache.fetch(cache_key(coordinates, profile), expires_in: CACHE_TTL, skip_nil: true) do
      Maps::RouteFetcher.call(**coordinates, profile: profile)
    end
    return head :bad_gateway unless route

    render json: route
  end

  private

  def coordinate_params
    values = params.values_at(:from_lat, :from_lng, :to_lat, :to_lng)
    return nil if values.any?(&:blank?)

    from_lat, from_lng, to_lat, to_lng = values.map { |value| Float(value) }
    return nil unless from_lat.abs <= 90 && to_lat.abs <= 90 && from_lng.abs <= 180 && to_lng.abs <= 180

    { from_lat: from_lat.round(ORIGIN_PRECISION), from_lng: from_lng.round(ORIGIN_PRECISION),
      to_lat: to_lat, to_lng: to_lng }
  rescue ArgumentError, TypeError
    nil
  end

  def requested_profile
    Maps::RouteFetcher::PROFILES.include?(params[:profile]) ? params[:profile] : Maps::RouteFetcher::WALKING
  end

  def cache_key(coordinates, profile)
    "map_route/#{profile}/#{coordinates.values.join(",")}"
  end
end
