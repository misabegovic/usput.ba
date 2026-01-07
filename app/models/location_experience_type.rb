# frozen_string_literal: true

# Join model between Location and ExperienceType
# Replaces the JSON suitable_experiences field on Location
class LocationExperienceType < ApplicationRecord
  belongs_to :location
  belongs_to :experience_type

  validates :location_id, uniqueness: { scope: :experience_type_id }
end
