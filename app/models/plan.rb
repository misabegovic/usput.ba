class Plan < ApplicationRecord
  include Identifiable
  include Translatable
  include Reviewable
  include Browsable

  # Translatable fields - these can have translations in multiple languages
  translates :title, :notes

  # Visibility enum
  enum :visibility, { private_plan: 0, public_plan: 1 }, prefix: true

  # Preferences the device is allowed to author. The column also carries the
  # explore marker, which decides which listings a plan appears in and which
  # plan check-ins ride on, so it is set here and never from a payload.
  DEVICE_PREFERENCE_KEYS = %w[budget meat_lover custom_title interests].freeze

  # Returns custom_title if set, otherwise falls back to title
  def display_title
    custom_title = preferences&.dig("custom_title")
    custom_title.present? ? custom_title : title
  end

  # Asocijacije
  belongs_to :user, optional: true
  has_many :plan_experiences, -> { order(day_number: :asc, position: :asc) }, dependent: :destroy
  has_many :experiences, through: :plan_experiences

  # Standalone locations a user adds to a specific day (separate from the locations
  # nested inside experiences). Named :location_items to avoid clashing with the
  # experience-derived #locations helper further down.
  has_many :plan_locations, -> { order(day_number: :asc, position: :asc) }, dependent: :destroy
  has_many :location_items, through: :plan_locations, source: :location

  # Private per-traveller photos of this plan's locations. Not scoped to the
  # plan's owner: anyone viewing a public plan collects their own moments on it.
  has_many :moments, dependent: :destroy
  has_many :plan_visits, dependent: :destroy

  # A check-in and a moment belong to the location, not to the itinerary that
  # brought the traveller there — so the cascade above must never reach them.
  # Every traveller's rows, the owner's included, move to that traveller's own
  # explore plan before the plan goes.
  before_destroy :rehome_traveller_records, prepend: true

  # Setter for experience_days (used by content change proposals)
  # Format: { "1" => ["uuid1", "uuid2"], "2" => ["uuid3"] }
  def experience_days=(days_hash)
    return if days_hash.blank?

    transaction do
      # Clear existing experiences
      plan_experiences.destroy_all

      # Add new experiences for each day
      days_hash.each do |day_number, experience_uuids|
        next if experience_uuids.blank?

        experience_uuids.each_with_index do |uuid, position|
          next if uuid.blank?
          experience = Experience.find_by(uuid: uuid)
          next unless experience

          plan_experiences.create!(
            experience: experience,
            day_number: day_number.to_i,
            position: position
          )
        end
      end
    end
  end

  # Getter for experience_days
  def experience_days
    days = {}
    plan_experiences.includes(:experience).group_by(&:day_number).each do |day_num, plan_exps|
      days[day_num.to_s] = plan_exps.sort_by(&:position).map { |pe| pe.experience.uuid }
    end
    days
  end

  # Setter for location_days (used by content change proposals / curator editing)
  # Format: { "1" => ["uuid1", "uuid2"], "2" => ["uuid3"] }
  def location_days=(days_hash)
    return if days_hash.blank?

    transaction do
      # Clear existing standalone locations
      plan_locations.destroy_all

      # Add new locations for each day
      days_hash.each do |day_number, location_uuids|
        next if location_uuids.blank?

        location_uuids.each_with_index do |uuid, position|
          next if uuid.blank?
          location = Location.find_by(uuid: uuid)
          next unless location

          plan_locations.create!(
            location: location,
            day_number: day_number.to_i,
            position: position
          )
        end
      end
    end
  end

  # Getter for location_days
  def location_days
    days = {}
    plan_locations.includes(:location).group_by(&:day_number).each do |day_num, plan_locs|
      days[day_num.to_s] = plan_locs.sort_by(&:position).map { |pl| pl.location.uuid }
    end
    days
  end

  # Validacije
  validates :title, presence: true
  # start_date and end_date are optional - users pick their own dates
  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }

  # Scopes
  scope :upcoming, -> { where("start_date >= ?", Date.current) }
  scope :past, -> { where("end_date < ?", Date.current) }
  scope :active, -> { where("start_date <= ? AND end_date >= ?", Date.current, Date.current) }
  scope :for_city, ->(city_name) { where(city_name: city_name) }
  scope :by_city_name, ->(city_name) { where(city_name: city_name) }
  scope :by_start_date, -> { order(start_date: :asc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :public_plans, -> { visibility_public_plan }
  scope :private_plans, -> { visibility_private_plan }
  scope :without_explore_bosnia, -> { where("preferences IS NULL OR NOT (preferences @> ?)", { explore_bosnia: true }.to_json) }

  # The hidden per-user plan that explore-mode check-ins and moments ride on.
  # Marked in preferences so no schema change is needed; excluded from plan
  # listings via .without_explore_bosnia.
  def self.explore_bosnia_for(user)
    user.plans.where("preferences @> ?", { explore_bosnia: true }.to_json).first ||
      user.plans.create!(title: "Explore Bosnia", visibility: :private_plan,
                         preferences: { explore_bosnia: true })
  end

  def explore_bosnia?
    preferences.is_a?(Hash) && preferences["explore_bosnia"] == true
  end

  # Find plans that have locations within given radius (more precise than city-based)
  # This joins through plan_experiences -> experiences -> experience_locations -> locations
  scope :nearby_by_locations, ->(lat, lng, radius_km: 25) {
    return none if lat.blank? || lng.blank?

    # Calculate bounding box for initial filtering (faster than full distance calc)
    lat_delta = radius_km / 111.0 # ~111km per degree latitude
    lng_delta = radius_km / (111.0 * Math.cos(lat.to_f * Math::PI / 180))

    min_lat = lat.to_f - lat_delta
    max_lat = lat.to_f + lat_delta
    min_lng = lng.to_f - lng_delta
    max_lng = lng.to_f + lng_delta

    # Subquery to find location IDs within the bounding box
    nearby_location_ids = Location
      .where("lat BETWEEN ? AND ?", min_lat, max_lat)
      .where("lng BETWEEN ? AND ?", min_lng, max_lng)
      .select(:id)

    # Find plans that have experiences with these locations
    where(
      id: PlanExperience
        .joins(experience: :experience_locations)
        .where(experience_locations: { location_id: nearby_location_ids })
        .select(:plan_id)
    )
  }

  # Search plans by text query (matches title, notes, experience titles, location names)
  scope :search_by_text, ->(query) {
    return all if query.blank?

    sanitized_query = "%#{query.to_s.strip.downcase}%"

    # Find plan IDs that match through experiences or locations
    matching_experience_ids = Experience
      .where("LOWER(title) LIKE ? OR LOWER(description) LIKE ?", sanitized_query, sanitized_query)
      .select(:id)

    matching_location_ids = Location
      .where("LOWER(name) LIKE ? OR LOWER(description) LIKE ?", sanitized_query, sanitized_query)
      .select(:id)

    plan_ids_from_experiences = PlanExperience
      .where(experience_id: matching_experience_ids)
      .select(:plan_id)

    plan_ids_from_locations = PlanExperience
      .joins(experience: :experience_locations)
      .where(experience_locations: { location_id: matching_location_ids })
      .select(:plan_id)

    # Match on plan title/notes OR on experiences/locations
    where("LOWER(title) LIKE ? OR LOWER(notes) LIKE ?", sanitized_query, sanitized_query)
      .or(where(id: plan_ids_from_experiences))
      .or(where(id: plan_ids_from_locations))
  }

  # Filter by duration
  scope :by_duration, ->(duration_filter) {
    case duration_filter.to_s
    when "short"  # 1-2 days
      # Use a subquery approach for plan_experiences day count
      where(id: PlanExperience.select(:plan_id).group(:plan_id).having("MAX(day_number) <= 2"))
        .or(where("start_date IS NOT NULL AND end_date IS NOT NULL AND (end_date - start_date) <= 1"))
    when "medium" # 3-5 days
      where(id: PlanExperience.select(:plan_id).group(:plan_id).having("MAX(day_number) BETWEEN 3 AND 5"))
        .or(where("start_date IS NOT NULL AND end_date IS NOT NULL AND (end_date - start_date) BETWEEN 2 AND 4"))
    when "long"   # 6+ days
      where(id: PlanExperience.select(:plan_id).group(:plan_id).having("MAX(day_number) >= 6"))
        .or(where("start_date IS NOT NULL AND end_date IS NOT NULL AND (end_date - start_date) >= 5"))
    else
      all
    end
  }

  # Resources needing AI regeneration (translations)
  scope :needs_ai_regeneration, -> { where(needs_ai_regeneration: true) }

  # Filter by AI generated / Human made
  scope :ai_generated, -> { where(ai_generated: true) }
  scope :human_made, -> { where(ai_generated: false) }

  # Broj dana u planu
  def duration_in_days
    return calculated_duration_days unless start_date.present? && end_date.present?

    (end_date - start_date).to_i + 1
  end

  # Dohvati experiences za određeni dan (1-indexed)
  def experiences_for_day(day_number)
    plan_experiences.where(day_number: day_number).includes(:experience).map(&:experience)
  end

  # Dohvati plan_experiences za određeni dan
  def plan_experiences_for_day(day_number)
    plan_experiences.where(day_number: day_number).order(position: :asc)
  end

  # Dodaj experience u određeni dan
  def add_experience(experience, day_number:, position: nil)
    validate_day_number!(day_number)

    pos = position || next_position_for_day(day_number)
    plan_experiences.create(experience: experience, day_number: day_number, position: pos)
  end

  # Ukloni experience iz plana
  def remove_experience(experience)
    plan_experiences.find_by(experience: experience)&.destroy
  end

  # Dohvati standalone lokacije za određeni dan
  def locations_for_day(day_number)
    plan_locations.where(day_number: day_number).includes(:location).map(&:location)
  end

  # Deduplicirano: lokacija dostupna iz dva doživljaja je i dalje jedno mjesto.
  def all_locations
    @all_locations ||= begin
      by_id = Location.where(id: all_location_ids).with_card_content.index_by(&:id)
      all_location_ids.filter_map { |id| by_id[id] }
    end
  end

  # A progress badge wants the number, not the places, and the ids answer it
  # without loading a single photo or blob.
  def all_location_count
    all_location_ids.size
  end

  def all_location_ids
    @all_location_ids ||= begin
      by_day = Hash.new { |hash, day| hash[day] = [] }

      plan_experiences.includes(experience: :experience_locations).each do |plan_experience|
        by_day[plan_experience.day_number].concat(plan_experience.experience.experience_locations.map(&:location_id))
      end

      plan_locations.each do |plan_location|
        by_day[plan_location.day_number] << plan_location.location_id
      end

      by_day.keys.sort.flat_map { |day| by_day[day] }.uniq
    end
  end

  # Dodaj standalone lokaciju u određeni dan
  def add_location(location, day_number:, position: nil)
    validate_day_number!(day_number)

    pos = position || next_location_position_for_day(day_number)
    plan_locations.create(location: location, day_number: day_number, position: pos)
  end

  # Ukloni standalone lokaciju iz plana
  def remove_location(location)
    plan_locations.find_by(location: location)&.destroy
  end

  # Premjesti experience na drugi dan
  def move_experience_to_day(experience, new_day_number, position: nil)
    validate_day_number!(new_day_number)

    plan_exp = plan_experiences.find_by(experience: experience)
    return false unless plan_exp

    pos = position || next_position_for_day(new_day_number)
    plan_exp.update(day_number: new_day_number, position: pos)
  end

  # Datum za određeni dan plana (1-indexed)
  def date_for_day(day_number)
    return nil unless start_date.present?
    return nil unless day_number.between?(1, duration_in_days)

    start_date + (day_number - 1).days
  end

  # Dan plana za određeni datum
  def day_number_for_date(date)
    return nil unless start_date.present? && end_date.present?
    return nil unless date.between?(start_date, end_date)

    (date - start_date).to_i + 1
  end

  # Broj experiences po danu
  def experiences_count_by_day
    plan_experiences.group(:day_number).count
  end

  # Ukupno trajanje svih experiences za dan (u minutama)
  def total_duration_for_day(day_number)
    experiences_for_day(day_number).sum { |exp| exp.estimated_duration || 0 }
  end

  # Formatirano trajanje za dan
  def formatted_duration_for_day(day_number)
    total = total_duration_for_day(day_number)
    return nil if total.zero?

    hours = total / 60
    minutes = total % 60

    if hours > 0 && minutes > 0
      "#{hours}h #{minutes}min"
    elsif hours > 0
      "#{hours}h"
    else
      "#{minutes}min"
    end
  end

  # Provjeri je li plan aktivan (danas je unutar perioda)
  def active?
    return false unless start_date.present? && end_date.present?
    Date.current.between?(start_date, end_date)
  end

  # Provjeri je li plan u budućnosti
  def upcoming?
    return false unless start_date.present?
    start_date > Date.current
  end

  # Provjeri je li plan prošao
  def past?
    return false unless end_date.present?
    end_date < Date.current
  end

  # Dani sa svim podacima
  def days_with_experiences
    (1..duration_in_days).map do |day_num|
      {
        day_number: day_num,
        date: date_for_day(day_num),
        experiences: experiences_for_day(day_num),
        locations: locations_for_day(day_num),
        total_duration: total_duration_for_day(day_num)
      }
    end
  end

  # Check if this is a user-owned plan
  def user_plan?
    user_id.present?
  end

  # Get all unique cities from all experiences' locations (for multi-city display)
  def cities
    experiences.includes(:locations).flat_map(&:cities).uniq
  end

  # Returns cover photos for display purposes (for photo gallery)
  # Uses experience cover_photos, with fallback to location photos for experiences without cover
  def display_cover_photos
    experiences.map(&:display_cover_photo).compact
  end

  # Returns a single cover photo for display (e.g., for og:image)
  # Prioritizes experiences with their own cover_photo, then falls back to location photos
  def display_cover_photo
    # First try to find an experience with its own cover_photo
    experience_with_cover = experiences.find { |e| e.cover_photo.attached? }
    return experience_with_cover.cover_photo if experience_with_cover

    # Fall back to display_cover_photo from any experience (which uses location photos)
    experiences.each do |exp|
      photo = exp.display_cover_photo
      return photo if photo
    end

    nil
  end

  # Check if display_cover_photo would return something
  def has_display_cover_photo?
    experiences.any?(&:has_display_cover_photo?)
  end

  # Duration in days for user plans (from actual experiences, then preferences)
  # Prioritizes actual experience data over preferences
  def calculated_duration_days
    return duration_in_days if start_date.present? && end_date.present?

    # First check actual experiences and standalone locations (most accurate)
    max_day_from_items = [
      plan_experiences.maximum(:day_number),
      plan_locations.maximum(:day_number)
    ].compact.max
    return max_day_from_items if max_day_from_items.present?

    # Fall back to preferences if no items yet
    preferences&.dig("duration_days") || 1
  end

  # Export plan to localStorage-compatible format
  def to_local_storage_format
    {
      id: local_id || uuid,
      uuid: uuid,
      generated_at: created_at.iso8601,
      city_name: city_name,
      duration_days: calculated_duration_days,
      preferences: preferences || {},
      custom_title: preferences&.dig("custom_title"),
      notes: notes,
      days: build_days_for_export,
      total_experiences: plan_experiences.count,
      total_locations: plan_locations.count,
      saved: true,
      savedAt: updated_at.iso8601,
      synced: true,
      syncedAt: Time.current.iso8601,
      visibility: visibility,
      is_public: visibility_public_plan?
    }
  end

  # Import plan from localStorage data
  # Returns a hash with :plan and :warnings keys
  def self.create_from_local_storage(data, user:)
    result = { plan: nil, warnings: [] }

    # Get city_name from data (supports both new format and legacy format)
    city_name = data["city_name"] || data.dig("city", "display_name") || data.dig("city", "name")
    unless city_name.present?
      Rails.logger.warn "Plan import: city_name not found in data"
      return result
    end

    duration_days = data["duration_days"] || 1
    preferences = (data["preferences"] || {}).to_h.slice(*DEVICE_PREFERENCE_KEYS)

    # Store custom_title in preferences if provided
    if data["custom_title"].present?
      preferences["custom_title"] = data["custom_title"]
    end

    # Sanitize notes to prevent XSS
    sanitized_notes = data["notes"].present? ? ActionController::Base.helpers.sanitize(data["notes"].to_s.truncate(2000)) : nil

    plan = new(
      user: user,
      city_name: city_name,
      title: generate_auto_title(city_name, duration_days),
      local_id: data["id"],
      visibility: :private_plan,
      preferences: preferences,
      notes: sanitized_notes
    )

    if plan.save
      skipped_count = 0

      # Import experiences for each day
      (data["days"] || []).each do |day_data|
        day_number = day_data["day_number"] || 1
        (day_data["experiences"] || []).each_with_index do |exp_data, position|
          # Look up by UUID first, fall back to ID for backwards compatibility
          experience = Experience.find_by_public_id(exp_data["id"])
          unless experience
            skipped_count += 1
            Rails.logger.warn "Plan import: Experience #{exp_data['id']} not found, skipping"
            next
          end

          plan.plan_experiences.create(
            experience: experience,
            day_number: day_number,
            position: position
          )
        end

        # Import standalone locations added directly to this day
        (day_data["locations"] || []).each_with_index do |loc_data, position|
          location = Location.find_by_public_id(loc_data["id"])
          unless location
            skipped_count += 1
            Rails.logger.warn "Plan import: Location #{loc_data['id']} not found, skipping"
            next
          end

          plan.plan_locations.create(
            location: location,
            day_number: day_number,
            position: position
          )
        end
      end

      if skipped_count > 0
        result[:warnings] << I18n.t("plans.errors.experiences_skipped", count: skipped_count)
      end
    end

    result[:plan] = plan
    result
  end

  # Generate localized auto-title for plan
  def self.generate_auto_title(city_name, duration_days)
    I18n.t("plans.auto_title", city: city_name, days: duration_days)
  end

  # Update existing plan from localStorage data
  # Returns a hash with :success and :warnings keys
  #
  # NOTE: This method replaces ALL existing experiences with those from localStorage.
  # This is intentional because localStorage is the source of truth for client-side editing.
  # Any experiences added directly to the database (bypassing localStorage) will be lost.
  # This design ensures consistency between client and server state.
  def update_from_local_storage(data)
    result = { success: false, warnings: [] }
    skipped_count = 0

    transaction do
      self.preferences = data["preferences"].to_h.slice(*DEVICE_PREFERENCE_KEYS) if data["preferences"].present?

      # Handle custom_title - store in preferences if provided at top level
      if data.key?("custom_title")
        self.preferences ||= {}
        self.preferences["custom_title"] = data["custom_title"]
      end

      # Handle notes - sanitize input to prevent XSS
      if data.key?("notes")
        self.notes = data["notes"].present? ? ActionController::Base.helpers.sanitize(data["notes"].to_s.truncate(2000)) : nil
      end

      # Clear existing experiences and locations, then re-import
      plan_experiences.delete_all
      plan_locations.delete_all

      (data["days"] || []).each do |day_data|
        day_number = day_data["day_number"] || 1
        (day_data["experiences"] || []).each_with_index do |exp_data, position|
          # Look up by UUID first, fall back to ID for backwards compatibility
          experience = Experience.find_by_public_id(exp_data["id"])
          unless experience
            skipped_count += 1
            Rails.logger.warn "Plan update: Experience #{exp_data['id']} not found, skipping"
            next
          end

          plan_experiences.create!(
            experience: experience,
            day_number: day_number,
            position: position
          )
        end

        # Re-import standalone locations added directly to this day
        (day_data["locations"] || []).each_with_index do |loc_data, position|
          location = Location.find_by_public_id(loc_data["id"])
          unless location
            skipped_count += 1
            Rails.logger.warn "Plan update: Location #{loc_data['id']} not found, skipping"
            next
          end

          plan_locations.create!(
            location: location,
            day_number: day_number,
            position: position
          )
        end
      end

      save!
    end

    if skipped_count > 0
      result[:warnings] << I18n.t("plans.errors.experiences_skipped", count: skipped_count)
    end

    result[:success] = true
    result
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error "Failed to update plan from localStorage: #{e.message}"
    errors.add(:base, e.message)
    result
  end

  private

  def rehome_traveller_records
    travellers = User.where(id: traveller_ids)

    # The explore plan is where every other plan's records are re-homed to, so
    # it has nowhere of its own to go. It is unreachable from the plan endpoints;
    # this stops a console or a future caller stranding what it holds.
    if explore_bosnia? && travellers.exists?
      errors.add(:base, I18n.t("plans.errors.explore_plan_holds_records"))
      throw(:abort)
    end

    travellers.find_each do |traveller|
      destination = Plan.explore_bosnia_for(traveller)
      next if destination.id == id

      moments.where(user_id: traveller.id).update_all(plan_id: destination.id)
      rehome_visits_for(traveller, destination)
    end
  end

  def traveller_ids
    (moments.distinct.pluck(:user_id) + plan_visits.distinct.pluck(:user_id)).uniq
  end

  def rehome_visits_for(traveller, destination)
    held = destination.plan_visits.where(user_id: traveller.id).index_by(&:location_id)

    plan_visits.where(user_id: traveller.id).find_each do |visit|
      duplicate = held[visit.location_id]
      # Moving it would collide with the uniqueness index, and the row it
      # duplicates records the same arrival — so only the earlier date survives,
      # and the copy is left for the cascade.
      if duplicate
        duplicate.update_column(:created_at, visit.created_at) if visit.created_at < duplicate.created_at
      else
        visit.update_column(:plan_id, destination.id)
      end
    end
  end

  def build_days_for_export
    max_day = [
      plan_experiences.maximum(:day_number),
      plan_locations.maximum(:day_number)
    ].compact.max || calculated_duration_days

    (1..max_day).map do |day_num|
      day_experiences = plan_experiences_for_day(day_num).includes(experience: :locations)
      day_locations = plan_locations.where(day_number: day_num).order(position: :asc).includes(:location)

      {
        day_number: day_num,
        date: (start_date.present? ? date_for_day(day_num) : Date.today + (day_num - 1).days).iso8601,
        experiences: day_experiences.map do |pe|
          exp = pe.experience
          {
            id: exp.uuid,
            title: exp.title,
            description: exp.description,
            estimated_duration: exp.estimated_duration,
            formatted_duration: exp.formatted_duration,
            locations: exp.locations.map { |loc| location_export_hash(loc) }
          }
        end,
        # Standalone locations added directly to this day (not inside an experience)
        locations: day_locations.map { |pl| location_export_hash(pl.location) }
      }
    end
  end

  # Serialized shape of a Location for the localStorage plan format
  def location_export_hash(loc)
    {
      id: loc.uuid,
      name: loc.name,
      description: loc.description,
      category: loc.category_key,
      budget: loc.budget,
      lat: loc.lat,
      lng: loc.lng,
      city: loc.city
    }
  end

  def end_date_after_start_date
    return unless start_date && end_date

    if end_date < start_date
      errors.add(:end_date, "must be after or equal to start date")
    end
  end

  def validate_day_number!(day_number)
    unless day_number.between?(1, duration_in_days)
      raise ArgumentError, "Day number must be between 1 and #{duration_in_days}"
    end
  end

  def next_position_for_day(day_number)
    (plan_experiences.where(day_number: day_number).maximum(:position) || 0) + 1
  end

  def next_location_position_for_day(day_number)
    (plan_locations.where(day_number: day_number).maximum(:position) || 0) + 1
  end
end
