# frozen_string_literal: true

# LocationSuggestion - Per-resource suggestion model for locations
#
# Replaces ContentChange for location-specific suggestions with typed columns
# and Active Storage support. Supports multi-curator contributions through
# LocationSuggestionContribution model.
#
# One pending suggestion per location enforced by unique constraint.
# Multiple curators can contribute to the same suggestion.
#
# Usage:
#   # Create or find pending suggestion
#   suggestion = LocationSuggestion.find_or_create_pending!(
#     location,
#     user: current_user,
#     origin: :human,
#     change_type: :update_resource
#   )
#
#   # Update with proposed changes
#   suggestion.update!(
#     proposed_name: "Stari Most",
#     proposed_city: "Mostar",
#     proposed_description: "...",
#     proposed_lat: 43.337,
#     proposed_lng: 17.815
#   )
#
#   # Add photos
#   suggestion.proposed_photos.attach(params[:photos])
#
#   # Approve (applies changes to location)
#   suggestion.approve!(admin_user)
#
class LocationSuggestion < ApplicationRecord
  include Suggestable

  belongs_to :location, optional: true  # nil for create_resource
  has_many :contributions, class_name: "LocationSuggestionContribution", dependent: :destroy
  has_many_attached :proposed_photos

  validate :acceptable_photos

  # Returns the resource association column name for Suggestable concern
  def self.resource_association_column
    :location_id
  end

  # Apply proposed changes to the location
  # Creates new location for create_resource, updates for update_resource, deletes for delete_resource
  def apply_changes!
    case change_type
    when "create_resource"
      attrs = proposed_attributes
      result = LocationCreator.new(attrs).call
      raise ActiveRecord::RecordInvalid.new(result.location) unless result.success?
      update!(location: result.location)
    when "update_resource"
      attrs = proposed_attributes
      result = LocationUpdater.new(location, attrs).call
      raise ActiveRecord::Rollback unless result.success?
      # Attach photos if any
      attach_proposed_photos_to_location! if proposed_photos.attached?
    when "delete_resource"
      location.destroy!
    end
  end

  private

  # Build hash of proposed attributes from typed columns
  def proposed_attributes
    attrs = {}
    attrs[:name] = proposed_name if proposed_name.present?
    attrs[:city] = proposed_city if proposed_city.present?
    attrs[:description] = proposed_description if proposed_description.present?
    attrs[:historical_context] = proposed_historical_context if proposed_historical_context.present?
    attrs[:lat] = proposed_lat if proposed_lat.present?
    attrs[:lng] = proposed_lng if proposed_lng.present?
    attrs[:budget] = proposed_budget if proposed_budget.present?
    attrs[:phone] = proposed_phone if proposed_phone.present?
    attrs[:email] = proposed_email if proposed_email.present?
    attrs[:website] = proposed_website if proposed_website.present?
    attrs[:video_url] = proposed_video_urls&.first if proposed_video_urls.present? # backwards compat
    attrs[:tags] = proposed_tags if proposed_tags.present?
    attrs[:social_links] = proposed_social_links if proposed_social_links.present?
    attrs[:suitable_experiences] = proposed_experience_type_ids if proposed_experience_type_ids.present?
    attrs
  end

  # Attach proposed photos to the location
  def attach_proposed_photos_to_location!
    proposed_photos.each do |photo|
      location.photos.attach(photo.blob)
    end
  end

  # Validate photo attachments
  def acceptable_photos
    return unless proposed_photos.attached?

    proposed_photos.each do |photo|
      errors.add(:proposed_photos, "max 10MB per photo") if photo.blob.byte_size > 10.megabytes
      unless %w[image/jpeg image/png image/gif image/webp].include?(photo.blob.content_type)
        errors.add(:proposed_photos, "must be JPEG, PNG, GIF, or WebP")
      end
    end
    errors.add(:proposed_photos, "max 10 photos") if proposed_photos.size > 10
  end
end
