# frozen_string_literal: true

# Locale model for managing supported languages
# Replaces the hardcoded SUPPORTED_LOCALES in Translation model
class Locale < ApplicationRecord
  validates :code, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ai_supported, -> { where(ai_supported: true) }
  scope :ordered, -> { order(position: :asc, name: :asc) }

  # Get all active locale codes
  def self.active_codes
    active.ordered.pluck(:code)
  end

  # Get all AI-supported locale codes (for content generation)
  def self.ai_supported_codes
    active.ai_supported.ordered.pluck(:code)
  end

  # Get locale display info for admin UI
  def display_name
    if native_name.present? && native_name != name
      "#{flag_emoji} #{name} (#{native_name})"
    else
      "#{flag_emoji} #{name}"
    end
  end

  # Get locales as hash (for backwards compatibility)
  def self.as_hash
    active.ordered.each_with_object({}) do |locale, hash|
      hash[locale.code] = {
        name: locale.name,
        native_name: locale.native_name,
        flag: locale.flag_emoji
      }
    end
  end
end
