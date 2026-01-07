class Location < ApplicationRecord
  include Identifiable
  include Translatable
  include Reviewable
  include Browsable

  # Translatable fields - these can have translations in multiple languages
  translates :name, :description, :historical_context

  # Geocoder konfiguracija
  reverse_geocoded_by :lat, :lng

  # Active Storage attachments
  has_many_attached :photos

  # Asocijacije
  has_many :experience_locations, dependent: :destroy
  has_many :experiences, through: :experience_locations
  has_many :location_experience_types, dependent: :destroy
  has_many :experience_types, through: :location_experience_types
  has_many :audio_tours, dependent: :destroy

  # Location categories (many-to-many - a location can have multiple categories)
  has_many :location_category_assignments, dependent: :destroy
  has_many :location_categories, through: :location_category_assignments

  # Enums
  enum :budget, { low: 0, medium: 1, high: 2 }

  # DEPRECATED: location_type enum - use location_category instead
  # Kept for backwards compatibility during migration period
  enum :location_type, {
    place: 0,        # Standardna lokacija/atrakcija
    guide: 1,        # Lokalni vodič
    business: 2,     # Lokalni biznis/firma
    restaurant: 3,   # Restoran/kafić
    artisan: 4,      # Zanatlija/proizvođač
    accommodation: 5 # Smještaj
  }

  # Validations
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :phone, format: { with: /\A[\d\s\+\-\(\)]+\z/, message: "must be a valid phone number" }, allow_blank: true
  validates :lat, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :lng, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :lat, uniqueness: { scope: :lng, message: "i longitude kombinacija već postoji" }, allow_nil: true
  validates :video_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  # Callbacks
  after_save :sync_experience_types_from_json, if: :saved_change_to_suitable_experiences?

  # Custom validation for coordinates (both or neither)
  validate :coordinates_must_be_complete

  # ============================================================================
  # SCOPES - Core queries on Location table
  # For search/listing with filters, prefer Browse model which has denormalized
  # data and proper indexes. Use these scopes for direct Location queries.
  # ============================================================================

  scope :by_city, ->(city_name) { where(city: city_name) }
  scope :by_experience, ->(experience) {
    joins(:experience_types).where(experience_types: { key: experience })
  }
  scope :with_tag, ->(tag) { where("tags @> ?", [ tag ].to_json) }
  scope :with_coordinates, -> { where.not(lat: nil, lng: nil) }

  # Scope for locations with audio tours
  scope :with_audio, -> {
    joins(:audio_tours).merge(AudioTour.with_audio).distinct
  }

  # Scopes za tipove lokacija - uses location_categories (many-to-many) with fallback to legacy enum
  # Using subqueries instead of joins + distinct to avoid ORDER BY conflicts
  scope :places, -> {
    # Locations that either:
    # 1. Have no categories assigned, OR
    # 2. Have at least one non-contact category, OR
    # 3. Have legacy place type
    where(
      # No categories assigned
      "NOT EXISTS (SELECT 1 FROM location_category_assignments WHERE location_category_assignments.location_id = locations.id)"
    ).or(
      # Has at least one non-contact category
      where(
        "EXISTS (SELECT 1 FROM location_category_assignments lca
         JOIN location_categories lc ON lc.id = lca.location_category_id
         WHERE lca.location_id = locations.id AND lc.key NOT IN (?))", %w[guide business artisan]
      )
    ).or(
      # Legacy place type
      where(location_type: :place)
    )
  }
  scope :contacts, -> {
    # Locations with contact category, OR legacy non-place type
    where(
      "EXISTS (SELECT 1 FROM location_category_assignments lca
       JOIN location_categories lc ON lc.id = lca.location_category_id
       WHERE lca.location_id = locations.id AND lc.key IN (?))", %w[guide business artisan]
    ).or(where.not(location_type: :place))
  }
  scope :by_category, ->(category_key) {
    return all if category_key.blank?
    where(
      "EXISTS (SELECT 1 FROM location_category_assignments lca
       JOIN location_categories lc ON lc.id = lca.location_category_id
       WHERE lca.location_id = locations.id AND lc.key = ?)", category_key
    )
  }
  scope :with_contact_info, -> { where.not(phone: [nil, ""]).or(where.not(email: [nil, ""])) }

  # Filter by type/category - supports both new category key and legacy enum
  scope :by_type, ->(type) {
    return all if type.blank?
    # Try new category first, fall back to legacy enum
    category = LocationCategory.find_by_key(type)
    if category
      where(
        "EXISTS (SELECT 1 FROM location_category_assignments
         WHERE location_category_assignments.location_id = locations.id
         AND location_category_assignments.location_category_id = ?)", category.id
      )
    else
      where(location_type: type)
    end
  }

  # NOTE: For search/listing, prefer Browse.by_budget and Browse.by_min_rating
  # which use denormalized, indexed data. These scopes are for direct queries.

  # Filter by budget level (cumulative: low=low, medium=low+medium, high=all)
  scope :by_budget, ->(budget) {
    return all if budget.blank?
    budget_value = budgets[budget.to_s]
    return all if budget_value.nil?
    where("budget <= ?", budget_value)
  }

  # Filter by minimum rating
  scope :by_min_rating, ->(min_rating) {
    where("locations.average_rating >= ?", min_rating.to_f)
  }

  # Get supported experiences dynamically from database
  def self.supported_experiences
    ExperienceType.active_keys
  end

  # Get supported social platforms dynamically from settings or use defaults
  def self.supported_social_platforms
    Setting.get("social.platforms", default: nil)&.then { |v| JSON.parse(v) rescue nil } ||
      %w[facebook instagram twitter linkedin youtube tiktok whatsapp viber]
  end

  # Ensure tags and suitable_experiences are always arrays
  def tags
    super || []
  end

  # Get suitable experiences (combines JSON field with association)
  def suitable_experiences
    # Prefer association data if already loaded, otherwise use JSON field
    if experience_types.loaded?
      experience_types.map(&:key)
    else
      read_attribute(:suitable_experiences) || []
    end
  end

  # Set suitable experiences (updates both JSON and association)
  def suitable_experiences=(values)
    super(values)
    sync_experience_types_from_array(values) if persisted?
  end

  # Helper to add a tag
  def add_tag(tag)
    self.tags = (tags + [ tag.to_s.strip.downcase ]).uniq
  end

  # Helper to remove a tag
  def remove_tag(tag)
    self.tags = tags - [ tag.to_s.strip.downcase ]
  end

  # Helper to add an experience type
  def add_experience_type(experience_type_or_key)
    exp_type = experience_type_or_key.is_a?(ExperienceType) ?
      experience_type_or_key :
      ExperienceType.find_by_key(experience_type_or_key)

    return unless exp_type

    location_experience_types.find_or_create_by(experience_type: exp_type)
    update_suitable_experiences_json
  end

  # Helper to remove an experience type
  def remove_experience_type(experience_type_or_key)
    exp_type = experience_type_or_key.is_a?(ExperienceType) ?
      experience_type_or_key :
      ExperienceType.find_by_key(experience_type_or_key)

    return unless exp_type

    location_experience_types.find_by(experience_type: exp_type)&.destroy
    update_suitable_experiences_json
  end

  # Legacy method for backwards compatibility
  def add_experience(experience)
    add_experience_type(experience)
  end

  # Legacy method for backwards compatibility
  def remove_experience(experience)
    remove_experience_type(experience)
  end

  # Check if location has a specific experience type
  def has_experience_type?(experience_type_or_key)
    key = experience_type_or_key.is_a?(ExperienceType) ?
      experience_type_or_key.key :
      experience_type_or_key.to_s

    experience_types.exists?(key: key)
  end

  # Ensure social_links is always a hash
  def social_links
    super || {}
  end

  # Helper to add a social link
  def add_social_link(platform, url)
    platform_key = platform.to_s.strip.downcase
    platforms = self.class.supported_social_platforms
    return unless platforms.include?(platform_key)

    self.social_links = social_links.merge(platform_key => url.to_s.strip)
  end

  # Helper to remove a social link
  def remove_social_link(platform)
    platform_key = platform.to_s.strip.downcase
    self.social_links = social_links.except(platform_key)
  end

  # Get a specific social link
  def social_link(platform)
    social_links[platform.to_s.strip.downcase]
  end

  # Check if this is a contact type (guide, business, artisan)
  def contact?
    location_categories.any?(&:contact_type?) || (location_type.present? && !place?)
  end

  # Check if this is a place type (not a contact)
  def place_type?
    return place? if location_categories.empty?
    location_categories.any?(&:place_type?)
  end

  # Get primary category (first one marked as primary, or just first one)
  def primary_category
    location_category_assignments.find_by(primary: true)&.location_category ||
      location_categories.first
  end

  # Get all category keys
  def category_keys
    location_categories.pluck(:key)
  end

  # Get primary category key (for display and API - backwards compatible)
  def category_key
    primary_category&.key || location_type
  end

  # Get primary category name (for display - backwards compatible)
  def category_name
    primary_category&.name || location_type&.titleize
  end

  # Get all category names
  def category_names
    location_categories.pluck(:name)
  end

  # Add a category to this location
  def add_category(category_or_key, primary: false)
    category = category_or_key.is_a?(LocationCategory) ?
      category_or_key :
      LocationCategory.find_by_key(category_or_key)
    return unless category

    assignment = location_category_assignments.find_or_create_by(location_category: category)
    assignment.update(primary: true) if primary
    assignment
  end

  # Remove a category from this location
  def remove_category(category_or_key)
    category = category_or_key.is_a?(LocationCategory) ?
      category_or_key :
      LocationCategory.find_by_key(category_or_key)
    return unless category

    location_category_assignments.find_by(location_category: category)&.destroy
  end

  # Check if location has a specific category
  def has_category?(category_or_key)
    key = category_or_key.is_a?(LocationCategory) ?
      category_or_key.key :
      category_or_key.to_s
    location_categories.exists?(key: key)
  end

  # Check if has any contact information
  def has_contact_info?
    phone.present? || email.present? || website.present?
  end

  # Returns the city name as address
  def address
    city
  end

  # Find existing location by exact coordinates or initialize a new one
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @param attributes [Hash] Attributes for new location if not found
  # @return [Location] Existing or new location (not persisted if new)
  def self.find_or_initialize_by_coordinates(lat, lng, attributes = {})
    return new(attributes.merge(lat: lat, lng: lng)) if lat.blank? || lng.blank?

    existing = find_by(lat: lat.to_f, lng: lng.to_f)
    existing || new(attributes.merge(lat: lat.to_f, lng: lng.to_f))
  end

  # Find existing location by exact coordinates or create a new one
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @param attributes [Hash] Attributes for new location if not found
  # @return [Location] Existing or newly created location
  def self.find_or_create_by_coordinates(lat, lng, attributes = {})
    location = find_or_initialize_by_coordinates(lat, lng, attributes)
    location.save! if location.new_record?
    location
  end

  # Find existing location by coordinates with tolerance (for fuzzy matching)
  # Useful when coordinates might have small precision differences
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @param tolerance [Float] Tolerance in degrees (default: 0.0001 ≈ 11 meters)
  # @return [Location, nil] Existing location or nil
  def self.find_by_coordinates_fuzzy(lat, lng, tolerance: 0.0001)
    return nil if lat.blank? || lng.blank?

    where(
      "lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?",
      lat.to_f - tolerance, lat.to_f + tolerance,
      lng.to_f - tolerance, lng.to_f + tolerance
    ).first
  end

  # Pronađi lokacije u određenom radijusu (u km)
  def self.nearby(lat, lng, radius_km: 10)
    with_coordinates.near([ lat, lng ], radius_km, units: :km)
  end

  # Pronađi lokacije u istom gradu
  def self.in_same_city(location)
    return none unless location.city.present?
    where(city: location.city).where.not(id: location.id)
  end

  # Pronađi najbliže lokacije
  def nearby_locations(radius_km: 10, limit: 10)
    return self.class.none unless lat.present? && lng.present?
    self.class.nearby(lat, lng, radius_km: radius_km)
              .where.not(id: id)
              .limit(limit)
  end

  # Pronađi istaknute lokacije u blizini (sortirane po kvaliteti recenzija i najnovijem ažuriranju)
  def nearby_featured(limit: 3)
    return self.class.none unless city.present?

    self.class
      .where(city: city)
      .where.not(id: id)
      .order(
        Arel.sql("COALESCE(average_rating, 0) DESC"),
        updated_at: :desc
      )
      .limit(limit)
  end

  # Pronađi lokacije u istom gradu
  def locations_in_same_city
    self.class.in_same_city(self)
  end

  # Koordinate kao array
  def coordinates
    return nil unless lat.present? && lng.present?
    [ lat, lng ]
  end

  # Provjeri da li ima koordinate
  def geocoded?
    lat.present? && lng.present?
  end

  # Udaljenost od danih koordinata u km
  def distance_from(other_lat, other_lng)
    return nil unless geocoded?
    Geocoder::Calculations.distance_between(
      [ lat, lng ],
      [ other_lat, other_lng ],
      units: :km
    )
  end

  # Audio tour helpers for multilingual support

  # Get audio tour for a specific locale
  def audio_tour_for(locale)
    audio_tours.find_by(locale: locale.to_s)
  end

  # Get audio tour for locale with fallback chain
  # Falls back to: requested locale -> default locale -> English -> any available
  def audio_tour_with_fallback(locale)
    audio_tour_for(locale) ||
      audio_tour_for(I18n.default_locale) ||
      audio_tour_for("en") ||
      audio_tours.with_audio.first
  end

  # Check if location has any audio tours
  def has_audio_tours?
    audio_tours.with_audio.exists?
  end

  # Get all available audio tour locales
  def available_audio_locales
    audio_tours.with_audio.pluck(:locale)
  end

  # Check if audio tour exists for specific locale
  def has_audio_tour_for?(locale)
    audio_tours.by_locale(locale.to_s).with_audio.exists?
  end

  private

  # Sync experience types from JSON field to association
  def sync_experience_types_from_json
    return unless persisted?
    json_experiences = read_attribute(:suitable_experiences) || []
    sync_experience_types_from_array(json_experiences)
  end

  # Sync experience types from array to association
  def sync_experience_types_from_array(experience_keys)
    return unless persisted?
    return if experience_keys.blank?

    experience_keys = Array(experience_keys).map(&:to_s).map(&:downcase).uniq

    # Find matching experience types
    types = ExperienceType.where("LOWER(key) IN (?)", experience_keys)

    # Update association
    self.experience_types = types
  end

  # Update JSON field from association
  def update_suitable_experiences_json
    write_attribute(:suitable_experiences, experience_types.pluck(:key))
    save! if persisted? && changed?
  end

  # Validate that coordinates are complete (both or neither)
  def coordinates_must_be_complete
    if lat.present? != lng.present?
      errors.add(:base, "Both latitude and longitude must be provided, or neither")
    end
  end
end
