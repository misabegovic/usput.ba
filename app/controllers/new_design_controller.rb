class NewDesignController < ApplicationController
  layout "new_design"

  def home
    # Fetch positive reviews (rating 3+) with reviewable and user associations for display
    @positive_reviews = Review.approved.includes(:reviewable, :user)
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
                                  .left_joins(:reviews).where(reviews: { moderation_status: [ "approved", nil ] })
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
                                      .left_joins(:reviews).where(reviews: { moderation_status: [ "approved", nil ] })
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
    @tag = params[:tag]
    @origin = params[:origin]
    @audio_support = params[:audio_support] == "true"
    @accessible = params[:accessible] == "true"
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

    # The filter menus read every place; they change only when a place does.
    @city_names, @tags = Rails.cache.fetch([ "explore/filters", Location.not_archived.cache_key_with_version ]) do
      places = Location.not_archived
      [ places.where.not(city: [ nil, "" ]).distinct.pluck(:city).sort,
        places.where.not(tags: [ nil, [] ]).pluck(:tags).flatten.uniq.sort ]
    end

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
    base_browse = apply_browse_filters(Browse.smart_search(@query))
    base_browse = base_browse.nearby(@lat, @lng, radius_km: @radius) if @lat.present? && @lng.present?

    # A search naming exactly one place widens to what lies around it
    base_browse = widen_around_single_place(base_browse) || base_browse

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
    params.permit(:q, :season, :budget, :duration, :min_rating, :city_name, :tag,
                  :origin, :audio_support, :accessible, :lat, :lng, :radius, :sort, types: [])
          .to_h.reject { |_, value| value.blank? }
  end

  # Unfiltered, a traveller keeps seeing every moment they own, including ones
  # at places since retired that browse no longer indexes.
  def filters_active?
    @query.present? || @city_name.present? || @tag.present? || @season.present? || @budget.present? ||
      @min_rating.present? || @origin.present? || @accessible || (@lat.present? && @lng.present?)
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

  # One page of a type's results, read from the search index in one query.
  # A type's own filters (places only, public plans, audio, duration) ride the
  # index query as a subquery, so the database filters, orders and pages
  # together, and only the page's records are loaded. The order is the
  # index's (apply_browse_sort), as it always was.
  def page_from_browse(browse_scope, filter, records, page)
    page = [ page.to_i, 1 ].max
    matching = browse_scope.where(browsable_id: filter.select(:id))
    ids = matching.offset((page - 1) * PER_PAGE).limit(PER_PAGE).pluck(:browsable_id)
    by_id = ids.empty? ? {} : records.where(id: ids).index_by(&:id)
    Kaminari.paginate_array(ids.filter_map { |id| by_id[id] }, total_count: matching.count(:all))
            .page(page).per(PER_PAGE)
  end

  def build_locations_from_browse(base_browse)
    filter = Location.places
    # audio_support is location-specific, so it is not in the index
    filter = filter.where("EXISTS (SELECT 1 FROM audio_tours WHERE audio_tours.location_id = locations.id)") if @audio_support

    page_from_browse(base_browse.locations, filter, Location.places.with_attached_photos, @locations_page)
  end

  def build_experiences_from_browse(base_browse)
    filter = Experience.all
    filter = filter.by_duration(@duration) if @duration.present?

    page_from_browse(base_browse.experiences, filter,
                     Experience.includes(:experience_category).with_attached_cover_photo, @experiences_page)
  end

  def build_plans_from_browse(base_browse)
    filter = Plan.public_plans
    filter = filter.by_duration(@duration) if @duration.present?

    page_from_browse(base_browse.plans, filter, Plan.public_plans, @plans_page)
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

  # Every filter the traveller set, whichever rows they narrow: the search's
  # own matches and, when a search widens around a place, its neighbours too.
  def apply_browse_filters(scope)
    scope = scope.by_city_name(@city_name) if @city_name.present?
    scope = scope.by_tag(@tag) if @tag.present?
    scope = scope.by_min_rating(@min_rating) if @min_rating.present?
    scope = scope.by_season(@season) if @season.present?
    scope = scope.by_budget(@budget) if @budget.present?
    scope = scope.by_origin(@origin) if @origin.present?
    scope = scope.by_accessible(@accessible) if @accessible
    scope
  end

  # When the search matches exactly one place, the results are what matches
  # the words or lies within 10 km of that place, with the same filters on
  # both. nil when there is nothing to widen.
  def widen_around_single_place(base_browse)
    return nil if @query.blank?
    return nil if @lat.present? && @lng.present? # Already using nearby filter

    matching_locations = base_browse.locations.limit(2).pluck(:browsable_id)
    return nil unless matching_locations.one?

    location = Location.find_by(id: matching_locations.first)
    return nil unless location&.geocoded?

    # The words' matches by id, so the union carries no ranking order for #or
    # to refuse; the sort applied after it orders the whole set.
    words = Browse.where(id: Browse.smart_search(@query).select(:id))
    apply_browse_filters(words.or(Browse.nearby(location.lat, location.lng, radius_km: 10)))
  end
end
