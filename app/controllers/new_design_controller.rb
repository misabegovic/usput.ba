class NewDesignController < ApplicationController
  layout "new_design"

  def home
    # Fetch positive reviews (rating 3+) with reviewable and user associations for display
    @positive_reviews = Review.includes(:reviewable, :user)
                              .where("rating >= ?", 3)
                              .where.not(comment: [ nil, "" ])
                              .order(created_at: :desc)
                              .limit(6)

    # A handful of the newest approved public moments for the home strip
    @recent_moments = Moment.publicly_visible
                               .with_attached_photo
                               .includes(:user, :location)
                               .order(created_at: :desc)
                               .limit(4)

    # Trending locations - minimum 3.5 rating, sorted by most recent review
    @trending_locations = Location.places
                                  .with_attached_photos
                                  .left_joins(:reviews)
                                  .where("locations.average_rating >= ?", 3.5)
                                  .where("locations.reviews_count > ?", 0)
                                  .group("locations.id")
                                  .order(Arel.sql("MAX(reviews.created_at) DESC NULLS LAST"))
                                  .limit(3)

    # Fallback to random locations if none found with filters
    if @trending_locations.empty?
      @trending_locations = Location.places
                                    .with_attached_photos
                                    .order("RANDOM()")
                                    .limit(3)
    end

    # Trending experiences - minimum 3.5 rating, sorted by most recent review
    @trending_experiences = Experience.includes(:experience_category)
                                      .with_attached_cover_photo
                                      .left_joins(:reviews)
                                      .where("experiences.average_rating >= ?", 3.5)
                                      .where("experiences.reviews_count > ?", 0)
                                      .group("experiences.id")
                                      .order(Arel.sql("MAX(reviews.created_at) DESC NULLS LAST"))
                                      .limit(2)

    # Fallback to random experiences if none found with filters
    if @trending_experiences.empty?
      @trending_experiences = Experience.includes(:experience_category)
                                        .with_attached_cover_photo
                                        .order("RANDOM()")
                                        .limit(2)
    end
  end

  PER_PAGE = 3

  def explore
    @query = params[:q]
    @types = Array(params[:types]).reject(&:blank?)
    @season = params[:season]
    @budget = params[:budget]
    @duration = params[:duration]
    @min_rating = params[:min_rating]
    @city_name = params[:city_name]
    @origin = params[:origin]
    @audio_support = params[:audio_support] == "true"
    @lat = params[:lat].presence&.to_f
    @lng = params[:lng].presence&.to_f
    @radius = params[:radius].presence&.to_i || 25
    @sort = params[:sort].presence || "relevance"

    # The load-more fetch carries the filters in its own url instead of reading
    # them back from the address bar: an open moment viewer rewrites that to the
    # moment's own address, which has no query string.
    @filter_params = filter_params

    # Pagination params per resource type
    @locations_page = (params[:locations_page] || 1).to_i
    @experiences_page = (params[:experiences_page] || 1).to_i
    @plans_page = (params[:plans_page] || 1).to_i
    @moments_page = (params[:moments_page] || 1).to_i
    @my_moments_page = (params[:my_moments_page] || 1).to_i

    # Initialize empty result sets
    @locations = Location.none.page(1)
    @experiences = Experience.none.page(1)
    @plans = Plan.none.page(1)
    @moments = Moment.none.page(1)
    @my_moments = Moment.none.page(1)

    # Determine which types to search
    search_types = @types.presence || %w[location experience plan moment]

    # A moment's own address lands here. The named one leads its band so the
    # viewer opens on the first tile, which keeps one moments view rather than a
    # second that merely resembles it.
    @named_moment = readable_named_moment

    # Asked for a moment nobody may show them: the address is not theirs to keep,
    # so it becomes the moments view's own url rather than lying about what is on
    # screen. A private moment and an id that never existed redirect alike, so the
    # url still says nothing about whether the moment exists.
    return redirect_to(explore_path(types: [ "moment" ])) if params[:id].present? && @named_moment.nil?

    # Always use Browse model for consistent search and filtering
    build_browse_queries(search_types)

    @open_band = band_holding_named_moment

    # Load city names for filter dropdown
    @city_names = Location.not_archived.where.not(city: [ nil, "" ])
                          .distinct
                          .pluck(:city)
                          .sort

    # Load categories for filter dropdown
    @experience_categories = ExperienceCategory.active.ordered

    # Handle partial/AJAX requests for "Load More" functionality
    if params[:partial].present? && request.xhr?
      render_partial_for(params[:partial])
    end
  end

  def render_partial_for(partial_type)
    case partial_type
    when "locations"
      render partial: "new_design/explore/locations_items", locals: { locations: @locations }, layout: false
    when "experiences"
      render partial: "new_design/explore/experiences_items", locals: { experiences: @experiences }, layout: false
    when "plans"
      render partial: "new_design/explore/plans_items", locals: { plans: @plans }, layout: false
    when "moments"
      render partial: "new_design/explore/moments_items", locals: { moments: @moments }, layout: false
    when "my_moments"
      render partial: "new_design/explore/my_moments_items", locals: { moments: @my_moments }, layout: false
    end
  end

  private

  # Build queries using the Browse model for optimized full-text search
  def build_browse_queries(search_types)
    # Build base Browse query with common filters
    base_browse = Browse.smart_search(@query)
    base_browse = base_browse.by_city_name(@city_name) if @city_name.present?
    base_browse = base_browse.by_min_rating(@min_rating) if @min_rating.present?
    base_browse = base_browse.by_season(@season) if @season.present?
    base_browse = base_browse.by_budget(@budget) if @budget.present?
    base_browse = base_browse.by_origin(@origin) if @origin.present?
    base_browse = base_browse.nearby(@lat, @lng, radius_km: @radius) if @lat.present? && @lng.present?

    # Check if search matches a single place - if so, expand to nearby items
    single_place_expansion = find_single_place_for_expansion(base_browse)
    if single_place_expansion
      @matched_place = single_place_expansion[:place]
      @nearby_radius = 10 # 10 km radius for single place expansion
      base_browse = single_place_expansion[:expanded_browse]
    end

    base_browse = apply_browse_sort(base_browse)

    if search_types.include?("location")
      @locations = build_locations_from_browse(base_browse)
    end

    if search_types.include?("experience")
      @experiences = build_experiences_from_browse(base_browse)
    end

    if search_types.include?("plan")
      @plans = build_plans_from_browse(base_browse)
    end

    if search_types.include?("moment")
      @moments = build_moments_from_browse(base_browse)
      @my_moments = build_own_moments(base_browse)
    end
  end

  # Browse indexes only public moments, so own ones are read from the
  # association and kept beside the public results, never merged into them.
  def build_own_moments(base_browse)
    return Moment.none.page(1) unless logged_in?

    scope = current_user.moments.with_attached_photo.includes(:location, :plan)
    # A moment's note is indexed, but only once public and approved — a
    # traveller's own list includes private ones, so location is the only
    # handle that narrows the whole set.
    scope = scope.where(location_id: base_browse.locations.select(:browsable_id)) if filters_active?
    lead_own_with_named(scope.newest_first).page(@my_moments_page).per(PER_PAGE)
  end

  # Public to anyone, yours to you, nil for the rest — someone else's private
  # moment and an id that never existed answer identically, so the url never
  # says whether a private moment exists.
  def readable_named_moment
    return nil if params[:id].blank?

    public_moment = Moment.publicly_visible.find_by_public_id(params[:id])
    return public_moment if public_moment || !logged_in?

    current_user.moments.find_by_public_id(params[:id])
  end

  # Named only where it genuinely leads the band: the viewer opens on index 0,
  # so a moment that did not reach page one must not claim to be there.
  def band_holding_named_moment
    return nil if @named_moment.nil?
    return "moments" if @moments.first&.id == @named_moment.id
    return "my_moments" if @my_moments.first&.id == @named_moment.id

    nil
  end

  # Order is defined by this array, so moving the id is all the hoisting takes —
  # paging and load-more keep working against it unchanged.
  def lead_with_named(ids)
    named = @named_moment&.id
    return ids unless named && ids.include?(named)

    [ named, *(ids - [ named ]) ]
  end

  # Kaminari pages whatever order it is handed; leading with the named moment
  # keeps it on page one, which is the page the viewer opens against.
  def lead_own_with_named(scope)
    named = @named_moment&.id
    return scope unless named

    scope.reorder(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "(moments.id = ?) DESC", named ])),
                  created_at: :desc)
  end

  # Passed through as given rather than rebuilt from the ivars: the fetch has to
  # reproduce this request, and @radius and @sort carry defaults that were never
  # asked for. id, partial and the *_page keys stay out — loadMore sets its own
  # page, and an id would re-name a moment on every fetch.
  def filter_params
    params.permit(:q, :season, :budget, :duration, :min_rating, :city_name,
                  :origin, :audio_support, :lat, :lng, :radius, :sort, types: [])
          .to_h.reject { |_, value| value.blank? }
  end

  # Unfiltered, a traveller keeps seeing every moment they own, including ones
  # at places since retired that browse no longer indexes.
  def filters_active?
    @query.present? || @city_name.present? || @season.present? || @budget.present? ||
      @min_rating.present? || @origin.present? || (@lat.present? && @lng.present?)
  end

  def build_moments_from_browse(base_browse)
    # reorder replaces the caller's by_relevance: a moment ranks on its own likes.
    moment_rows = base_browse.moments
    moment_rows = moment_rows.reorder(reviews_count: :desc, id: :desc) if @sort == "relevance"
    matching_ids = lead_with_named(moment_rows.pluck(:browsable_id))
    return Moment.none.page(1) if matching_ids.empty?

    # Browse only indexes approved public moments; publicly_visible re-asserts it.
    scope = Moment.publicly_visible
                  .with_attached_photo
                  .includes(:user, :location)
                  .where(id: matching_ids)

    scope = scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "array_position(ARRAY[?]::bigint[], moments.id)", matching_ids ])))
    scope.page(@moments_page).per(PER_PAGE)
  end

  # Build locations from Browse results
  def build_locations_from_browse(base_browse)
    # Get matching location IDs from Browse
    browse_scope = base_browse.locations
    matching_ids = browse_scope.pluck(:browsable_id)

    return Location.none.page(1) if matching_ids.empty?

    # Build the actual location query using the Browse-matched IDs
    scope = Location.places
                    .with_attached_photos
                    .where(id: matching_ids)

    # Apply additional filters not in Browse (audio_support is location-specific)
    if @audio_support
      # Use EXISTS subquery instead of joins + distinct to avoid ORDER BY issues
      scope = scope.where("EXISTS (SELECT 1 FROM audio_tours WHERE audio_tours.location_id = locations.id)")
    end

    # Preserve the order from Browse search (by relevance)
    # Use sanitized SQL to prevent SQL injection (matching_ids are integers from DB)
    scope = scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "array_position(ARRAY[?]::bigint[], locations.id)", matching_ids ]))) if matching_ids.any?
    scope = apply_location_sort(scope) unless @sort == "relevance"

    scope.page(@locations_page).per(PER_PAGE)
  end

  # Build experiences from Browse results
  def build_experiences_from_browse(base_browse)
    # Get matching experience IDs from Browse
    browse_scope = base_browse.experiences
    matching_ids = browse_scope.pluck(:browsable_id)

    return Experience.none.page(1) if matching_ids.empty?

    # Build the actual experience query using the Browse-matched IDs
    scope = Experience.includes(:experience_category)
                      .with_attached_cover_photo
                      .where(id: matching_ids)

    # Apply additional filters not in Browse
    if @duration.present?
      scope = scope.by_duration(@duration)
    end

    # Preserve the order from Browse search (by relevance)
    # Use sanitized SQL to prevent SQL injection (matching_ids are integers from DB)
    scope = scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "array_position(ARRAY[?]::bigint[], experiences.id)", matching_ids ]))) if matching_ids.any?
    scope = apply_experience_sort(scope) unless @sort == "relevance"

    scope.page(@experiences_page).per(PER_PAGE)
  end

  # Build plans from Browse results
  def build_plans_from_browse(base_browse)
    # Get matching plan IDs from Browse
    browse_scope = base_browse.plans
    matching_ids = browse_scope.pluck(:browsable_id)

    return Plan.none.page(1) if matching_ids.empty?

    # Build the actual plan query using the Browse-matched IDs
    scope = Plan.public_plans
                .where(id: matching_ids)

    # Apply additional filters not in Browse
    if @duration.present?
      scope = scope.by_duration(@duration)
    end

    # Preserve the order from Browse search (by relevance)
    # Use sanitized SQL to prevent SQL injection (matching_ids are integers from DB)
    scope = scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "array_position(ARRAY[?]::bigint[], plans.id)", matching_ids ]))) if matching_ids.any?
    scope = apply_plan_sort(scope) unless @sort == "relevance"

    scope.page(@plans_page).per(PER_PAGE)
  end

  # Apply sorting to Browse query
  def apply_browse_sort(scope)
    case @sort
    when "rating"
      scope.by_rating
    when "newest"
      scope.by_newest
    when "name"
      scope.by_name
    else # relevance
      scope.by_relevance
    end
  end

  def build_locations_query
    scope = Location.places.with_attached_photos

    # Text search
    if @query.present?
      scope = scope.where("LOWER(locations.name) LIKE :q OR LOWER(locations.description) LIKE :q",
                          q: "%#{@query.downcase}%")
    end

    # Season filter - locations are always available (no season restriction)
    # Season filtering is primarily for experiences

    # Budget filter
    if @budget.present?
      scope = scope.by_budget(@budget)
    end

    # Rating filter
    if @min_rating.present?
      scope = scope.by_min_rating(@min_rating)
    end

    # City filter
    if @city_name.present?
      scope = scope.by_city(@city_name)
    end

    # Audio support filter
    if @audio_support
      # Use EXISTS subquery instead of joins + distinct to avoid ORDER BY issues
      scope = scope.where("EXISTS (SELECT 1 FROM audio_tours WHERE audio_tours.location_id = locations.id)")
    end

    # Nearby filter
    if @lat.present? && @lng.present?
      scope = scope.nearby(@lat, @lng, radius_km: @radius)
    end

    # Sorting
    scope = apply_location_sort(scope)

    scope.page(@locations_page).per(PER_PAGE)
  end

  def build_experiences_query
    scope = Experience.includes(:experience_category).with_attached_cover_photo

    # Text search
    if @query.present?
      scope = scope.where("LOWER(experiences.title) LIKE :q OR LOWER(experiences.description) LIKE :q",
                          q: "%#{@query.downcase}%")
    end

    # Season filter
    if @season.present?
      scope = scope.by_season(@season)
    end

    # Duration filter
    if @duration.present?
      scope = scope.by_duration(@duration)
    end

    # Rating filter
    if @min_rating.present?
      scope = scope.by_min_rating(@min_rating)
    end

    # City filter (through locations)
    if @city_name.present?
      scope = scope.by_city_name(@city_name)
    end

    # Nearby filter
    if @lat.present? && @lng.present?
      scope = scope.nearby(@lat, @lng, radius_km: @radius)
    end

    # Sorting
    scope = apply_experience_sort(scope)

    scope.page(@experiences_page).per(PER_PAGE)
  end

  def build_plans_query
    scope = Plan.public_plans

    # Text search
    if @query.present?
      scope = scope.search_by_text(@query)
    end

    # Duration filter
    if @duration.present?
      scope = scope.by_duration(@duration)
    end

    # City filter
    if @city_name.present?
      scope = scope.by_city_name(@city_name)
    end

    # Nearby filter (using locations within plans)
    if @lat.present? && @lng.present?
      scope = scope.nearby_by_locations(@lat, @lng, radius_km: @radius)
    end

    # Sorting
    scope = apply_plan_sort(scope)

    scope.page(@plans_page).per(PER_PAGE)
  end

  def apply_location_sort(scope)
    case @sort
    when "rating"
      scope.order(average_rating: :desc)
    when "newest"
      scope.order(created_at: :desc)
    when "name"
      scope.order(:name)
    else # relevance or default
      if @query.present?
        # Use sanitized SQL to prevent SQL injection
        sanitized_query = ActiveRecord::Base.sanitize_sql_like(@query.downcase)
        scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "CASE WHEN LOWER(locations.name) LIKE ? THEN 0 ELSE 1 END", "#{sanitized_query}%" ])), :name)
      else
        scope.order(average_rating: :desc, reviews_count: :desc)
      end
    end
  end

  def apply_experience_sort(scope)
    case @sort
    when "rating"
      scope.order(average_rating: :desc)
    when "newest"
      scope.order(created_at: :desc)
    when "duration"
      scope.order(:estimated_duration)
    when "name"
      scope.order(:title)
    else # relevance or default
      if @query.present?
        # Use sanitized SQL to prevent SQL injection
        sanitized_query = ActiveRecord::Base.sanitize_sql_like(@query.downcase)
        scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "CASE WHEN LOWER(experiences.title) LIKE ? THEN 0 ELSE 1 END", "#{sanitized_query}%" ])), :title)
      else
        scope.order(average_rating: :desc, reviews_count: :desc)
      end
    end
  end

  def apply_plan_sort(scope)
    case @sort
    when "rating"
      scope.order(average_rating: :desc)
    when "newest"
      scope.order(created_at: :desc)
    when "name"
      scope.order(:title)
    else # relevance or default
      scope.order(created_at: :desc)
    end
  end

  # Check if the search query matches exactly one place (Location)
  # If so, expand to include all nearby items within 10km radius
  def find_single_place_for_expansion(base_browse)
    return nil if @query.blank?
    return nil if @lat.present? && @lng.present? # Already using nearby filter

    # Check if query matches exactly one location
    matching_locations = base_browse.locations.limit(2)
    return nil unless matching_locations.count == 1

    # Get the matched location
    browse_record = matching_locations.first
    location = Location.find_by(id: browse_record.browsable_id)
    return nil unless location&.geocoded?

    # Build expanded browse query including all items within 10km radius
    # Start fresh with smart_search to preserve text relevance
    expanded_browse = Browse.smart_search(@query)
    expanded_browse = expanded_browse.by_city_name(@city_name) if @city_name.present?
    expanded_browse = expanded_browse.by_min_rating(@min_rating) if @min_rating.present?
    expanded_browse = expanded_browse.by_season(@season) if @season.present?
    expanded_browse = expanded_browse.by_budget(@budget) if @budget.present?
    expanded_browse = expanded_browse.by_origin(@origin) if @origin.present?

    # Now add nearby items that match the search OR are within 10km of the matched location
    nearby_browse = Browse.nearby(location.lat, location.lng, radius_km: 10)

    # Combine: items matching search query OR items nearby the matched location
    expanded_browse = expanded_browse.or(nearby_browse)

    {
      place: location,
      expanded_browse: expanded_browse
    }
  end
end
