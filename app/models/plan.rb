class Plan < ApplicationRecord
  include Identifiable
  include Translatable
  include Reviewable
  include Browsable

  # Translatable fields - these can have translations in multiple languages
  translates :title, :notes

  # Visibility enum
  enum :visibility, { private_plan: 0, public_plan: 1 }, prefix: true

  # Returns custom_title if set, otherwise falls back to title
  def display_title
    custom_title = preferences&.dig("custom_title")
    custom_title.present? ? custom_title : title
  end

  # Asocijacije
  belongs_to :user, optional: true
  has_many :plan_experiences, -> { order(day_number: :asc, position: :asc) }, dependent: :destroy
  has_many :experiences, through: :plan_experiences

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
        total_duration: total_duration_for_day(day_num)
      }
    end
  end

  # Check if this is a user-owned plan
  def user_plan?
    user_id.present?
  end

  # Duration in days for user plans (from actual experiences, then preferences)
  # Prioritizes actual experience data over preferences
  def calculated_duration_days
    return duration_in_days if start_date.present? && end_date.present?

    # First check actual experiences (most accurate)
    max_day_from_experiences = plan_experiences.maximum(:day_number)
    return max_day_from_experiences if max_day_from_experiences.present?

    # Fall back to preferences if no experiences yet
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
    preferences = (data["preferences"] || {}).dup

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
      self.preferences = data["preferences"] if data["preferences"].present?

      # Handle custom_title - store in preferences if provided at top level
      if data.key?("custom_title")
        self.preferences ||= {}
        self.preferences["custom_title"] = data["custom_title"]
      end

      # Handle notes - sanitize input to prevent XSS
      if data.key?("notes")
        self.notes = data["notes"].present? ? ActionController::Base.helpers.sanitize(data["notes"].to_s.truncate(2000)) : nil
      end

      # Clear existing experiences and re-import
      plan_experiences.delete_all

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

  def build_days_for_export
    max_day = plan_experiences.maximum(:day_number) || calculated_duration_days

    (1..max_day).map do |day_num|
      day_experiences = plan_experiences_for_day(day_num).includes(experience: :locations)

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
            locations: exp.locations.map do |loc|
              {
                id: loc.uuid,
                name: loc.name,
                description: loc.description,
                location_type: loc.location_type,
                budget: loc.budget,
                lat: loc.lat,
                lng: loc.lng
              }
            end
          }
        end
      }
    end
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
end
