class LocationsController < ApplicationController
  # Raised where a not-found would be, so the two answers stay one behaviour:
  # a retired place and a missing one both leave through a rescue_from on this
  # controller rather than through each action remembering to check.
  Retired = Class.new(StandardError)

  MAP_POINTS_TTL = 1.hour

  rescue_from ActiveRecord::RecordNotFound, with: :redirect_to_explore
  rescue_from Retired, with: :redirect_from_retired

  def show
    @location = visible_location(Location.includes(:reviews))

    if logged_in?
      visit = current_user.plan_visits.find_by(location: @location)
      @visited = visit.present?
      # Moments hang off a plan. Reuse the one the visit happened on rather
      # than minting anything; only a traveller who has never checked in
      # anywhere falls through to the ambient explore plan.
      @moments_plan = visit&.plan || Plan.explore_bosnia_for(current_user)
    end
    @reviews = @location.reviews.recent.limit(10)
    @review = Review.new
    @nearby_locations = @location.nearby_featured(limit: 3)

    # Experiences that include this location
    experiences_scope = @location.experiences
                                 .includes(:experience_category)
                                 .with_attached_cover_photo
                                 .order(average_rating: :desc)
    @related_experiences = experiences_scope.limit(3)
    @total_experiences_count = @location.experiences.count

    # Public plans that include this location (through experiences)
    plans_scope = Plan.public_plans
                      .joins(experiences: :locations)
                      .where(locations: { id: @location.id })
                      .distinct
    @related_plans = plans_scope.order(average_rating: :desc).limit(3)
    @total_plans_count = plans_scope.count
  end

  def audio_tour
    @location = visible_location(Location)
  end

  def map_points
    # Cached as the rendered string: a hit is bytes to the socket rather than
    # 10k hashes re-serialised. The etag lets a browser that already holds this
    # version be answered with a 304 instead of the payload.
    return unless stale?(etag: map_points_cache_key, public: true)

    payload = Rails.cache.fetch(map_points_cache_key, expires_in: MAP_POINTS_TTL) do
      Location.map_points.to_json
    end

    render json: payload
  end


  def map_panel
    location = visible_location(Location.includes(:reviews))

    render partial: "locations/map_panel", locals: { location: location, frame_id: panel_frame_id }
  end

  private

  # Matched against the shape dom_id emits rather than echoed, so no arbitrary
  # string from the query reaches the markup.
  def panel_frame_id
    frame = params[:frame].to_s
    frame.match?(/\Amap_panel_location_\d+\z/) ? frame : "map_panel"
  end

  # Content edits are the only thing that moves the catalogue.
  def map_points_cache_key
    "locations/map_points/#{I18n.locale}/#{helpers.map_points_version}"
  end

  def visible_location(scope)
    location = scope.find_by_public_id!(params[:id])
    raise Retired if location.archived?

    location
  end

  def redirect_to_explore
    answer_gone(t("locations.not_found"))
  end

  def redirect_from_retired
    answer_gone(t("locations.retired"))
  end

  # A frame cannot redirect the page — Turbo would fetch explore, find no frame
  # of that id, and blank the panel. Same sentence either way; only the
  # transport differs.
  def answer_gone(message)
    if turbo_frame_request?
      render partial: "locations/gone_panel",
             locals: { message: message, frame_id: panel_frame_id }
    else
      redirect_to explore_path, alert: message
    end
  end
end
