# frozen_string_literal: true

# ExperienceSuggestion - Per-resource suggestion model for experiences
#
# Replaces ContentChange for experience-specific suggestions with typed columns
# and Active Storage support. Supports multi-curator contributions through
# ExperienceSuggestionContribution model.
#
# One pending suggestion per experience enforced by unique constraint.
# Multiple curators can contribute to the same suggestion.
#
# Usage:
#   # Create or find pending suggestion
#   suggestion = ExperienceSuggestion.find_or_create_pending!(
#     experience,
#     user: current_user,
#     origin: :human,
#     change_type: :update_resource
#   )
#
#   # Update with proposed changes
#   suggestion.update!(
#     proposed_title: "Rafting na Uni",
#     proposed_description: "...",
#     proposed_estimated_duration: 180,
#     proposed_location_uuids: ["uuid1", "uuid2"]
#   )
#
#   # Add cover photo
#   suggestion.proposed_cover_photo.attach(params[:cover_photo])
#
#   # Approve (applies changes to experience)
#   suggestion.approve!(admin_user)
#
class ExperienceSuggestion < ApplicationRecord
  include Suggestable

  belongs_to :experience, optional: true  # nil for create_resource
  has_many :contributions, class_name: "ExperienceSuggestionContribution", dependent: :destroy
  has_one_attached :proposed_cover_photo

  validate :acceptable_cover_photo

  # Returns the resource association column name for Suggestable concern
  def self.resource_association_column
    :experience_id
  end

  # Apply proposed changes to the experience
  # Creates new experience for create_resource, updates for update_resource, deletes for delete_resource
  def apply_changes!
    case change_type
    when "create_resource"
      attrs = proposed_attributes
      new_experience = Experience.create!(attrs)
      update_experience_locations!(new_experience) if proposed_location_uuids.present?
      attach_cover_photo!(new_experience) if proposed_cover_photo.attached?
      update!(experience: new_experience)
    when "update_resource"
      attrs = proposed_attributes
      experience.update!(attrs)
      update_experience_locations!(experience) if proposed_location_uuids.present?
      attach_cover_photo!(experience) if proposed_cover_photo.attached?
    when "delete_resource"
      experience.destroy!
    end
  end

  private

  # Build hash of proposed attributes from typed columns
  def proposed_attributes
    attrs = {}
    attrs[:title] = proposed_title if proposed_title.present?
    attrs[:description] = proposed_description if proposed_description.present?
    attrs[:experience_category_id] = proposed_experience_category_id if proposed_experience_category_id.present?
    attrs[:estimated_duration] = proposed_estimated_duration if proposed_estimated_duration.present?
    attrs[:contact_name] = proposed_contact_name if proposed_contact_name.present?
    attrs[:contact_email] = proposed_contact_email if proposed_contact_email.present?
    attrs[:contact_phone] = proposed_contact_phone if proposed_contact_phone.present?
    attrs[:contact_website] = proposed_contact_website if proposed_contact_website.present?
    attrs[:seasons] = proposed_seasons if proposed_seasons.present?
    attrs
  end

  # Update experience locations from proposed UUIDs
  def update_experience_locations!(exp)
    exp.location_uuids = proposed_location_uuids
  end

  # Attach proposed cover photo to the experience
  def attach_cover_photo!(exp)
    exp.cover_photo.attach(proposed_cover_photo.blob)
  end

  # Validate cover photo attachment
  def acceptable_cover_photo
    return unless proposed_cover_photo.attached?

    photo = proposed_cover_photo
    errors.add(:proposed_cover_photo, "max 10MB") if photo.blob.byte_size > 10.megabytes
    unless %w[image/jpeg image/png image/gif image/webp].include?(photo.blob.content_type)
      errors.add(:proposed_cover_photo, "must be JPEG, PNG, GIF, or WebP")
    end
  end
end
