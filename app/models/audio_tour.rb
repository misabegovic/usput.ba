class AudioTour < ApplicationRecord
  include Identifiable

  # Associations
  belongs_to :location

  # Active Storage attachment for the audio file
  has_one_attached :audio_file

  # Validations
  validates :locale, presence: true
  validates :locale, uniqueness: { scope: :location_id, message: "already has an audio tour for this language" }
  validates :locale, inclusion: { in: ->(_) { SUPPORTED_LOCALES.keys.map(&:to_s) }, message: "is not supported" }

  # Supported languages for audio tours
  SUPPORTED_LOCALES = {
    bs: "Bosanski",
    en: "English",
    de: "Deutsch",
    hr: "Hrvatski",
    sr: "Srpski",
    fr: "Français",
    it: "Italiano",
    es: "Español",
    nl: "Nederlands",
    pl: "Polski",
    cs: "Čeština",
    sl: "Slovenščina",
    tr: "Türkçe",
    ar: "العربية"
  }.freeze

  # Default locales to generate for new audio tours
  DEFAULT_GENERATION_LOCALES = %w[bs en de].freeze

  # Scopes
  scope :by_locale, ->(locale) { where(locale: locale) }
  scope :with_audio, -> { joins(:audio_file_attachment) }

  # Get the language name for the current locale
  def language_name
    SUPPORTED_LOCALES[locale.to_sym] || locale.upcase
  end

  # Check if audio file is ready
  def audio_ready?
    audio_file.attached?
  end

  # Get audio file URL for playback
  def audio_url
    return nil unless audio_ready?
    Rails.application.routes.url_helpers.rails_blob_path(audio_file, only_path: true)
  end

  # Duration estimate based on word count
  def estimated_duration
    return duration if duration.present?
    return nil unless word_count.present? && word_count > 0

    minutes = (word_count / 150.0).round(1)
    "#{minutes} min"
  end

  # Class method to get available locales
  def self.available_locales
    SUPPORTED_LOCALES
  end

  # Class method to get default generation locales
  def self.default_locales
    DEFAULT_GENERATION_LOCALES
  end

  # Get locale options for select dropdown
  def self.locale_options
    SUPPORTED_LOCALES.map { |code, name| [name, code.to_s] }
  end

  # Get locales that are available for a specific location
  def self.available_for_location(location)
    where(location: location).where.associated(:audio_file_attachment).pluck(:locale)
  end

  # Get missing locales for a location (locales that don't have audio yet)
  def self.missing_locales_for_location(location, target_locales: DEFAULT_GENERATION_LOCALES)
    existing = available_for_location(location)
    target_locales.map(&:to_s) - existing
  end
end
