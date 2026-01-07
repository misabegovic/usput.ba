class TravelProfilesController < ApplicationController
  before_action :require_login, except: [ :page, :my_plans ]

  PER_PAGE = 6

  # Maximum distance in kilometers to validate a visit claim
  MAX_VISIT_DISTANCE_KM = 0.5 # 500 meters

  # GET /profile - Full travel profile page
  def page
    # Page is accessible to everyone, data comes from localStorage or server
    # Load user plans if logged in (first page for initial render)
    if logged_in?
      @plans = current_user.plans.includes(plan_experiences: :experience)
                           .order(created_at: :desc)
                           .page(1).per(PER_PAGE)
    end
  end

  # GET /profile/plans - Paginated plans for Turbo Frame
  def my_plans
    if logged_in?
      @plans = current_user.plans.includes(plan_experiences: :experience)
                           .order(created_at: :desc)
                           .page(params[:page]).per(PER_PAGE)
      render partial: "travel_profiles/my_plans_content", locals: { plans: @plans }
    else
      head :no_content
    end
  end

  # GET /travel_profile
  def show
    render json: { travel_profile_data: current_user.travel_profile_data }
  end

  # PATCH /travel_profile
  def update
    if params[:travel_profile_data].present?
      begin
        profile_data = params[:travel_profile_data].is_a?(String) ?
          JSON.parse(params[:travel_profile_data]) :
          params[:travel_profile_data].to_unsafe_h

        current_user.merge_travel_profile(profile_data)
        render json: { success: true, travel_profile_data: current_user.travel_profile_data }
      rescue JSON::ParserError => e
        render json: { success: false, error: "Invalid JSON" }, status: :bad_request
      rescue => e
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end
    else
      render json: { success: false, error: "No profile data provided" }, status: :bad_request
    end
  end

  # POST /travel_profile/sync
  def sync
    if params[:travel_profile_data].present?
      begin
        profile_data = params[:travel_profile_data].is_a?(String) ?
          JSON.parse(params[:travel_profile_data]) :
          params[:travel_profile_data].to_unsafe_h

        current_user.merge_travel_profile(profile_data)
        render json: {
          success: true,
          travel_profile_data: current_user.travel_profile_data,
          message: "Profile synced successfully"
        }
      rescue JSON::ParserError
        render json: { success: false, error: "Invalid JSON" }, status: :bad_request
      end
    else
      # Just return current server data
      render json: {
        success: true,
        travel_profile_data: current_user.travel_profile_data
      }
    end
  end

  # POST /travel_profile/validate_visit
  # Validates that user is physically near a location before marking it as visited
  def validate_visit
    location_id = params[:location_id]
    user_lat = params[:user_lat].to_f
    user_lng = params[:user_lng].to_f

    # Validate required parameters
    if location_id.blank?
      return render json: { success: false, error: "Location ID is required" }, status: :bad_request
    end

    if user_lat.zero? && user_lng.zero?
      return render json: { success: false, error: "User coordinates are required" }, status: :bad_request
    end

    # Find the location by UUID
    location = Location.find_by_public_id(location_id)
    unless location
      return render json: { success: false, error: "Location not found" }, status: :not_found
    end

    # Check if location has coordinates
    unless location.geocoded?
      return render json: { success: false, error: "Location does not have coordinates" }, status: :unprocessable_entity
    end

    # Calculate distance between user and location
    distance_km = location.distance_from(user_lat, user_lng)

    if distance_km <= MAX_VISIT_DISTANCE_KM
      # User is close enough - add to visited
      visit_data = {
        "id" => location.uuid,
        "type" => "location",
        "name" => location.name,
        "visitedAt" => Time.current.iso8601,
        "city" => location.city,
        "tags" => location.tags
      }

      add_visit_to_profile(visit_data)

      render json: {
        success: true,
        validated: true,
        distance_km: distance_km.round(3),
        travel_profile_data: current_user.reload.travel_profile_data,
        message: I18n.t("travel_profile.visit_recorded")
      }
    else
      # User is too far away
      distance_text = distance_km >= 1 ?
        "#{distance_km.round(1)} km" :
        "#{(distance_km * 1000).round} m"
      render json: {
        success: false,
        validated: false,
        distance_km: distance_km.round(3),
        max_distance_km: MAX_VISIT_DISTANCE_KM,
        error: I18n.t("travel_profile.too_far_from_location", distance: distance_text, max_distance: (MAX_VISIT_DISTANCE_KM * 1000).to_i)
      }, status: :unprocessable_entity
    end
  end

  private

  def add_visit_to_profile(visit_data)
    current_data = current_user.travel_profile_data
    visited = current_data["visited"] || []

    # Check if already visited
    already_visited = visited.any? { |v| v["id"] == visit_data["id"] && v["type"] == visit_data["type"] }
    return if already_visited

    # Add to visited
    visited << visit_data

    # Update stats
    stats = current_data["stats"] || {}
    stats["totalVisits"] = (stats["totalVisits"] || 0) + 1

    if visit_data["city"].present? && !stats["citiesVisited"]&.include?(visit_data["city"])
      stats["citiesVisited"] = (stats["citiesVisited"] || []) + [ visit_data["city"] ]
    end

    current_season = get_current_season
    unless stats["seasonsVisited"]&.include?(current_season)
      stats["seasonsVisited"] = (stats["seasonsVisited"] || []) + [ current_season ]
    end

    # Save updated profile
    current_user.update!(
      travel_profile_data: current_data.merge(
        "visited" => visited,
        "stats" => stats,
        "updatedAt" => Time.current.iso8601
      )
    )
  end

  def get_current_season
    month = Time.current.month
    case month
    when 3..5 then "spring"
    when 6..8 then "summer"
    when 9..11 then "autumn"
    else "winter"
    end
  end
end
