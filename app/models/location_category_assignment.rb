# frozen_string_literal: true

# Join model for many-to-many relationship between Location and LocationCategory
# Allows a location to belong to multiple categories (e.g., museum can be both
# "Museum & Gallery" and "Historical Site")
class LocationCategoryAssignment < ApplicationRecord
  belongs_to :location
  belongs_to :location_category

  # Validations
  validates :location_id, uniqueness: { scope: :location_category_id }

  # Scopes
  scope :primary, -> { where(primary: true) }

  # Callback to ensure only one primary category per location
  before_save :ensure_single_primary, if: :primary?

  private

  def ensure_single_primary
    return unless primary? && primary_changed?

    # Unmark any existing primary category for this location
    LocationCategoryAssignment
      .where(location_id: location_id, primary: true)
      .where.not(id: id)
      .update_all(primary: false)
  end
end
