# frozen_string_literal: true

# Suggestable concern for suggestion models (LocationSuggestion, ExperienceSuggestion, etc.)
#
# Provides common functionality for content suggestions:
# - Status tracking (pending/approved/rejected)
# - Change types (create/update/delete)
# - Origin tracking (human vs AI-generated)
# - Approve/reject workflows
# - Multi-contributor support
#
# Usage:
#   class LocationSuggestion < ApplicationRecord
#     include Suggestable
#
#     belongs_to :location, optional: true
#     has_many :contributions, class_name: "LocationSuggestionContribution"
#
#     def apply_changes!
#       # Implement resource-specific logic
#     end
#   end
#
module Suggestable
  extend ActiveSupport::Concern

  included do
    belongs_to :user
    belongs_to :reviewed_by, class_name: "User", optional: true

    enum :status, { pending: 0, approved: 1, rejected: 2 }
    enum :change_type, { create_resource: 0, update_resource: 1, delete_resource: 2 }
    enum :origin, { human: 0, ai_generated: 1 }, prefix: :origin

    validates :user, presence: true

    scope :pending_review, -> { where(status: :pending) }
    scope :recent, -> { order(created_at: :desc) }
    scope :human_suggestions, -> { where(origin: :human) }
    scope :ai_suggestions, -> { where(origin: :ai_generated) }
  end

  # Approve the suggestion and apply changes to the resource
  # @param admin [User] The admin approving the suggestion
  # @param notes [String, nil] Optional admin notes
  def approve!(admin, notes: nil)
    transaction do
      apply_changes!
      update!(
        status: :approved,
        reviewed_by: admin,
        reviewed_at: Time.current,
        admin_notes: notes
      )
    end
  end

  # Reject the suggestion without applying changes
  # @param admin [User] The admin rejecting the suggestion
  # @param notes [String, nil] Optional admin notes explaining rejection
  def reject!(admin, notes: nil)
    update!(
      status: :rejected,
      reviewed_by: admin,
      reviewed_at: Time.current,
      admin_notes: notes
    )
  end

  # Add contribution from another curator to this suggestion
  # Updates the suggestion fields with non-nil values and creates a contribution record
  # @param user [User] The user contributing
  # @param notes [String, nil] Optional notes about the contribution
  # @param proposed_fields [Hash] The fields being proposed (non-nil values only)
  def add_contribution(user:, notes: nil, **proposed_fields)
    non_nil_fields = proposed_fields.compact

    transaction do
      # Save contribution for audit trail
      contribution = contributions.create!(
        user: user,
        notes: notes,
        **non_nil_fields
      )

      # Update suggestion with new values
      non_nil_fields.each do |field, value|
        self[field] = value if respond_to?("#{field}=")
      end
      save!
    end
  end

  # Apply the proposed changes to the resource
  # Must be implemented by including model
  def apply_changes!
    raise NotImplementedError, "#{self.class.name} must implement #apply_changes!"
  end

  # Get all proposed changes (non-nil proposed_* fields)
  # @return [Hash] Hash of proposed field names and values
  def proposed_changes
    attributes.select { |k, v| k.start_with?("proposed_") && v.present? }
  end

  module ClassMethods
    # Find existing pending suggestion or create new one for this resource
    # @param resource [ActiveRecord::Base, nil] The resource being suggested (nil for create_resource)
    # @param user [User] The user creating the suggestion
    # @param attrs [Hash] Additional attributes for the suggestion
    # @return [Suggestable] The found or created suggestion
    def find_or_create_pending!(resource, user:, **attrs)
      resource_column = resource_association_column
      existing = pending.find_by(resource_column => resource&.id)

      if existing
        existing
      else
        create!(
          resource_column => resource&.id,
          user: user,
          status: :pending,
          **attrs
        )
      end
    end

    # Returns the resource association column name (e.g., :location_id)
    # Must be implemented by including model
    def resource_association_column
      raise NotImplementedError, "#{name} must implement .resource_association_column"
    end
  end
end
