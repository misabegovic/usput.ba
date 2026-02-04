# frozen_string_literal: true

module Ai
  # @deprecated Use Platform DSL instead: bin/platform chat
  #   This service will be removed in a future release.
  #   Use DSL: locations { id: X } | generate { style: "detailed" }
  #
  # Obogaćuje lokaciju sa AI-generisanim sadržajem
  # Koristi postojeća polja Location modela bez migracija
  class LocationEnricher
    include Concerns::ErrorReporting
    include PromptHelper

    class EnrichmentError < StandardError; end

    # NOTE: Batch constants moved to individual generator modules
    # - DescriptionGenerator::LOCALES_PER_BATCH
    # - HistoricalGenerator::LOCALES_PER_BATCH

    def initialize
      # No longer using @chat directly - using OpenaiQueue for rate limiting
    end

    # Obogaćuje jednu lokaciju sa AI sadržajem
    # @param location [Location] Lokacija za obogaćivanje
    # @param place_data [Hash] Opcioni podaci sa Geoapify-ja
    # @return [Boolean] Da li je obogaćivanje uspjelo
    def enrich(location, place_data: {})
      log_info "Enriching location: #{location.name}"

      enrichment = generate_enrichment(location, place_data)
      return false if enrichment.blank?

      apply_enrichment(location, enrichment)
      location.save!

      log_info "Successfully enriched location: #{location.name}"
      true
    rescue StandardError => e
      log_error "Failed to enrich location #{location.name}: #{e.message}"
      false
    end

    # Obogaćuje batch lokacija
    # @param locations [Array<Location>] Lokacije za obogaćivanje
    # @param place_data_map [Hash] Mapa location_id => place_data
    # @return [Hash] Rezultati { success: [], failed: [] }
    def enrich_batch(locations, place_data_map: {})
      results = { success: [], failed: [] }

      locations.each do |location|
        place_data = place_data_map[location.id] || {}

        if enrich(location, place_data: place_data)
          results[:success] << location
        else
          results[:failed] << location
        end
      end

      log_info "Batch enrichment complete: #{results[:success].count} success, #{results[:failed].count} failed"
      results
    end

    # Kreira novu lokaciju iz Geoapify podataka i obogaćuje je
    # @param place_data [Hash] Podaci sa Geoapify-ja
    # @param city [String] Ime grada
    # @return [Location, nil] Kreirana lokacija ili nil ako već postoji
    def create_and_enrich(place_data, city:)
      return nil if place_data[:name].blank? || place_data[:lat].blank?

      # Provjeri da li lokacija već postoji po koordinatama (primarno)
      existing = Location.find_by_coordinates_fuzzy(place_data[:lat], place_data[:lng])
      if existing
        log_info "Location already exists at coordinates: #{existing.name} (#{existing.id})"
        return existing
      end

      # Fallback: provjeri po imenu i gradu
      existing = Location.where(city: city)
                        .where("LOWER(name) = ?", place_data[:name].to_s.downcase)
                        .first
      if existing
        log_info "Location already exists: #{place_data[:name]} in #{city}"
        return existing
      end

      # Kreiraj lokaciju
      # Sanitize string fields from Geoapify to remove null bytes and control characters
      sanitized_name = sanitize_external_string(place_data[:name])
      sanitized_phone = sanitize_external_string(place_data[:contact]&.dig(:phone))
      sanitized_email = sanitize_external_string(place_data[:contact]&.dig(:email))

      location = Location.new(
        name: sanitized_name,
        lat: place_data[:lat],
        lng: place_data[:lng],
        city: city,
        location_type: determine_location_type(place_data[:categories]),
        budget: determine_budget(place_data),
        website: normalize_website_url(place_data[:website]),
        phone: sanitized_phone,
        email: sanitized_email,
        ai_generated: true
      )

      # Save location first so it has an ID for translations
      # Translations require translatable_id to be set (not-null constraint)
      unless location.save
        log_error "Failed to create location: #{location.errors.full_messages.join(', ')}"
        return nil
      end

      # Generate and apply enrichment (including translations) now that location has an ID
      enrichment = generate_enrichment(location, place_data)
      if enrichment.present?
        apply_enrichment(location, enrichment)
        location.save!
      end

      # Dodaj tagove iz kategorija
      add_tags_from_categories(location, place_data[:categories])

      log_info "Created and enriched location: #{location.name}"
      location
    rescue StandardError => e
      log_error "Error creating location #{place_data[:name]}: #{e.message}"
      nil
    end

    private

    def generate_enrichment(location, place_data)
      combined_result = {
        suitable_experiences: [],
        descriptions: {},
        historical_context: {},
        tags: [],
        practical_info: {}
      }

      # Step 1: Generate metadata
      metadata = MetadataGenerator.new.generate(location, place_data)
      if metadata.present?
        combined_result[:suitable_experiences] = metadata[:suitable_experiences] || []
        combined_result[:tags] = metadata[:tags] || []
        combined_result[:practical_info] = metadata[:practical_info] || {}
      end

      # Step 2: Generate descriptions
      descriptions = DescriptionGenerator.new.generate(location, place_data)
      combined_result[:descriptions] = descriptions if descriptions.present?

      # Step 3: Generate historical context
      history = HistoricalGenerator.new.generate(location, place_data)
      combined_result[:historical_context] = history if history.present?

      combined_result
    rescue Ai::OpenaiQueue::RequestError => e
      log_warn "AI enrichment failed for #{location.name}: #{e.message}"
      {}
    end

    def apply_enrichment(location, enrichment)
      Applicator.new(location).apply(enrichment)
    end

    def add_tags_from_categories(location, categories)
      Applicator.new(location).add_tags_from_categories(categories)
    end

    def determine_location_type(categories)
      return :place if categories.blank?

      category_str = categories.join(" ")

      if category_str.match?(/restaurant|cafe|bar|food|catering/)
        :restaurant
      elsif category_str.match?(/hotel|accommodation|lodging|hostel/)
        :accommodation
      elsif category_str.match?(/guide|tour/)
        :guide
      elsif category_str.match?(/shop|store|business|commercial/)
        :business
      elsif category_str.match?(/craft|artisan/)
        :artisan
      else
        :place
      end
    end

    def normalize_website_url(url)
      return nil if url.blank?

      url = url.to_s.strip
      return nil if url.empty?

      # Sanitize null bytes and control characters
      url = sanitize_external_string(url)
      return nil if url.blank?

      # Already has a valid scheme
      return url if url.match?(%r{\Ahttps?://}i)

      # Prepend https:// if no scheme present
      "https://#{url}"
    end

    # Sanitizes a string from external sources (Geoapify API) by removing null bytes
    # and other control characters that PostgreSQL rejects
    # @param str [String, nil] The string to sanitize
    # @return [String, nil] Sanitized string or nil
    def sanitize_external_string(str)
      return nil if str.nil?
      return str unless str.is_a?(String)

      # Remove null bytes (0x00) which PostgreSQL rejects in text columns
      # Also remove other control characters except tab, newline, carriage return
      str.gsub(/[\x00]/, "").gsub(/[\x01-\x08\x0B\x0C\x0E-\x1F]/, "")
    end

    def determine_budget(place_data)
      # Geoapify može vratiti price_level (1-4)
      price_level = place_data[:properties]&.dig(:price_level) ||
                   place_data[:price_level]

      case price_level
      when 1, 2
        :low
      when 3
        :medium
      when 4
        :high
      else
        :medium
      end
    end

    def cultural_context
      Ai::BihContext::BIH_CULTURAL_CONTEXT
    end

    def supported_locales
      @supported_locales ||= Locale.ai_supported_codes.presence ||
        %w[en bs hr de es fr it pt nl pl cs sk sl sr]
    end

    def supported_experience_types
      @supported_experience_types ||= ExperienceType.active_keys.presence ||
        %w[culture history sport food nature adventure relaxation]
    end

    def log_info(message)
      Rails.logger.info "[LocationEnricher] #{message}"
    end

    def log_warn(message)
      Rails.logger.warn "[LocationEnricher] #{message}"
    end

    def log_error(message)
      Rails.logger.error "[LocationEnricher] #{message}"
    end
  end
end
