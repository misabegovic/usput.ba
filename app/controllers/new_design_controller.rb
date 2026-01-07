class NewDesignController < ApplicationController
  layout "new_design"

  def home
    # Fetch positive reviews (rating 3+) with reviewable and user associations for display
    @positive_reviews = Review.includes(:reviewable, :user)
                              .where("rating >= ?", 3)
                              .where.not(comment: [ nil, "" ])
                              .order(created_at: :desc)
                              .limit(6)

    # Trending locations - minimum 3.5 rating, sorted by most recent review
    @trending_locations = Location.places
                                  .with_attached_photos
                                  .left_joins(:reviews)
                                  .where("locations.average_rating >= ?", 3.5)
                                  .where("locations.reviews_count > ?", 0)
                                  .group("locations.id")
                                  .order(Arel.sql("MAX(reviews.created_at) DESC NULLS LAST"))
                                  .limit(3)

    # Trending experiences - minimum 3.5 rating, sorted by most recent review
    @trending_experiences = Experience.includes(:experience_category)
                                      .with_attached_cover_photo
                                      .left_joins(:reviews)
                                      .where("experiences.average_rating >= ?", 3.5)
                                      .where("experiences.reviews_count > ?", 0)
                                      .group("experiences.id")
                                      .order(Arel.sql("MAX(reviews.created_at) DESC NULLS LAST"))
                                      .limit(2)
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
    @audio_support = params[:audio_support] == "true"
    @lat = params[:lat].presence&.to_f
    @lng = params[:lng].presence&.to_f
    @radius = params[:radius].presence&.to_i || 25
    @sort = params[:sort].presence || "newest"

    # Pagination params per resource type
    @locations_page = (params[:locations_page] || 1).to_i
    @experiences_page = (params[:experiences_page] || 1).to_i
    @plans_page = (params[:plans_page] || 1).to_i

    # Initialize empty result sets
    @locations = Location.none.page(1)
    @experiences = Experience.none.page(1)
    @plans = Plan.none.page(1)

    # Determine which types to search
    search_types = @types.presence || %w[location experience plan]

    # Always use Browse model for consistent search and filtering
    build_browse_queries(search_types)

    # Load city names for filter dropdown
    @city_names = Location.where.not(city: [nil, ""])
                          .distinct
                          .pluck(:city)
                          .sort

    # Load categories for filter dropdown
    @experience_categories = ExperienceCategory.active.ordered
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
  end

  # Build queries without Browse (when no search query)
  def build_direct_queries(search_types)
    if search_types.include?("location")
      @locations = build_locations_query
    end

    if search_types.include?("experience")
      @experiences = build_experiences_query
    end

    if search_types.include?("plan")
      @plans = build_plans_query
    end
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
    scope = scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array(["array_position(ARRAY[?]::bigint[], locations.id)", matching_ids]))) if matching_ids.any?
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
    scope = scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array(["array_position(ARRAY[?]::bigint[], experiences.id)", matching_ids]))) if matching_ids.any?
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
    scope = scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array(["array_position(ARRAY[?]::bigint[], plans.id)", matching_ids]))) if matching_ids.any?
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
        scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array(["CASE WHEN LOWER(locations.name) LIKE ? THEN 0 ELSE 1 END", "#{sanitized_query}%"])), :name)
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
        scope.order(Arel.sql(ActiveRecord::Base.sanitize_sql_array(["CASE WHEN LOWER(experiences.title) LIKE ? THEN 0 ELSE 1 END", "#{sanitized_query}%"])), :title)
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
