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
    review_flagged
    photo_suggested
    resource_viewed
    resource_created
    resource_updated
    resource_deleted
    login
    approve_photo_suggestion
    reject_photo_suggestion
    suggestion_created
    suggestion_contributed
    approve_suggestion
    reject_suggestion
    approve_review
    remove_review
    update_user
    unblock_user
    approve_curator_application
    reject_curator_application
    approve_content_change
    reject_content_change
    audio_tour_generation_requested
    audio_tour_generated
    audio_tour_generation_failed
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
    when "review_flagged"
      "Flagged a review"
    when "photo_suggested"
      target = recordable_description
      "Suggested photo for #{target}"
    when "suggestion_created"
      target = recordable_description
      "Created suggestion for #{target}"
    when "suggestion_contributed"
      target = recordable_description
      "Contributed to suggestion for #{target}"
    when "approve_suggestion"
      type = metadata["type"]&.gsub("Suggestion", "") || "Resource"
      "Approved #{type}Suggestion"
    when "reject_suggestion"
      type = metadata["type"]&.gsub("Suggestion", "") || "Resource"
      "Rejected #{type}Suggestion"
    when "approve_review"
      "Approved a review"
    when "remove_review"
      "Removed a review"
    when "resource_viewed"
      target = recordable_description
      "Viewed #{target}"
    when "resource_created"
      type = metadata["type"] || "Resource"
      name = metadata["name"] || metadata["title"]
      "Created #{type}: #{name}"
    when "resource_updated"
      target = recordable_description
      "Updated #{target}"
    when "resource_deleted"
      type = metadata["type"] || "Resource"
      name = metadata["name"] || metadata["title"]
      "Deleted #{type}: #{name}"
    when "login"
      "Logged in"
    when "audio_tour_generation_requested"
      target = recordable_description
      "Requested audio tour generation for #{target}"
    when "audio_tour_generated"
      target = recordable_description
      "Generated audio tour for #{target}"
    when "audio_tour_generation_failed"
      target = recordable_description
      "Audio tour generation failed for #{target}"
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
    when "proposal_deleted", "resource_deleted"
      "text-red-500"
    when "resource_created"
      "text-emerald-600"
    when "resource_updated"
      "text-sky-500"
    when "review_added"
      "text-purple-500"
    when "review_flagged"
      "text-orange-500"
    when "photo_suggested"
      "text-green-500"
    when "suggestion_created"
      "text-blue-500"
    when "suggestion_contributed"
      "text-amber-500"
    when "approve_suggestion"
      "text-green-600"
    when "reject_suggestion"
      "text-red-600"
    when "approve_review"
      "text-green-600"
    when "remove_review"
      "text-red-600"
    when "resource_viewed"
      "text-gray-400"
    when "login"
      "text-emerald-500"
    when "audio_tour_generation_requested"
      "text-blue-500"
    when "audio_tour_generated"
      "text-green-600"
    when "audio_tour_generation_failed"
      "text-red-600"
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
    when LocationSuggestion
      "Location suggestion for #{recordable.location&.name || 'new location'}"
    when ExperienceSuggestion
      "Experience suggestion for #{recordable.experience&.title || 'new experience'}"
    when PlanSuggestion
      "Plan suggestion for #{recordable.plan&.title || 'new plan'}"
    else
      recordable.class.name
    end
  end
end
