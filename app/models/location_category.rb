# frozen_string_literal: true

# LocationCategory represents a category/type of location
# Examples: Attraction, Restaurant, Museum, Nature Park, etc.
#
# Replaces the hardcoded location_type enum in Location model
# Allows AI and users to create new categories dynamically
# A location can belong to multiple categories (many-to-many)
class LocationCategory < ApplicationRecord
  include Identifiable
  include Translatable

  translates :name, :description

  # Associations (many-to-many through join table)
  has_many :location_category_assignments, dependent: :destroy
  has_many :locations, through: :location_category_assignments

  # Validations
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, name: :asc) }

  # Find by key (case-insensitive)
  def self.find_by_key(key)
    find_by("LOWER(key) = ?", key.to_s.downcase)
  end

  # Find or create by key (for AI generation)
  def self.find_or_create_by_key(key, name: nil, icon: nil)
    existing = find_by_key(key)
    return existing if existing

    create(
      key: key.to_s.downcase.gsub(/\s+/, '_'),
      name: name || key.to_s.titleize,
      icon: icon || 'circle',
      active: true,
      position: maximum(:position).to_i + 1
    )
  end

  # Check if this is a "contact" type category (guide, business, artisan)
  def contact_type?
    %w[guide business artisan].include?(key)
  end

  # Check if this is a "place" type category (everything else)
  def place_type?
    !contact_type?
  end

  # Class method for AI generation - returns all active categories
  def self.for_ai_generation
    active.ordered.map do |category|
      {
        key: category.key,
        name: category.name,
        description: category.description,
        icon: category.icon
      }
    end
  end

  # Get all place-type categories
  def self.place_categories
    active.ordered.reject(&:contact_type?)
  end

  # Get all contact-type categories
  def self.contact_categories
    active.ordered.select(&:contact_type?)
  end
end
