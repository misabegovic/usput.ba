class Browse < ApplicationRecord
  # Polymorphic association to the source model
  belongs_to :browsable, polymorphic: true

  # Validations
  validates :title, presence: true
  validates :browsable_type, inclusion: { in: %w[Location Experience Plan] }
  validates :browsable_id, uniqueness: { scope: :browsable_type }

  # Scopes for filtering by type
  scope :locations, -> { where(browsable_type: "Location") }
  scope :experiences, -> { where(browsable_type: "Experience") }
  scope :plans, -> { where(browsable_type: "Plan") }

  # Scope for full-text search using PostgreSQL
  scope :search, ->(query) {
    return all if query.blank?

    sanitized_query = sanitize_sql_like(query.to_s.strip)
    # Use plainto_tsquery for simple word matching, or websearch_to_tsquery for advanced search
    # Use sanitize_sql_array to prevent SQL injection in order clause
    order_sql = sanitize_sql_array(["ts_rank(searchable, plainto_tsquery('simple', ?)) DESC", sanitized_query])
    where("searchable @@ plainto_tsquery('simple', ?)", sanitized_query)
      .order(Arel.sql(order_sql))
  }

  # Fallback search using ILIKE for partial matches
  scope :search_fuzzy, ->(query) {
    return all if query.blank?

    pattern = "%#{sanitize_sql_like(query.to_s.strip.downcase)}%"
    where("LOWER(title) LIKE :q OR LOWER(description) LIKE :q", q: pattern)
  }

  # Combined search: prefer full-text, fallback to fuzzy
  scope :smart_search, ->(query) {
    return all if query.blank?

    fts_results = search(query)
    fts_results.exists? ? fts_results : search_fuzzy(query)
  }

  # Filter by city name
  scope :by_city_name, ->(city_name) {
    return all if city_name.blank?
    where(city_name: city_name)
  }

  # Filter by minimum rating
  scope :by_min_rating, ->(min_rating) {
    return all if min_rating.blank?
    where("average_rating >= ?", min_rating.to_f)
  }

  # Filter by subtype (location_type, experience_category, etc.)
  scope :by_subtype, ->(subtype) {
    return all if subtype.blank?
    where(browsable_subtype: subtype)
  }

  # Filter by budget level (cumulative: low=low, medium=low+medium, high=all)
  # Uses Location.budgets enum values: low=0, medium=1, high=2
  scope :by_budget, ->(budget) {
    return all if budget.blank?
    budget_value = Location.budgets[budget.to_s]
    return all if budget_value.nil?
    where("budget IS NULL OR budget <= ?", budget_value)
  }

  # Filter by category key (uses GIN index on jsonb array)
  scope :by_category_key, ->(category_key) {
    return all if category_key.blank?
    where("category_keys @> ?", [ category_key ].to_json)
  }

  # Filter by season - matches if seasons array contains the season OR is empty (year-round)
  # Seasons: spring, summer, fall, winter
  scope :by_season, ->(season) {
    return all if season.blank?
    where("seasons = '[]'::jsonb OR seasons @> ?", [ season ].to_json)
  }

  # Filter by multiple seasons (OR logic - matches any of the provided seasons)
  scope :by_seasons, ->(seasons) {
    return all if seasons.blank?
    seasons = Array(seasons).map(&:to_s)
    conditions = seasons.map { "seasons @> ?" }
    where("seasons = '[]'::jsonb OR #{conditions.join(' OR ')}", *seasons.map { |s| [ s ].to_json })
  }

  # Nearby search - searches locations directly by coordinates,
  # and experiences/plans by their associated locations
  scope :nearby, ->(lat, lng, radius_km: 25) {
    return all if lat.blank? || lng.blank?

    lat = lat.to_f
    lng = lng.to_f

    # Calculate bounding box
    lat_delta = radius_km / 111.0 # ~111km per degree latitude
    lng_delta = radius_km / (111.0 * Math.cos(lat * Math::PI / 180))

    min_lat = lat - lat_delta
    max_lat = lat + lat_delta
    min_lng = lng - lng_delta
    max_lng = lng + lng_delta

    # Find location IDs within bounding box
    nearby_location_ids = Location
      .where("lat BETWEEN ? AND ?", min_lat, max_lat)
      .where("lng BETWEEN ? AND ?", min_lng, max_lng)
      .pluck(:id)

    return none if nearby_location_ids.empty?

    # Find experience IDs that have any location within bounding box
    nearby_experience_ids = ExperienceLocation
      .where(location_id: nearby_location_ids)
      .pluck(:experience_id)
      .uniq

    # Find plan IDs that have any experience with location within bounding box
    nearby_plan_ids = PlanExperience
      .joins(experience: :experience_locations)
      .where(experience_locations: { location_id: nearby_location_ids })
      .pluck(:plan_id)
      .uniq

    # Build conditions dynamically to avoid IN (NULL) issues
    conditions = []
    values = []

    # Locations directly within bounding box
    conditions << "(browsable_type = 'Location' AND browsable_id IN (?))"
    values << nearby_location_ids

    # Experiences with locations within bounding box
    if nearby_experience_ids.any?
      conditions << "(browsable_type = 'Experience' AND browsable_id IN (?))"
      values << nearby_experience_ids
    end

    # Plans with experiences that have locations within bounding box
    if nearby_plan_ids.any?
      conditions << "(browsable_type = 'Plan' AND browsable_id IN (?))"
      values << nearby_plan_ids
    end

    where(conditions.join(" OR "), *values)
  }

  # Sorting options
  scope :by_relevance, -> { order(average_rating: :desc, reviews_count: :desc) }
  scope :by_rating, -> { order(average_rating: :desc) }
  scope :by_newest, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:title) }

  # Get the original record
  def original_record
    browsable
  end

  # Type helpers
  def location?
    browsable_type == "Location"
  end

  def experience?
    browsable_type == "Experience"
  end

  def plan?
    browsable_type == "Plan"
  end

  # Class methods for syncing data
  class << self
    # Sync a single record to Browse
    def sync_record(record)
      return unless syncable?(record)

      browse = find_or_initialize_by(browsable: record)
      attributes = BrowseAdapter.attributes_for(record)

      if attributes
        browse.update!(attributes)
      else
        browse.destroy if browse.persisted?
      end
    end

    # Remove a record from Browse
    def remove_record(record)
      where(browsable: record).destroy_all
    end

    # Check if a record should be synced
    def syncable?(record)
      case record
      when Location
        record.place_type? # Only sync places, not contacts (uses new category system)
      when Experience
        true # Always sync experiences
      when Plan
        record.visibility_public_plan? # Only sync public plans
      else
        false
      end
    end

    # Rebuild entire Browse table
    def rebuild_all!
      transaction do
        delete_all

        # Sync all locations (places only - using place_type? which supports new category system)
        Location.includes(:location_categories).find_each do |loc|
          sync_record(loc) if loc.place_type?
        end

        # Sync all experiences
        Experience.find_each { |exp| sync_record(exp) }

        # Sync all public plans
        Plan.public_plans.find_each { |plan| sync_record(plan) }
      end
    end
  end
end
