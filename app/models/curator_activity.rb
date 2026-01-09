# frozen_string_literal: true

# Records all curator actions for audit trail and activity feeds.
# Uses the Recordable pattern to track changes to any model.
class CuratorActivity < ApplicationRecord
  belongs_to :user
  belongs_to :recordable, polymorphic: true, optional: true

  # Action types
  ACTIONS = %w[
    proposal_created
    proposal_updated
    proposal_contributed
    proposal_deleted
    review_added
    photo_suggested
    resource_viewed
    login
  ].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :today, -> { where("created_at >= ?", Time.current.beginning_of_day) }
  scope :this_hour, -> { where("created_at >= ?", 1.hour.ago) }

  # Create an activity record for a curator action
  def self.record(user:, action:, recordable: nil, metadata: {}, request: nil)
    return unless user&.curator? || user&.admin?

    create!(
      user: user,
      action: action,
      recordable: recordable,
      metadata: metadata,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent&.truncate(500)
    )
  rescue StandardError => e
    Rails.logger.error "Failed to record curator activity: #{e.message}"
    nil
  end

  # Human-readable description of the activity
  def description
    case action
    when "proposal_created"
      target = recordable_description
      "Created a proposal for #{target}"
    when "proposal_updated"
      target = recordable_description
      "Updated proposal for #{target}"
    when "proposal_contributed"
      target = recordable_description
      "Contributed to proposal for #{target}"
    when "proposal_deleted"
      "Submitted deletion request"
    when "review_added"
      "Added review to a proposal"
    when "photo_suggested"
      target = recordable_description
      "Suggested photo for #{target}"
    when "resource_viewed"
      target = recordable_description
      "Viewed #{target}"
    when "login"
      "Logged in"
    else
      action.humanize
    end
  end

  # Icon for the activity type
  def icon_class
    case action
    when "proposal_created"
      "text-blue-500"
    when "proposal_updated", "proposal_contributed"
      "text-amber-500"
    when "proposal_deleted"
      "text-red-500"
    when "review_added"
      "text-purple-500"
    when "photo_suggested"
      "text-green-500"
    when "resource_viewed"
      "text-gray-400"
    when "login"
      "text-emerald-500"
    else
      "text-gray-500"
    end
  end

  private

  def recordable_description
    return metadata["description"] if metadata["description"].present?
    return "unknown" unless recordable

    case recordable
    when Location
      "Location: #{recordable.name}"
    when Experience
      "Experience: #{recordable.title}"
    when Plan
      "Plan: #{recordable.title}"
    when AudioTour
      "Audio Tour: #{recordable.location&.name} (#{recordable.locale})"
    when ContentChange
      recordable.description
    when PhotoSuggestion
      "Photo for #{recordable.location&.name}"
    else
      recordable.class.name
    end
  end
end
