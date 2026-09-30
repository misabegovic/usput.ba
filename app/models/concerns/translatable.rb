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
#   location.name_hr = "Stari Most" # Staged; saved with location.save
#
module Translatable
  extend ActiveSupport::Concern

  # The locales a lookup for `locale` may return, in the order it tries them.
  def self.fallback_chain(locale)
    locale = locale.to_s
    fallbacks = begin
      I18n.fallbacks[locale.to_sym]
    rescue StandardError
      [ locale.to_sym, :en ]
    end

    ([ locale ] + Array(fallbacks).map(&:to_s)).uniq
  end

  def self.request_locale_chain
    fallback_chain(I18n.locale)
  end

  included do
    has_many :translations, as: :translatable, dependent: :destroy, autosave: true

    # Preloading `translations` pulls every locale of every field — sixteen
    # locales' worth to render one card. This one holds only what the current
    # request could resolve to, so a page preloads it instead.
    has_many :locale_translations,
             -> { where(locale: Translatable.request_locale_chain) },
             as: :translatable, class_name: "Translation"

    # Class attribute to store translatable fields
    class_attribute :translatable_fields, default: []
  end

  class_methods do
    # Define which fields should be translatable
    # @param fields [Array<Symbol>] list of field names to translate
    def translates(*fields)
      self.translatable_fields = fields.map(&:to_sym)

      fields.each do |field|
        # Per-language accessors (name_hr, name_de, ...) read and write exactly
        # one language, with no fallback, which is what an edit form needs: an
        # empty German field must not show the English text and then save it
        # as German. Reading with fallbacks is what `translate` is for.
        Translation::SUPPORTED_LOCALES.each do |locale|
          define_method("#{field}_#{locale}") do
            stored_translation(field, locale)&.value
          end

          define_method("#{field}_#{locale}=") do |value|
            write_translation(field, locale, value)
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
  # Source locales - content is natively in Bosnian/Croatian (Latin script)
  # For these locales, prefer original content over fallback translations
  SOURCE_LOCALES = %w[bs hr].freeze

  def translate(field, locale = I18n.locale)
    locale = locale.to_s
    field = field.to_s
    chain = fallback_chain(locale)
    values = translated_values(field, chain)

    # First try to find the exact translation
    return values[locale] if values[locale].present?

    # For source locales (bs, hr), prefer original content over fallback translations
    # This ensures Bosnian/Croatian users see Latin script content, not Cyrillic or English
    if SOURCE_LOCALES.include?(locale)
      original = send(field) if respond_to?(field)
      return original if original.present?
    end

    # Try fallback locales (for non-source locales like de, fr, etc.)
    chain.each do |fallback_locale|
      next if fallback_locale == locale

      return values[fallback_locale] if values[fallback_locale].present?
    end

    # Fall back to the original field value
    send(field) if respond_to?(field)
  end

  # Aliases for translate
  alias_method :t, :translate
  alias_method :translation_for, :translate

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

  # Stages one language of one field on the record, saved with it (autosave),
  # so a record that fails validation leaves its translations untouched too.
  # An unchanged value is left alone, a blank one removes the translation, and a
  # change made by a person in the admin (Current.editor) is marked as theirs.
  def write_translation(field, locale, value)
    field = field.to_s
    locale = locale.to_s
    existing = stored_translation(field, locale)

    if value.blank?
      existing&.mark_for_destruction
      return
    end
    return if existing && existing.value == value

    translation = existing || translations.build(field_name: field, locale: locale)
    translation.value = value
    translation.human_edited_at = Time.current if Current.editor
  end

  def stored_translation(field, locale)
    field = field.to_s
    locale = locale.to_s
    translations.detect do |translation|
      translation.field_name == field && translation.locale == locale && !translation.marked_for_destruction?
    end
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

  private

  def fallback_chain(locale)
    Translatable.fallback_chain(locale)
  end

  # The whole fallback chain is resolved in one pass rather than one lookup per
  # locale, and from memory when the association is preloaded — a `find_by`
  # would query per locale and ignore the preload, which is what made a rendered
  # card cost a query per translated field per fallback step.
  def translated_values(field, chain)
    rows = preloaded_translations(chain) || translations.where(field_name: field, locale: chain).to_a

    rows.each_with_object({}) do |row, values|
      next unless row.field_name == field

      values[row.locale] ||= row.value
    end
  end

  # `locale_translations` only holds the request's own chain, so an explicit
  # lookup in some other locale has to fall through to the query.
  def preloaded_translations(chain)
    return translations.to_a if translations.loaded?
    return locale_translations.to_a if locale_translations.loaded? && chain == Translatable.request_locale_chain

    nil
  end
end
