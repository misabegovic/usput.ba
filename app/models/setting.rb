# frozen_string_literal: true

# Setting model for application configuration
# Stores key-value pairs with type casting support
#
# Example usage:
#   Setting.get("geoapify.search_radius") # => 15000
#   Setting.set("geoapify.search_radius", 20000, type: "integer")
class Setting < ApplicationRecord
  CATEGORIES = %w[general geoapify ai photo security].freeze
  VALUE_TYPES = %w[string integer float boolean json array].freeze

  validates :key, presence: true, uniqueness: true
  validates :value_type, inclusion: { in: VALUE_TYPES }
  validates :category, inclusion: { in: CATEGORIES }

  scope :by_category, ->(category) { where(category: category) }

  # Get a setting value with type casting
  def self.get(key, default: nil)
    setting = find_by(key: key)
    return default unless setting

    setting.typed_value
  end

  # Set a setting value
  def self.set(key, value, type: "string", category: "general", description: nil)
    setting = find_or_initialize_by(key: key)
    setting.value = value.to_s
    setting.value_type = type
    setting.category = category
    setting.description = description if description
    setting.save!
    setting
  end

  # Get typed value
  def typed_value
    case value_type
    when "integer"
      value.to_i
    when "float"
      value.to_f
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(value)
    when "json"
      JSON.parse(value)
    when "array"
      JSON.parse(value)
    else
      value
    end
  rescue JSON::ParserError
    value
  end

  # Get all settings for a category as a hash
  def self.for_category(category)
    by_category(category).each_with_object({}) do |setting, hash|
      hash[setting.key] = setting.typed_value
    end
  end

  # Bulk update settings
  def self.bulk_set(settings_hash, category: "general")
    settings_hash.each do |key, config|
      set(
        key,
        config[:value],
        type: config[:type] || "string",
        category: category,
        description: config[:description]
      )
    end
  end
end
