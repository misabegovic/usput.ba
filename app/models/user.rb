class User < ApplicationRecord
  include Identifiable

  has_secure_password
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 100, 100 ]
    attachable.variant :medium, resize_to_limit: [ 256, 256 ]
  end
  has_many :curator_applications, dependent: :destroy
  has_many :plans, dependent: :nullify
  has_many :content_changes, dependent: :destroy
  has_many :content_change_contributions, dependent: :destroy
  has_many :curator_reviews, dependent: :destroy
  has_many :curator_activities, dependent: :destroy
  has_many :photo_suggestions, dependent: :destroy
  has_many :moments, dependent: :destroy
  has_many :plan_visits, dependent: :destroy

  # The profile blob is written straight from whatever the device sends, so each
  # list it holds is bounded rather than left to grow a row without limit.
  MAX_PROFILE_ENTRIES = 200
  MAX_RECENTLY_VIEWED = 20

  # Spam protection constants
  MAX_ACTIVITIES_PER_HOUR = 50
  MAX_ACTIVITIES_PER_DAY = 200
  SPAM_BLOCK_DURATION = 24.hours

  validate :acceptable_avatar, if: -> { avatar.attached? }

  # User types: basic (default), curator (can manage resources), admin (full access)
  enum :user_type, {
    basic: 0,
    curator: 1,
    admin: 2
  }, default: :basic

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 3, maximum: 30 },
                       format: { with: /\A[a-zA-Z0-9_]+\z/, message: "can only contain letters, numbers, and underscores" }

  validates :password, length: { minimum: 6 }, on: :create

  # Normalize username to lowercase
  before_save { self.username = username.downcase }

  # Permission helpers
  def can_curate?
    curator? || admin?
  end

  def pending_curator_application?
    curator_applications.pending.exists?
  end

  def can_apply_for_curator?
    basic? && !pending_curator_application?
  end

  # Spam protection methods
  def spam_blocked?
    return false unless spam_blocked_until.present?

    if spam_blocked_until > Time.current
      true
    else
      # Auto-unblock if block has expired
      clear_spam_block!
      false
    end
  end

  def check_spam_activity!
    return unless curator?

    reset_activity_count_if_needed!

    hourly_count = curator_activities.this_hour.count
    daily_count = activity_count_today

    if hourly_count >= MAX_ACTIVITIES_PER_HOUR
      block_for_spam!("Exceeded #{MAX_ACTIVITIES_PER_HOUR} actions per hour")
    elsif daily_count >= MAX_ACTIVITIES_PER_DAY
      block_for_spam!("Exceeded #{MAX_ACTIVITIES_PER_DAY} actions per day")
    end
  end

  def increment_activity_count!
    reset_activity_count_if_needed!
    increment!(:activity_count_today)
  end

  def block_for_spam!(reason)
    update!(
      spam_blocked_at: Time.current,
      spam_blocked_until: SPAM_BLOCK_DURATION.from_now,
      spam_block_reason: reason
    )
  end

  def clear_spam_block!
    update!(
      spam_blocked_at: nil,
      spam_blocked_until: nil,
      spam_block_reason: nil
    )
  end

  def admin_unblock!
    clear_spam_block!
    update!(activity_count_today: 0)
  end

  # Default travel profile structure. `visited` and `stats` are always projected
  # from PlanVisit — the browser holds a copy, never the truth, because a native
  # app and a second device have to see the same visits. Both come off one load
  # of the rows, and neither is memoized: `reload` does not clear a custom ivar,
  # so a cached projection would outlive the check-in that invalidated it.
  def travel_profile_data
    visits = visits_for_profile
    (super.presence || default_travel_profile).merge(
      "visited" => visited_profile_entries(visits),
      "stats" => visit_stats(visits)
    )
  end

  def visited_profile_entries(visits = visits_for_profile)
    visits.uniq(&:location_id).map do |visit|
      {
        "id" => visit.location.uuid,
        "type" => "location",
        "name" => visit.location.name,
        "visitedAt" => visit.created_at.iso8601,
        "city" => visit.location.city,
        "tags" => visit.location.tags
      }
    end
  end

  # Cities and seasons come off every visit rather than the deduplicated list:
  # returning to one place in a later season must not retire the season the
  # first walk there earned.
  def visit_stats(visits = visits_for_profile)
    {
      "totalVisits" => visits.uniq(&:location_id).size,
      "citiesVisited" => visits.filter_map { |visit| visit.location.city.presence }.uniq,
      "seasonsVisited" => visits.map { |visit| Location.season_for(visit.created_at) }.uniq
    }
  end

  # Merge incoming profile data with existing. `visited` and `stats` are not
  # merged — both are derived from PlanVisit, so whatever the client sends is
  # discarded. For badges, savedPlans, and recentlyViewed, we merge to avoid
  # losing data.
  def merge_travel_profile(incoming_data)
    return if incoming_data.blank?

    current_data = travel_profile_data
    merged = {
      "createdAt" => [ current_data["createdAt"], incoming_data["createdAt"] ].compact.min,
      "updatedAt" => Time.current.iso8601,
      "favorites" => merge_favorites(current_data, incoming_data).first(MAX_PROFILE_ENTRIES),
      "recentlyViewed" => (current_data["recentlyViewed"].to_a + incoming_data["recentlyViewed"].to_a)
                           .uniq { |item| item["id"] }
                           .sort_by { |item| item["viewedAt"] || "" }
                           .reverse
                           .first(MAX_RECENTLY_VIEWED),
      "badges" => merge_arrays_by_id(current_data["badges"], incoming_data["badges"]).first(MAX_PROFILE_ENTRIES),
      "savedPlans" => merge_arrays_by_id(current_data["savedPlans"], incoming_data["savedPlans"]).first(MAX_PROFILE_ENTRIES)
    }

    update!(travel_profile_data: merged)
  end

  private

  def visits_for_profile
    plan_visits.includes(:location).order(created_at: :desc).to_a
  end

  # Favourites have no server-side source to recompute from, so the device stays
  # their owner — but a device holding no profile yet sends an empty list, and an
  # empty array is truthy in Ruby. Nothing said is not the same as delete these.
  def merge_favorites(current_data, incoming_data)
    incoming = incoming_data["favorites"]
    current = current_data["favorites"].to_a
    return current if incoming.blank?
    return incoming if current.empty?

    client_copy_newer?(current_data, incoming_data) ? incoming : current
  end

  def client_copy_newer?(current_data, incoming_data)
    incoming_at = parsed_profile_time(incoming_data["updatedAt"])
    return true if incoming_at.nil?

    current_at = parsed_profile_time(current_data["updatedAt"])
    current_at.nil? || incoming_at >= current_at
  end

  # The two sides stamp in different formats — Rails writes a zoned iso8601, the
  # browser writes UTC with milliseconds — so the strings cannot be compared.
  def parsed_profile_time(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def reset_activity_count_if_needed!
    if activity_count_reset_at.nil? || activity_count_reset_at < Time.current.beginning_of_day
      update!(
        activity_count_today: 0,
        activity_count_reset_at: Time.current
      )
    end
  end

  def default_travel_profile
    {
      "createdAt" => Time.current.iso8601,
      "updatedAt" => Time.current.iso8601,
      "visited" => [],
      "favorites" => [],
      "recentlyViewed" => [],
      "badges" => [],
      "savedPlans" => [],
      "stats" => {
        "totalVisits" => 0,
        "citiesVisited" => [],
        "seasonsVisited" => []
      }
    }
  end

  def merge_arrays_by_id(arr1, arr2)
    combined = (arr1.to_a + arr2.to_a)
    combined.group_by { |item| item["id"] }.map { |_id, items| items.last }
  end

  def acceptable_avatar
    acceptable_types = [ "image/jpeg", "image/png", "image/webp", "image/gif" ]
    unless acceptable_types.include?(avatar.content_type)
      errors.add(:avatar, "must be JPEG, PNG, WebP or GIF")
    end

    if avatar.byte_size > 5.megabytes
      errors.add(:avatar, "must be less than 5MB")
    end
  end
end
