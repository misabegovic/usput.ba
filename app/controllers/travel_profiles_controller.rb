class TravelProfilesController < ApplicationController
  before_action :require_login, except: [ :page, :my_plans ]

  PER_PAGE = 6

  VISITED_LIMIT = 24

  # GET /profile - Full travel profile page
  def page
    # Page is accessible to everyone, data comes from localStorage or server
    # Load user plans if logged in (first page for initial render)
    if logged_in?
      @plans = current_user.plans.without_explore_bosnia.includes(plan_experiences: :experience)
                           .order(created_at: :desc)
                           .page(1).per(PER_PAGE)

      # The traveller's most recent moments, across every plan — the same slice
      # the explore surface deals, not the whole collection.
      @moments = current_user.moments.with_attached_photo
                             .includes(:location, :plan)
                             .recent_own

      # Visited places come from the authoritative check-in (PlanVisit), not the
      # localStorage travel profile — one place a location becomes "visited".
      # The count is the whole passport; the list below it is a recent slice.
      @visited_count = current_user.plan_visits.distinct.count(:location_id)
      @visited_locations = current_user.plan_visits
                                       .includes(:location, :plan)
                                       .most_recent_per_location
                                       .limit(VISITED_LIMIT)
                                       .to_a
    end
  end

  # GET /profile/plans - Paginated plans for Turbo Frame
  def my_plans
    if logged_in?
      @plans = current_user.plans.without_explore_bosnia.includes(plan_experiences: :experience)
                           .order(created_at: :desc)
                           .page(params[:page]).per(PER_PAGE)
      render partial: "travel_profiles/my_plans_content", locals: { plans: @plans }
    else
      head :no_content
    end
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
      rescue JSON::ParserError
        render json: { success: false, error: "Invalid JSON" }, status: :bad_request
      rescue => e
        # The detail goes to the reporter, not to the caller: an exception
        # message names classes, columns and constraints.
        Rollbar.error(e) if defined?(Rollbar)
        render json: { success: false, error: t("travel_profile.sync_error") }, status: :unprocessable_entity
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
end
