class Experience < ApplicationRecord
  include Identifiable
  include Translatable
  include Reviewable
  include Browsable

  # Translatable fields - these can have translations in multiple languages
  translates :title, :description

  # Active Storage attachments
  has_one_attached :cover_photo

  # Asocijacije
  belongs_to :experience_category, optional: true
  has_many :experience_locations, -> { order(position: :asc) }, dependent: :destroy
  has_many :locations, through: :experience_locations
  has_many :plan_experiences, dependent: :destroy
  has_many :plans, through: :plan_experiences

  # Valid seasons
  SEASONS = %w[spring summer fall winter].freeze

  # Validations
  validates :title, presence: true
  validates :estimated_duration, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :with_locations, -> { joins(:experience_locations).distinct }
  scope :by_category, ->(category) {
    if category.is_a?(ExperienceCategory)
      where(experience_category_id: category.id)
    else
      # Look up by UUID
      cat = ExperienceCategory.find_by_public_id(category)
      where(experience_category_id: cat&.id)
    end
  }
  scope :uncategorized, -> { where(experience_category_id: nil) }

  # Find experiences that have locations near given coordinates
  scope :nearby, ->(lat, lng, radius_km: 25) {
    joins(:locations)
      .merge(Location.nearby(lat, lng, radius_km: radius_km))
      .distinct
  }

  # Filter by duration range (in minutes)
  scope :by_duration, ->(duration_filter) {
    case duration_filter.to_s
    when "short"
      where("estimated_duration <= ?", 60)
    when "medium"
      where("estimated_duration > ? AND estimated_duration <= ?", 60, 180)
    when "long"
      where("estimated_duration > ?", 180)
    else
      all
    end
  }

  # Filter by rating
  scope :by_min_rating, ->(min_rating) {
    where("experiences.average_rating >= ?", min_rating.to_f)
  }

  # Filter by city name (through locations)
  scope :by_city_name, ->(city_name) {
    joins(:locations).where(locations: { city: city_name }).distinct
  }

  # Filter by season - matches if seasons array contains the season OR is empty (year-round)
  scope :by_season, ->(season) {
    return all if season.blank?
    where("seasons = '[]'::jsonb OR seasons @> ?", [ season ].to_json)
  }

  # Filter by multiple seasons (OR logic)
  scope :by_seasons, ->(seasons) {
    return all if seasons.blank?
    seasons = Array(seasons).map(&:to_s)
    conditions = seasons.map { "seasons @> ?" }
    where("seasons = '[]'::jsonb OR #{conditions.join(' OR ')}", *seasons.map { |s| [ s ].to_json })
  }

  # Experiences available year-round (empty seasons array)
  scope :year_round, -> { where("seasons = '[]'::jsonb") }

  # Dodaj lokaciju na određenu poziciju
  def add_location(location, position: nil)
    pos = position || (experience_locations.maximum(:position) || 0) + 1
    experience_locations.create(location: location, position: pos)
  end

  # Ukloni lokaciju
  def remove_location(location)
    experience_locations.find_by(location: location)&.destroy
  end

  # Reorganizuj pozicije lokacija
  def reorder_locations(location_ids)
    transaction do
      location_ids.each_with_index do |loc_id, index|
        experience_locations.find_by(location_id: loc_id)&.update(position: index + 1)
      end
    end
  end

  # Broj lokacija u experience-u
  def locations_count
    experience_locations.count
  end

  # Formatirano trajanje
  def formatted_duration
    return nil unless estimated_duration

    hours = estimated_duration / 60
    minutes = estimated_duration % 60

    if hours > 0 && minutes > 0
      "#{hours}h #{minutes}min"
    elsif hours > 0
      "#{hours}h"
    else
      "#{minutes}min"
    end
  end

  # Get category name (for display)
  def category_name
    experience_category&.name
  end

  # Get category key (for programmatic use)
  def category_key
    experience_category&.key
  end

  # Get the city from the first location (for display purposes)
  def city
    locations.first&.city
  end

  # Check if experience has any contact information
  def has_contact_info?
    contact_name.present? || contact_email.present? || contact_phone.present? || contact_website.present?
  end

  # Season helpers

  # Ensure seasons is always an array
  def seasons
    super || []
  end

  # Check if experience is available in a specific season
  def available_in_season?(season)
    seasons.empty? || seasons.include?(season.to_s)
  end

  # Check if experience is available year-round
  def year_round?
    seasons.empty?
  end

  # Add a season
  def add_season(season)
    season = season.to_s.downcase
    return unless SEASONS.include?(season)
    self.seasons = (seasons + [ season ]).uniq
  end

  # Remove a season
  def remove_season(season)
    self.seasons = seasons - [ season.to_s.downcase ]
  end

  # Set all seasons (year-round)
  def set_year_round!
    self.seasons = []
  end

  # Get human-readable season names
  def season_names
    return [ "Year-round" ] if seasons.empty?
    seasons.map(&:titleize)
  end

  # Find featured experiences nearby (in the same city, sorted by rating and recency)
  def nearby_featured(limit: 3)
    current_city = city
    return self.class.none unless current_city.present?

    # Use subquery to avoid DISTINCT + ORDER BY conflict in PostgreSQL
    experience_ids = self.class
      .joins(:locations)
      .where(locations: { city: current_city })
      .where.not(id: id)
      .select("DISTINCT experiences.id")

    self.class
      .where(id: experience_ids)
      .order(
        Arel.sql("COALESCE(experiences.average_rating, 0) DESC"),
        updated_at: :desc
      )
      .limit(limit)
  end
end
