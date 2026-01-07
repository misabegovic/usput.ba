# frozen_string_literal: true

# ExperienceCategory represents a category of curated experiences
# Examples: Cultural Heritage, Culinary Journey, Nature Adventure
#
# Replaces the hardcoded EXPERIENCE_CATEGORIES in AI::ExperienceGenerator
class ExperienceCategory < ApplicationRecord
  include Identifiable
  include Translatable

  translates :name, :description

  # Associations
  has_many :experience_category_types, -> { order(position: :asc) }, dependent: :destroy
  has_many :experience_types, through: :experience_category_types
  has_many :experiences, dependent: :nullify

  # Validations
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :default_duration, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, name: :asc) }

  # Get experience type keys for this category
  def experience_type_keys
    experience_types.pluck(:key)
  end

  # Add an experience type to this category
  def add_experience_type(experience_type, position: nil)
    pos = position || (experience_category_types.maximum(:position) || 0) + 1
    experience_category_types.find_or_create_by(experience_type: experience_type) do |ect|
      ect.position = pos
    end
  end

  # Remove an experience type from this category
  def remove_experience_type(experience_type)
    experience_category_types.find_by(experience_type: experience_type)&.destroy
  end

  # Class method to get all active categories as hash (for AI prompts)
  def self.for_ai_generation
    active.ordered.includes(:experience_types).map do |category|
      {
        key: category.key,
        name: category.name,
        experiences: category.experience_type_keys,
        duration: category.default_duration
      }
    end
  end
end
