# frozen_string_literal: true

# ExperienceType represents a type of experience (culture, history, food, etc.)
# Used to tag locations and categorize experiences
#
# Replaces the hardcoded SUPPORTED_EXPERIENCES in Location model
class ExperienceType < ApplicationRecord
  include Identifiable
  include Translatable

  translates :name, :description

  # Associations
  has_many :experience_category_types, dependent: :destroy
  has_many :experience_categories, through: :experience_category_types
  has_many :location_experience_types, dependent: :destroy
  has_many :locations, through: :location_experience_types

  # Validations
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, name: :asc) }

  # Class method to get all active type keys (for validation)
  def self.active_keys
    active.pluck(:key)
  end

  # Class method to get all keys (for backwards compatibility)
  def self.all_keys
    pluck(:key)
  end

  # Find by key (case-insensitive)
  def self.find_by_key(key)
    find_by("LOWER(key) = ?", key.to_s.downcase)
  end
end
