# frozen_string_literal: true

# Stores proposed content changes from curators that require admin approval.
# This implements an approval workflow where curators can propose:
# - Creating new content (locations, experiences, plans, audio tours)
# - Updating existing content
# - Deleting content
#
# Only ONE pending proposal can exist per resource. Multiple curators can
# contribute to the same proposal through ContentChangeContribution.
# Admins review and approve or reject these proposals.
class ContentChange < ApplicationRecord
  belongs_to :changeable, polymorphic: true, optional: true
  belongs_to :user # Original proposer
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :contributions, class_name: "ContentChangeContribution", dependent: :destroy
  has_many :contributors, through: :contributions, source: :user
  has_many :curator_reviews, dependent: :destroy

  enum :change_type, { create_content: 0, update_content: 1, delete_content: 2 }
  enum :status, { pending: 0, approved: 1, rejected: 2 }

  # Supported content types
  CHANGEABLE_CLASSES = %w[Location Experience Plan AudioTour Review].freeze

  validates :change_type, presence: true
  validates :status, presence: true
  validates :changeable_class, inclusion: { in: CHANGEABLE_CLASSES }, if: :create_content?
  validates :changeable, presence: true, unless: :create_content?
  validates :proposed_data, presence: true, unless: :delete_content?

  # Sanitize proposed data
  before_save :sanitize_proposed_data

  scope :for_user, ->(user) { where(user: user) }
  scope :pending_review, -> { pending.order(created_at: :asc) }
  scope :recently_reviewed, -> { where.not(status: :pending).order(reviewed_at: :desc) }

  # Find existing pending proposal for a resource, or create a new one
  # Ensures only one pending proposal exists per resource
  def self.find_or_create_for_update(changeable:, user:, original_data:, proposed_data:)
    # Look for existing pending proposal for this resource
    existing = pending.find_by(changeable: changeable)

    if existing
      # Add contribution to existing proposal
      existing.add_contribution(user: user, proposed_data: proposed_data)
      existing
    else
      # Create new proposal
      create!(
        user: user,
        change_type: :update_content,
        changeable: changeable,
        original_data: original_data,
        proposed_data: proposed_data
      )
    end
  end

  def self.find_or_create_for_delete(changeable:, user:, original_data:)
    # Look for existing pending proposal for this resource
    existing = pending.find_by(changeable: changeable)

    if existing
      # If there's already a pending update, convert it to delete
      if existing.update_content?
        existing.update!(change_type: :delete_content, original_data: original_data, proposed_data: {})
      end
      existing.add_contribution(user: user, proposed_data: {}, notes: "Requested deletion")
      existing
    else
      create!(
        user: user,
        change_type: :delete_content,
        changeable: changeable,
        original_data: original_data
      )
    end
  end

  # Add a contribution from a curator
  def add_contribution(user:, proposed_data:, notes: nil)
    contribution = contributions.find_or_initialize_by(user: user)
    contribution.proposed_data = proposed_data
    contribution.notes = notes
    contribution.save!

    # Merge the contribution into main proposed_data
    merge_contributions!
    contribution
  end

  # Merge all contributions into the main proposed_data
  def merge_contributions!
    return if contributions.empty?

    merged = original_data.dup || {}
    contributions.order(:created_at).each do |contrib|
      merged.merge!(contrib.proposed_data.compact_blank)
    end
    update!(proposed_data: merged)
  end

  # Approve the proposal and apply the changes
  def approve!(admin, notes: nil)
    return false unless pending?

    transaction do
      case change_type.to_sym
      when :create_content
        apply_create!
      when :update_content
        apply_update!
      when :delete_content
        apply_delete!
      end

      update!(
        status: :approved,
        reviewed_by: admin,
        reviewed_at: Time.current,
        admin_notes: notes
      )
    end

    true
  rescue StandardError => e
    Rails.logger.error "Failed to approve content change #{id}: #{e.message}"
    false
  end

  # Reject the proposal
  def reject!(admin, notes:)
    return false unless pending?

    update!(
      status: :rejected,
      reviewed_by: admin,
      reviewed_at: Time.current,
      admin_notes: notes
    )
  end

  # Human-readable description of the change
  def description
    target = changeable&.respond_to?(:name) ? changeable.name : (changeable&.respond_to?(:title) ? changeable.title : changeable_class)

    case change_type.to_sym
    when :create_content
      "Create new #{changeable_class}: #{proposed_data['name'] || proposed_data['title']}"
    when :update_content
      "Update #{changeable_type}: #{target}"
    when :delete_content
      "Delete #{changeable_type}: #{target}"
    end
  end

  # Get a diff of changes for display
  def changes_diff
    return {} unless update_content?
    return {} if original_data.blank? || proposed_data.blank?

    diff = {}
    proposed_data.each do |key, new_value|
      old_value = original_data[key]
      if old_value != new_value
        diff[key] = { from: old_value, to: new_value }
      end
    end
    diff
  end

  # Count of curator recommendations
  def recommendation_summary
    {
      approve: curator_reviews.recommend_approve.count,
      reject: curator_reviews.recommend_reject.count,
      neutral: curator_reviews.neutral.count
    }
  end

  # All users involved (proposer + contributors)
  def all_contributors
    ([user] + contributors).uniq
  end

  private

  def sanitize_proposed_data
    return if proposed_data.blank?

    self.proposed_data = proposed_data.transform_values do |value|
      case value
      when String
        ActionController::Base.helpers.sanitize(value, tags: %w[b i em strong br p], attributes: [])
      when Array
        value.map { |v| v.is_a?(String) ? ActionController::Base.helpers.sanitize(v, tags: [], attributes: []) : v }
      else
        value
      end
    end
  end

  def apply_create!
    klass = changeable_class.constantize
    # Filter to only allowed attributes - prevent mass assignment
    allowed_attrs = safe_attributes_for(klass)
    safe_data = proposed_data.slice(*allowed_attrs)

    # Curator-created content is human-made, not AI-generated
    safe_data["ai_generated"] = false if klass.column_names.include?("ai_generated")

    record = klass.new(safe_data)
    record.save!
    update!(changeable: record)

    # Mark as needing AI regeneration for translations/audio
    mark_for_ai_regeneration!(record)
  end

  def apply_update!
    # Filter to only allowed attributes - prevent mass assignment
    allowed_attrs = safe_attributes_for(changeable.class)
    safe_data = proposed_data.slice(*allowed_attrs)
    changeable.update!(safe_data)

    # Mark as needing AI regeneration for translations/audio
    mark_for_ai_regeneration!(changeable)
  end

  def apply_delete!
    changeable.destroy!
  end

  # Mark resource for AI regeneration (translations, audio tours)
  # Only applies to Location, Experience, and Plan models
  def mark_for_ai_regeneration!(resource)
    return unless resource.respond_to?(:needs_ai_regeneration=)
    return unless %w[Location Experience Plan].include?(resource.class.name)

    resource.update_column(:needs_ai_regeneration, true)
  end

  # Define safe attributes for each model to prevent unauthorized changes
  def safe_attributes_for(klass)
    case klass.name
    when "Location"
      %w[name description historical_context city lat lng location_type budget phone email website video_url tags suitable_experiences social_links]
    when "Experience"
      %w[title description experience_category_id estimated_duration contact_name contact_email contact_phone contact_website seasons]
    when "Plan"
      %w[title notes city_name visibility start_date end_date user_id]
    when "AudioTour"
      %w[location_id locale script word_count duration]
    when "Review"
      %w[rating comment]
    else
      []
    end
  end
end
