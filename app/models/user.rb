class User < ApplicationRecord
  include Identifiable

  has_secure_password
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 100, 100 ]
    attachable.variant :medium, resize_to_limit: [ 256, 256 ]
  end
  has_many :curator_applications, dependent: :destroy
  has_many :plans, dependent: :nullify

  validate :acceptable_avatar, if: -> { avatar.attached? }

  # User types: basic (default), curator (can manage resources)
  enum :user_type, {
    basic: 0,
    curator: 1
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
    curator?
  end

  def pending_curator_application?
    curator_applications.pending.exists?
  end

  def can_apply_for_curator?
    basic? && !pending_curator_application?
  end

  # Default travel profile structure
  def travel_profile_data
    super.presence || default_travel_profile
  end

  # Merge incoming profile data with existing
  # For favorites and visited, client is authoritative (to support removals)
  # For badges, savedPlans, and recentlyViewed, we merge to avoid losing data
  def merge_travel_profile(incoming_data)
    return if incoming_data.blank?

    current_data = travel_profile_data
    merged = {
      "createdAt" => [ current_data["createdAt"], incoming_data["createdAt"] ].compact.min,
      "updatedAt" => Time.current.iso8601,
      # Client is authoritative for favorites and visited (supports removals)
      "visited" => incoming_data["visited"] || current_data["visited"] || [],
      "favorites" => incoming_data["favorites"] || current_data["favorites"] || [],
      "recentlyViewed" => (current_data["recentlyViewed"].to_a + incoming_data["recentlyViewed"].to_a)
                           .uniq { |item| item["id"] }
                           .sort_by { |item| item["viewedAt"] || "" }
                           .reverse
                           .first(20),
      "badges" => merge_arrays_by_id(current_data["badges"], incoming_data["badges"]),
      "savedPlans" => merge_arrays_by_id(current_data["savedPlans"], incoming_data["savedPlans"]),
      "stats" => incoming_data["stats"] || current_data["stats"] || {}
    }

    update!(travel_profile_data: merged)
  end

  private

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

  def merge_stats(stats1, stats2)
    stats1 ||= {}
    stats2 ||= {}

    {
      "totalVisits" => [ stats1["totalVisits"].to_i, stats2["totalVisits"].to_i ].max,
      "citiesVisited" => ((stats1["citiesVisited"] || []) + (stats2["citiesVisited"] || [])).uniq,
      "seasonsVisited" => ((stats1["seasonsVisited"] || []) + (stats2["seasonsVisited"] || [])).uniq
    }
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
