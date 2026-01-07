# frozen_string_literal: true

# Translation model for storing localized content
# Uses polymorphic association to support multiple models
#
# Example:
#   location = Location.find(1)
#   location.set_translation(:name, "Stari Most", :hr)
#   location.translate(:name, :hr) # => "Stari Most"
#
class Translation < ApplicationRecord
  belongs_to :translatable, polymorphic: true

  validates :locale, presence: true
  validates :field_name, presence: true
  validates :value, presence: true
  validates :locale, uniqueness: { scope: [ :translatable_type, :translatable_id, :field_name ] }

  # Supported locales (must match I18n.available_locales)
  SUPPORTED_LOCALES = %w[en bs hr de es fr it pt nl pl cs sk sl sr tr ar].freeze

  scope :for_locale, ->(locale) { where(locale: locale.to_s) }
  scope :for_field, ->(field) { where(field_name: field.to_s) }

  # Returns all translations for a specific locale as a hash
  # @param locale [String, Symbol] the locale code
  # @return [Hash] field names as keys, translations as values
  def self.as_hash(locale)
    for_locale(locale).pluck(:field_name, :value).to_h
  end
end
