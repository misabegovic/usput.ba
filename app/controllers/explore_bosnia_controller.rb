class ExploreBosniaController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :redirect_to_menu

  PAGE_SIZE = 10

  # Position orders the deck, it does not bound it: a traveller anywhere is dealt
  # the whole country, nearest first. Geocoder still wants a radius for its WHERE
  # box, so this one is wide enough to hold every place we have.
  RADIUS_KM = 20_000

  # Where to deal from for an admin who never answered the location prompt.
  DEFAULT_ORIGIN = [ 43.8563, 18.4131 ].freeze # Sarajevo

  BROWSE_TILES = {
    "history" => %w[history],
    "culture" => %w[culture art],
    "sport_nature" => %w[sport nature woods mountains],
    "food_drinks" => %w[food vegan vegetarian meat],
    "religious" => %w[religious],
    "relax" => %w[wellness nightlife]
  }.freeze

  ALL_CATEGORIES = "all"

  # The tile grid is gone: entry is the deck itself, which asks for a position and
  # says so while it waits.
  def show
    lat, lng = origin
    redirect_to explore_bosnia_experience_path(ALL_CATEGORIES, **(lat ? { lat: lat, lng: lng } : {}))
  end

  def experience
    @category = params[:category]
    # ALL_CATEGORIES, and anything unrecognised, deals every category.
    @selected_tiles = Array(params[:categories]).select { |key| BROWSE_TILES.key?(key) }.presence ||
                      Array(BROWSE_TILES.key?(@category) ? @category : nil)
    @type_keys = @selected_tiles.flat_map { |key| BROWSE_TILES[key] }.uniq
    @tile_keys = BROWSE_TILES.keys

    @lat, @lng = origin
    @needs_location = @lat.nil?
    # Either the deck said the browser never answered, or the origin came from
    # the request's address rather than from the traveller's device.
    @approximate_origin = params[:approx] == "1" || (@lat.present? && params[:lat].blank?)
    return if @needs_location

    # An absent filter is a first visit and takes the default; an empty one is a
    # pill the traveller turned off, and must stay off.
    @season = params.key?(:season) ? params[:season].presence : Location.current_season
    @budget = params.key?(:budget) ? params[:budget].presence : Location.budgets.keys.last
    @min_rating = params[:min_rating].presence

    # A guest has no plan to hang check-ins on; theirs stay on the device until
    # they sign in, so the deck is dealt without one.
    @plan = Plan.explore_bosnia_for(current_user) if logged_in?
    from = cursor
    @locations, @has_more = dealt_locations(cursor: from)
    @next_cursor = @has_more ? [ @locations.last.distance, @locations.last.id ] : nil
    # "nothing here" and "you have been to all of it" read identically to a
    # traveller otherwise, and the second is the common one.
    @all_visited = @locations.empty? && from.nil? && dealt_locations(skip_visited: false).first.any?

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  # Client-first with an IP fallback, which is the standard shape for this: the
  # browser's answer is authoritative and arrives late, so the request's own
  # address carries the deck until it does — and carries it permanently for the
  # traveller whose browser never answers. City-level accuracy orders a deck
  # honestly; it decides no check-in, because the gate reads the browser only.
  def origin
    lat = params[:lat].presence&.to_f
    lng = params[:lng].presence&.to_f
    return [ lat, lng ] if lat && lng

    approximate_origin || (current_user_admin? ? DEFAULT_ORIGIN : [ nil, nil ])
  end

  def approximate_origin
    @approximate_origin_coordinates ||= Maps::IpPosition.call(request.remote_ip)
  end

  def apply_filters(scope)
    scope = scope.by_season(@season) if @season
    # by_budget drops places that carry no budget, and the widest choice is the
    # same set as no filter at all, so it stays a no-op.
    scope = scope.by_budget(@budget) if @budget && @budget != Location.budgets.keys.last
    scope = scope.by_min_rating(@min_rating) if @min_rating
    scope
  end

  def filter_params
    base = { season: @season, budget: @budget, min_rating: @min_rating }.compact
    return base if @selected_tiles.blank? || @selected_tiles == [ @category ]

    base.merge(categories: @selected_tiles)
  end
  helper_method :filter_params

  # Season and budget always carry a value, so counting them would badge a page
  # nobody has filtered.
  def chosen_filter_count
    filter_params.count do |name, value|
      case name
      when :season then value != Location.current_season
      when :budget then value != Location.budgets.keys.last
      else true
      end
    end
  end
  helper_method :chosen_filter_count

  def next_page_params
    distance, id = @next_cursor
    filter_params.merge(lat: @lat, lng: @lng, after_distance: distance, after_id: id)
  end
  helper_method :next_page_params

  def cursor
    distance = params[:after_distance].presence
    id = params[:after_id].presence
    return nil unless distance && id

    [ distance.to_f, id.to_i ]
  end

  # Keyset, not offset: visiting a place drops it out of the set, and an offset
  # skips a place every time one does. The row comparison is the ORDER BY read as
  # a cursor. One row past the page is fetched and dropped, so "is there more"
  # comes from a place that exists rather than from this page being full.
  def dealt_locations(skip_visited: true, cursor: nil)
    scope = Location.with_coordinates
    scope = scope.where(id: tile_location_ids) if @type_keys.any?
    scope = scope.where.not(id: current_user.plan_visits.select(:location_id)) if skip_visited && logged_in?
    scope = apply_filters(scope)
    scope = scope.with_card_content
                 .near([ @lat, @lng ], RADIUS_KM, units: :km)
                 .order(:id)

    if cursor
      # Geocoder builds this from two floats, and the cursor is bound — the
      # interpolation carries no user string, whatever the scanner reads.
      distance_sql = Location.distance_from_sql([ @lat, @lng ], units: :km)
      scope = scope.where("(#{distance_sql}, locations.id) > (?, ?)", *cursor)
    end

    rows = scope.limit(PAGE_SIZE + 1).to_a
    [ rows.first(PAGE_SIZE), rows.size > PAGE_SIZE ]
  end

  # Ids, not a join: a tile spans several types, and SELECT DISTINCT can't be
  # combined with the computed distance Geocoder orders by.
  def tile_location_ids
    type_ids = ExperienceType.active.where(key: @type_keys).select(:id)

    Location.joins(:location_experience_types)
            .where(location_experience_types: { experience_type_id: type_ids })
            .distinct
            .select(:id)
  end

  def redirect_to_menu
    redirect_to explore_bosnia_path
  end
end
