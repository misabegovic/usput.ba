# frozen_string_literal: true

# Join model between ExperienceCategory and ExperienceType
# Allows categories to have multiple experience types with ordering
class ExperienceCategoryType < ApplicationRecord
  belongs_to :experience_category
  belongs_to :experience_type

  validates :experience_category_id, uniqueness: { scope: :experience_type_id }

  default_scope { order(position: :asc) }
end
