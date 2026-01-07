# frozen_string_literal: true

# Translatable concern for models that need multi-language support
#
# Usage:
#   class Location < ApplicationRecord
#     include Translatable
#     translates :name, :description, :historical_context
#   end
#
#   location = Location.find(1)
#   location.set_translation(:name, "Stari Most", :hr)
#   location.translate(:name, :hr)  # => "Stari Most"
#   location.name_hr                # => "Stari Most"
#   location.name_hr = "Stari Most" # Sets translation
#
module Translatable
  extend ActiveSupport::Concern

  included do
    has_many :translations, as: :translatable, dependent: :destroy

    # Class attribute to store translatable fields
    class_attribute :translatable_fields, default: []
  end

  class_methods do
    # Define which fields should be translatable
    # @param fields [Array<Symbol>] list of field names to translate
    def translates(*fields)
      self.translatable_fields = fields.map(&:to_sym)

      fields.each do |field|
        # Define getter methods for each locale
        # e.g., name_hr, name_de, etc.
        Translation::SUPPORTED_LOCALES.each do |locale|
          # Getter: location.name_hr
          define_method("#{field}_#{locale}") do
            translate(field, locale)
          end

          # Setter: location.name_hr = "value"
          define_method("#{field}_#{locale}=") do |value|
            set_translation(field, value, locale)
          end
        end
      end
    end
  end

  # Get translated value for a field
  # Falls back to the original field value if translation is not found
  #
  # @param field [Symbol, String] the field name
  # @param locale [Symbol, String] the locale (defaults to I18n.locale)
  # @return [String, nil] the translated value or original value
  def translate(field, locale = I18n.locale)
    locale = locale.to_s
    field = field.to_s

    # First try to find the exact translation
    translation = translations.find_by(field_name: field, locale: locale)
    return translation.value if translation&.value.present?

    # Try fallback locales
    fallback_locales = I18n.fallbacks[locale.to_sym] rescue [ locale.to_sym, :en ]
    fallback_locales.each do |fallback_locale|
      next if fallback_locale.to_s == locale

      translation = translations.find_by(field_name: field, locale: fallback_locale.to_s)
      return translation.value if translation&.value.present?
    end

    # Fall back to the original field value
    send(field) if respond_to?(field)
  end

  # Alias for translate
  alias_method :t, :translate

  # Set translation for a field
  #
  # @param field [Symbol, String] the field name
  # @param value [String] the translated value
  # @param locale [Symbol, String] the locale (defaults to I18n.locale)
  # @return [Translation] the translation record
  def set_translation(field, value, locale = I18n.locale)
    locale = locale.to_s
    field = field.to_s

    translation = translations.find_or_initialize_by(
      field_name: field,
      locale: locale
    )
    translation.value = value
    translation.save!
    translation
  end

  # Set multiple translations at once
  #
  # @param translations_hash [Hash] hash with field names as keys and values
  # @param locale [Symbol, String] the locale
  # @return [Array<Translation>] list of saved translations
  #
  # Example:
  #   location.set_translations({ name: "Stari Most", description: "Famous bridge" }, :hr)
  def set_translations(translations_hash, locale = I18n.locale)
    translations_hash.map do |field, value|
      set_translation(field, value, locale)
    end
  end

  # Get all translations for a specific locale
  #
  # @param locale [Symbol, String] the locale
  # @return [Hash] hash with field names as keys and values
  def translations_for(locale)
    translations.for_locale(locale).as_hash(locale)
  end

  # Get all translations grouped by locale
  #
  # @return [Hash] hash with locales as keys and field hashes as values
  def all_translations
    translations.group_by(&:locale).transform_values do |trans|
      trans.to_h { |t| [ t.field_name, t.value ] }
    end
  end

  # Check if a translation exists for a field and locale
  #
  # @param field [Symbol, String] the field name
  # @param locale [Symbol, String] the locale
  # @return [Boolean]
  def has_translation?(field, locale = I18n.locale)
    translations.exists?(field_name: field.to_s, locale: locale.to_s)
  end

  # Get the translated value for a field with the current I18n locale
  # This is useful in views: location.translated(:name)
  def translated(field)
    translate(field)
  end
end
