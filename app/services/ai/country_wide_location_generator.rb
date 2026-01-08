module Ai
  # AI-powered location generator that discovers and creates locations
  # across all of Bosnia and Herzegovina without city restrictions.
  #
  # Unlike ExperienceGenerator which is limited to a single city's radius,
  # this generator uses AI to suggest notable locations across the entire country
  # and automatically creates cities when needed.
  #
  # == Strict Mode (default: enabled)
  #
  # By default, the generator operates in strict mode which ensures data quality:
  # - All AI suggestions are pre-validated via reverse geocoding
  # - Locations are only created when the city can be verified
  # - Suggestions that fail validation are queued for manual review
  # - The AI-suggested city name is NEVER used as a fallback
  #
  # To disable strict mode (not recommended):
  #   generator = Ai::CountryWideLocationGenerator.new(strict_mode: false)
  #
  # == Review Queue
  #
  # When strict mode is enabled, locations that fail validation are added to
  # a review queue instead of being created with potentially incorrect data.
  # The summary includes details about queued locations:
  #   result[:locations_queued_for_review]  # Count of queued locations
  #   result[:review_queue]                 # Array of queued location details
  #   result[:review_queue_by_reason]       # Breakdown by failure reason
  #
  # Common failure reasons:
  # - geocoding_failed: Reverse geocoding couldn't determine the city
  # - coordinates_outside_bih: Coordinates are outside Bosnia and Herzegovina
  # - missing_coordinates: AI didn't provide valid coordinates
  # - missing_name: AI didn't provide a location name
  #
  # Usage:
  #   generator = Ai::CountryWideLocationGenerator.new
  #   result = generator.generate_all
  #   result = generator.generate_for_region("Herzegovina")
  #   result = generator.generate_by_category("natural")
  #
  class CountryWideLocationGenerator
    include Concerns::ErrorReporting

    class GenerationError < StandardError; end

    # Bosnia and Herzegovina geographic boundaries (approximate)
    BIH_BOUNDS = {
      north: 45.28,
      south: 42.55,
      east: 19.62,
      west: 15.72,
      center_lat: 43.915,
      center_lng: 17.679
    }.freeze

    # Major regions in BiH for organized generation
    BIH_REGIONS = {
      "Sarajevo" => { lat: 43.8563, lng: 18.4131, radius: 30_000 },
      "Herzegovina" => { lat: 43.3438, lng: 17.8078, radius: 50_000 },
      "Bosanska Krajina" => { lat: 44.7758, lng: 17.1858, radius: 60_000 },
      "Centralna Bosna" => { lat: 44.2267, lng: 17.6639, radius: 50_000 },
      "Istočna Bosna" => { lat: 44.5384, lng: 18.6732, radius: 50_000 },
      "Posavina" => { lat: 45.0328, lng: 18.0158, radius: 40_000 },
      "Podrinje" => { lat: 44.1000, lng: 19.2000, radius: 40_000 }
    }.freeze

    # Cultural context for AI prompts
    BIH_CULTURAL_CONTEXT = ExperienceGenerator::BIH_CULTURAL_CONTEXT

    # Location type priority for generation order (lower = higher priority)
    # Most important tourist attractions should be generated first
    LOCATION_TYPE_PRIORITY = {
      "place" => 1,        # General places/landmarks - highest priority
      "restaurant" => 3,   # Restaurants - medium priority
      "artisan" => 4,      # Artisans - lower priority
      "guide" => 5,        # Guides - lower priority
      "business" => 6,     # Businesses - lower priority
      "accommodation" => 7 # Hotels/accommodation - lowest priority (generated last)
    }.freeze

    # Category priority for generation order (lower = higher priority)
    # Historical and cultural sites are most important for tourists
    CATEGORY_PRIORITY = {
      "historical" => 1,   # Historical monuments, UNESCO sites
      "cultural" => 2,     # Museums, theaters, cultural centers
      "religious" => 3,    # Mosques, churches, monasteries
      "natural" => 4,      # Nature, parks, waterfalls
      "adventure" => 5,    # Adventure activities
      "culinary" => 6,     # Food and restaurants
      "accommodation" => 7 # Hotels and lodging - lowest priority
    }.freeze

    # Maximum locales per batch to avoid token limit errors
    # With 7 locales per batch, we stay under the 128K token limit
    LOCALES_PER_BATCH = 7

    def initialize(options = {})
      # No longer using @chat directly - using OpenaiQueue for rate limiting
      @places_service = GeoapifyService.new
      @locations_created = []
      @experiences_created = []
      @locations_queued_for_review = []
      @options = {
        generate_audio: options.fetch(:generate_audio, false),
        audio_locale: options.fetch(:audio_locale, "bs"),
        skip_existing: options.fetch(:skip_existing, true),
        max_locations_per_region: options.fetch(:max_locations_per_region, 20),
        generate_experiences: options.fetch(:generate_experiences, false),
        strict_mode: options.fetch(:strict_mode, true) # Don't create locations with unverified cities
      }
    end

    # Generate locations across all of BiH
    # @return [Hash] Summary of what was created
    def generate_all
      Rails.logger.info "[AI::CountryWideLocationGenerator] Starting country-wide generation"

      BIH_REGIONS.each do |region_name, region_data|
        generate_for_region(region_name)
      end

      build_summary
    end

    # Generate locations for a specific region
    # @param region_name [String] Name of the region (from BIH_REGIONS)
    # @return [Hash] Summary of what was created
    def generate_for_region(region_name)
      region_data = BIH_REGIONS[region_name]
      raise GenerationError, "Unknown region: #{region_name}" unless region_data

      Rails.logger.info "[AI::CountryWideLocationGenerator] Generating locations for #{region_name}"

      # Step 1: Ask AI to suggest notable locations in this region
      ai_suggestions = get_ai_location_suggestions(region_name, region_data)

      # Step 2: Sort suggestions by priority (important locations first, hotels last)
      sorted_suggestions = sort_suggestions_by_priority(ai_suggestions)
      Rails.logger.info "[AI::CountryWideLocationGenerator] Sorted #{sorted_suggestions.count} suggestions by priority"

      # Step 3: For each suggestion, find/create location
      sorted_suggestions.each do |suggestion|
        process_ai_suggestion(suggestion, region_name)
      end

      build_summary
    end

    # Generate locations by category (e.g., "natural", "historical", "religious")
    # @param category [String] Category of locations to generate
    # @return [Hash] Summary of what was created
    def generate_by_category(category)
      Rails.logger.info "[AI::CountryWideLocationGenerator] Generating #{category} locations across BiH"

      # Ask AI for category-specific locations across all of BiH
      ai_suggestions = get_ai_category_suggestions(category)

      # Sort suggestions by priority (important location types first, hotels last)
      sorted_suggestions = sort_suggestions_by_priority(ai_suggestions)
      Rails.logger.info "[AI::CountryWideLocationGenerator] Sorted #{sorted_suggestions.count} suggestions by priority"

      sorted_suggestions.each do |suggestion|
        process_ai_suggestion(suggestion, "BiH")
      end

      build_summary
    end

    # Discover hidden gems - lesser-known but notable locations
    # @param count [Integer] Number of locations to discover
    # @return [Hash] Summary of what was created
    def discover_hidden_gems(count: 15)
      Rails.logger.info "[AI::CountryWideLocationGenerator] Discovering #{count} hidden gems"

      ai_suggestions = get_ai_hidden_gems(count)

      # Sort suggestions by priority (important location types first, hotels last)
      sorted_suggestions = sort_suggestions_by_priority(ai_suggestions)
      Rails.logger.info "[AI::CountryWideLocationGenerator] Sorted #{sorted_suggestions.count} suggestions by priority"

      sorted_suggestions.each do |suggestion|
        process_ai_suggestion(suggestion, "BiH")
      end

      build_summary
    end

    # Generate experiences from existing country-wide locations
    # Creates curated multi-location experiences across BiH regions
    # @return [Hash] Summary of what was created
    def generate_experiences
      Rails.logger.info "[AI::CountryWideLocationGenerator] Generating country-wide experiences"

      # Get all locations in BiH with coordinates and experience types
      bih_locations = Location.with_coordinates
                              .includes(:experience_types)

      if bih_locations.empty?
        Rails.logger.info "[AI::CountryWideLocationGenerator] No locations found for experience generation"
        return build_summary
      end

      # Generate experiences for each category
      experience_categories.each do |category_data|
        generate_experience_for_category(category_data, bih_locations)
      end

      build_summary
    end

    # Generate experiences by region - creates regional tour experiences
    # @param region_name [String] Name of the region (from BIH_REGIONS)
    # @return [Hash] Summary of what was created
    def generate_experiences_for_region(region_name)
      region_data = BIH_REGIONS[region_name]
      raise GenerationError, "Unknown region: #{region_name}" unless region_data

      Rails.logger.info "[AI::CountryWideLocationGenerator] Generating experiences for #{region_name}"

      # Get locations within the region's radius
      region_locations = find_locations_in_region(region_name, region_data)

      if region_locations.empty?
        Rails.logger.info "[AI::CountryWideLocationGenerator] No locations found in #{region_name}"
        return build_summary
      end

      # Generate experiences for each category within this region
      experience_categories.each do |category_data|
        generate_regional_experience(category_data, region_locations, region_name)
      end

      build_summary
    end

    # Generate a cross-region experience (e.g., "Grand Tour of Bosnia")
    # @return [Hash] Summary of what was created
    def generate_cross_region_experiences
      Rails.logger.info "[AI::CountryWideLocationGenerator] Generating cross-region experiences"

      bih_locations = Location.with_coordinates
                              .includes(:experience_types)

      if bih_locations.count < 5
        Rails.logger.info "[AI::CountryWideLocationGenerator] Not enough locations for cross-region experiences"
        return build_summary
      end

      # Generate themed cross-region experiences
      cross_region_themes.each do |theme|
        generate_cross_region_experience(theme, bih_locations)
      end

      build_summary
    end

    private

    # Get experience categories from database
    def experience_categories
      @experience_categories ||= ExperienceCategory.for_ai_generation.presence || default_experience_categories
    end

    # Fallback categories if database is empty
    def default_experience_categories
      [
        { key: "cultural_heritage", experiences: %w[culture history], duration: 180 },
        { key: "culinary_journey", experiences: %w[food], duration: 120 },
        { key: "nature_adventure", experiences: %w[nature sport], duration: 240 }
      ]
    end

    # Themes for cross-region experiences
    def cross_region_themes
      [
        {
          key: "grand_tour",
          name: "Grand Tour of Bosnia",
          name_bs: "Veliki Obilazak Bosne",
          description: "An epic journey through all regions of Bosnia and Herzegovina",
          experience_types: %w[culture history nature],
          duration: 480,
          min_locations: 7,
          max_locations: 12
        },
        {
          key: "ottoman_heritage_trail",
          name: "Ottoman Heritage Trail",
          name_bs: "Tragovima Osmanske Baštine",
          description: "Discover the rich Ottoman legacy across Bosnia",
          experience_types: %w[culture history],
          duration: 360,
          min_locations: 5,
          max_locations: 8
        },
        {
          key: "natural_wonders",
          name: "Natural Wonders of BiH",
          name_bs: "Prirodna Čuda BiH",
          description: "Explore the most spectacular natural sites across the country",
          experience_types: %w[nature sport],
          duration: 420,
          min_locations: 5,
          max_locations: 10
        },
        {
          key: "culinary_expedition",
          name: "Bosnian Culinary Expedition",
          name_bs: "Kulinarska Ekspedicija Bosnom",
          description: "Taste the diverse flavors of Bosnia from region to region",
          experience_types: %w[food culture],
          duration: 300,
          min_locations: 5,
          max_locations: 8
        }
      ]
    end

    def find_locations_in_region(region_name, region_data)
      center_lat = region_data[:lat]
      center_lng = region_data[:lng]
      radius_km = region_data[:radius] / 1000.0

      Location.with_coordinates
              .includes(:experience_types)
              .select do |loc|
                distance = Geocoder::Calculations.distance_between(
                  [center_lat, center_lng],
                  [loc.lat, loc.lng],
                  units: :km
                )
                distance <= radius_km
              end
    end

    def generate_experience_for_category(category_data, locations)
      category_record = ExperienceCategory.find_by(key: category_data[:key])

      matching_locations = locations.select do |loc|
        (loc.suitable_experiences & category_data[:experiences]).any?
      end

      min_locations = Setting.get("experience.min_locations", default: 1)
      return if matching_locations.count < min_locations

      # Group locations by city for better distribution
      locations_by_city = matching_locations.group_by(&:city)

      # Select locations from different cities for variety
      selected_locations = select_distributed_locations(locations_by_city, max_count: 8)
      return if selected_locations.count < min_locations

      experience = create_country_wide_experience(category_data, category_record, selected_locations)
      @experiences_created << experience if experience
    end

    def generate_regional_experience(category_data, locations, region_name)
      category_record = ExperienceCategory.find_by(key: category_data[:key])

      matching_locations = locations.select do |loc|
        (loc.suitable_experiences & category_data[:experiences]).any?
      end

      min_locations = Setting.get("experience.min_locations", default: 1)
      return if matching_locations.count < min_locations

      experience = create_regional_experience(category_data, category_record, matching_locations, region_name)
      @experiences_created << experience if experience
    end

    def generate_cross_region_experience(theme, all_locations)
      matching_locations = all_locations.select do |loc|
        (loc.suitable_experiences & theme[:experience_types]).any?
      end

      return if matching_locations.count < theme[:min_locations]

      # Ensure we have locations from multiple regions
      locations_by_region = group_locations_by_region(matching_locations)
      return if locations_by_region.keys.count < 3

      # Select locations from different regions
      selected_locations = select_cross_region_locations(locations_by_region, theme)
      return if selected_locations.count < theme[:min_locations]

      experience = create_cross_region_experience(theme, selected_locations)
      @experiences_created << experience if experience
    end

    def group_locations_by_region(locations)
      locations.group_by do |loc|
        determine_region_for_location(loc)
      end.compact
    end

    def determine_region_for_location(location)
      BIH_REGIONS.find do |region_name, region_data|
        distance = Geocoder::Calculations.distance_between(
          [region_data[:lat], region_data[:lng]],
          [location.lat, location.lng],
          units: :km
        )
        distance <= (region_data[:radius] / 1000.0)
      end&.first
    end

    def select_distributed_locations(locations_by_city, max_count:)
      selected = []
      cities = locations_by_city.keys.shuffle

      # Round-robin selection from each city
      while selected.count < max_count && cities.any?
        cities.each do |city|
          break if selected.count >= max_count

          remaining = locations_by_city[city] - selected
          if remaining.any?
            selected << remaining.sample
          else
            cities.delete(city)
          end
        end
      end

      selected
    end

    def select_cross_region_locations(locations_by_region, theme)
      selected = []
      regions = locations_by_region.keys.shuffle

      # Guard against empty regions to avoid division by zero (Infinity)
      return selected if regions.empty?

      max_per_region = (theme[:max_locations].to_f / regions.count).ceil

      regions.each do |region|
        region_locs = locations_by_region[region]
        take_count = [max_per_region, region_locs.count, theme[:max_locations] - selected.count].min
        selected.concat(region_locs.sample(take_count))
      end

      selected.first(theme[:max_locations])
    end

    def create_country_wide_experience(category_data, category_record, locations)
      experience_data = generate_country_experience_with_ai(category_data, locations, scope: "country")

      experience = Experience.new(
        estimated_duration: category_data[:duration],
        experience_category: category_record
      )

      set_experience_translations(experience, experience_data, category_data)

      if experience.save
        add_locations_to_experience(experience, experience_data, locations)
        attach_cover_photo(experience, locations)

        Rails.logger.info "[AI::CountryWideLocationGenerator] Created country-wide experience: #{experience.title}"
        experience
      else
        Rails.logger.error "[AI::CountryWideLocationGenerator] Failed to create experience: #{experience.errors.full_messages}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[AI::CountryWideLocationGenerator] Error creating experience: #{e.message}"
      nil
    end

    def create_regional_experience(category_data, category_record, locations, region_name)
      experience_data = generate_country_experience_with_ai(category_data, locations, scope: "region", region: region_name)

      experience = Experience.new(
        estimated_duration: category_data[:duration],
        experience_category: category_record
      )

      set_experience_translations(experience, experience_data, category_data, region: region_name)

      if experience.save
        add_locations_to_experience(experience, experience_data, locations)
        attach_cover_photo(experience, locations)

        Rails.logger.info "[AI::CountryWideLocationGenerator] Created regional experience for #{region_name}: #{experience.title}"
        experience
      else
        Rails.logger.error "[AI::CountryWideLocationGenerator] Failed to create regional experience: #{experience.errors.full_messages}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[AI::CountryWideLocationGenerator] Error creating regional experience: #{e.message}"
      nil
    end

    def create_cross_region_experience(theme, locations)
      experience_data = generate_cross_region_experience_with_ai(theme, locations)

      # Try to find a matching category
      category_record = ExperienceCategory.find_by(key: theme[:key]) ||
                       ExperienceCategory.find_by(key: "cultural_heritage")

      experience = Experience.new(
        estimated_duration: theme[:duration],
        experience_category: category_record
      )

      set_cross_region_experience_translations(experience, experience_data, theme)

      if experience.save
        add_locations_to_experience(experience, experience_data, locations)
        attach_cover_photo(experience, locations)

        Rails.logger.info "[AI::CountryWideLocationGenerator] Created cross-region experience: #{experience.title}"
        experience
      else
        Rails.logger.error "[AI::CountryWideLocationGenerator] Failed to create cross-region experience: #{experience.errors.full_messages}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[AI::CountryWideLocationGenerator] Error creating cross-region experience: #{e.message}"
      nil
    end

    def generate_country_experience_with_ai(category_data, locations, scope:, region: nil)
      prompt = build_country_experience_prompt(category_data, locations, scope, region)

      # Use OpenaiQueue for rate-limited requests
      result = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: country_experience_schema,
        context: "CountryWideLocationGenerator:experience:#{scope}"
      )
      result || { titles: {}, descriptions: {}, location_ids: [] }
    rescue Ai::OpenaiQueue::RequestError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] AI experience generation failed: #{e.message}"
      { titles: {}, descriptions: {}, location_ids: [] }
    end

    def generate_cross_region_experience_with_ai(theme, locations)
      prompt = build_cross_region_experience_prompt(theme, locations)

      # Use OpenaiQueue for rate-limited requests
      result = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: country_experience_schema,
        context: "CountryWideLocationGenerator:cross_region:#{theme}"
      )
      result || { titles: {}, descriptions: {}, location_ids: [] }
    rescue Ai::OpenaiQueue::RequestError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] AI cross-region experience generation failed: #{e.message}"
      { titles: {}, descriptions: {}, location_ids: [] }
    end

    # JSON Schema for country/cross-region experience generation
    # Note: OpenAI structured output requires additionalProperties: false at all levels
    # and all properties must be listed in required array
    def country_experience_schema
      locale_properties = supported_locales.to_h { |loc| [loc, { type: "string" }] }

      {
        type: "object",
        properties: {
          titles: {
            type: "object",
            properties: locale_properties,
            required: supported_locales,
            additionalProperties: false
          },
          descriptions: {
            type: "object",
            properties: locale_properties,
            required: supported_locales,
            additionalProperties: false
          },
          location_ids: { type: "array", items: { type: "integer" } }
        },
        required: %w[titles descriptions location_ids],
        additionalProperties: false
      }
    end

    def build_country_experience_prompt(category_data, locations, scope, region)
      locations_info = locations.map do |loc|
        description = loc.translate(:description, :bs).presence || loc.translate(:description, :en)
        "- ID: #{loc.id} | #{loc.name} (#{loc.city}) | Types: #{loc.experience_types.pluck(:key).join(", ")}"
      end.join("\n")

      scope_text = if scope == "region" && region
        "the #{region} region of"
      else
        "all of"
      end

      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Create a curated tourism experience spanning #{scope_text} Bosnia and Herzegovina.

        Experience Category: #{category_data[:key].to_s.titleize}
        Target Activities: #{category_data[:experiences].join(", ")}
        Estimated Duration: #{category_data[:duration]} minutes
        #{region ? "Region Focus: #{region}" : "Scope: Country-wide"}

        Available Locations:
        #{locations_info}

        GUIDELINES:
        1. Create a compelling narrative that connects locations across #{scope == "region" ? "the region" : "multiple cities/regions"}
        2. Consider geographic flow for a logical route
        3. Select 4-8 locations that work best together
        4. Emphasize the diversity and richness of Bosnian heritage

        TITLES:
        - Bosnian (bs): Use authentic, poetic names (e.g., "Tragovima Bosanske Povijesti", "Srcem Hercegovine")
        - Other languages: Keep key Bosnian terms while translating meaning

        Return ONLY valid JSON:
        {
          "titles": {
            "en": "English title...",
            "bs": "Bosanski naslov...",
            "de": "Deutscher Titel...",
            "hr": "Hrvatski naslov..."
          },
          "descriptions": {
            "en": "Engaging description (2-3 sentences)...",
            "bs": "Opis (2-3 rečenice)...",
            "de": "Beschreibung (2-3 Sätze)...",
            "hr": "Opis (2-3 rečenice)..."
          },
          "location_ids": [1, 2, 3, 4, 5]
        }
      PROMPT
    end

    def build_cross_region_experience_prompt(theme, locations)
      locations_info = locations.map do |loc|
        region = determine_region_for_location(loc)
        "- ID: #{loc.id} | #{loc.name} (#{loc.city}, #{region}) | Types: #{loc.experience_types.pluck(:key).join(", ")}"
      end.join("\n")

      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Create an epic cross-region experience: "#{theme[:name]}"

        Theme: #{theme[:name]}
        Bosnian Name: #{theme[:name_bs]}
        Description: #{theme[:description]}
        Target Experience Types: #{theme[:experience_types].join(", ")}
        Duration: #{theme[:duration]} minutes
        Locations Needed: #{theme[:min_locations]}-#{theme[:max_locations]}

        Available Locations (from multiple regions):
        #{locations_info}

        GUIDELINES:
        1. This is a GRAND experience spanning multiple regions of BiH
        2. Create a journey narrative that takes travelers across the country
        3. Ensure geographic diversity - include locations from different regions
        4. Order locations logically for travel
        5. This should feel like an epic adventure through Bosnia

        TITLES:
        - Should feel grand and inspiring
        - Use the theme name as inspiration but make it compelling
        - Bosnian title should be poetic and memorable

        Return ONLY valid JSON:
        {
          "titles": {
            "en": "#{theme[:name]}: A Journey Through...",
            "bs": "#{theme[:name_bs]}: Putovanje kroz..."
          },
          "descriptions": {
            "en": "Epic description of this grand journey...",
            "bs": "Epski opis ovog velikog putovanja..."
          },
          "location_ids": [1, 2, 3, 4, 5, 6, 7],
          "route_narrative": "Description of how the journey unfolds across regions"
        }
      PROMPT
    end

    def set_experience_translations(experience, experience_data, category_data, region: nil)
      fallback_title = if region
        "#{category_data[:key].to_s.titleize} in #{region}"
      else
        "#{category_data[:key].to_s.titleize} Across Bosnia"
      end

      supported_locales.each do |locale|
        title = experience_data.dig(:titles, locale.to_s) ||
               experience_data.dig(:titles, locale.to_sym) ||
               fallback_title

        description = experience_data.dig(:descriptions, locale.to_s) ||
                     experience_data.dig(:descriptions, locale.to_sym) ||
                     "Explore #{category_data[:key].to_s.humanize.downcase} across Bosnia and Herzegovina."

        experience.set_translation(:title, title, locale)
        experience.set_translation(:description, description, locale)
      end
    end

    def set_cross_region_experience_translations(experience, experience_data, theme)
      supported_locales.each do |locale|
        title = experience_data.dig(:titles, locale.to_s) ||
               experience_data.dig(:titles, locale.to_sym) ||
               (locale.to_s == "bs" ? theme[:name_bs] : theme[:name])

        description = experience_data.dig(:descriptions, locale.to_s) ||
                     experience_data.dig(:descriptions, locale.to_sym) ||
                     theme[:description]

        experience.set_translation(:title, title, locale)
        experience.set_translation(:description, description, locale)
      end
    end

    def add_locations_to_experience(experience, experience_data, locations)
      max_locations = Setting.get("experience.max_locations", default: 8)

      selected_locations = if experience_data[:location_ids].present?
        experience_data[:location_ids].filter_map { |id| locations.find { |l| l.id == id } }
      else
        []
      end

      # Fallback to provided locations if AI didn't return valid IDs
      selected_locations = locations.first(max_locations) if selected_locations.empty?

      selected_locations.each_with_index do |loc, index|
        experience.add_location(loc, position: index + 1)
      end
    end

    def attach_cover_photo(experience, locations)
      location_with_photo = locations.find { |loc| loc.photos.attached? }
      return unless location_with_photo

      source_photo = location_with_photo.photos.first
      return unless source_photo

      experience.cover_photo.attach(
        io: StringIO.new(source_photo.download),
        filename: "experience-#{experience.id}-cover#{File.extname(source_photo.filename.to_s)}",
        content_type: source_photo.content_type
      )
    rescue StandardError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] Could not attach cover photo: #{e.message}"
    end

    # Get supported locales from database
    def supported_locales
      @supported_locales ||= Locale.ai_supported_codes.presence || %w[en bs hr de es fr it pt nl pl cs sk sl sr]
    end

    # Get experience types from database
    def supported_experience_types
      @supported_experience_types ||= ExperienceType.active_keys.presence || %w[culture history sport food nature]
    end

    def get_ai_location_suggestions(region_name, region_data)
      prompt = build_region_suggestions_prompt(region_name, region_data)

      # Use OpenaiQueue for rate-limited requests
      suggestions = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: location_suggestions_schema,
        context: "CountryWideLocationGenerator:suggestions:#{region_name}"
      )

      suggestions&.dig(:locations) || []
    rescue Ai::OpenaiQueue::RequestError => e
      Rails.logger.error "[AI::CountryWideLocationGenerator] AI suggestion failed: #{e.message}"
      []
    end

    def get_ai_category_suggestions(category)
      prompt = build_category_suggestions_prompt(category)

      # Use OpenaiQueue for rate-limited requests
      suggestions = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: location_suggestions_schema,
        context: "CountryWideLocationGenerator:category:#{category}"
      )

      suggestions&.dig(:locations) || []
    rescue Ai::OpenaiQueue::RequestError => e
      Rails.logger.error "[AI::CountryWideLocationGenerator] AI category suggestion failed: #{e.message}"
      []
    end

    def get_ai_hidden_gems(count)
      prompt = build_hidden_gems_prompt(count)

      # Use OpenaiQueue for rate-limited requests
      suggestions = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: location_suggestions_schema,
        context: "CountryWideLocationGenerator:hidden_gems"
      )

      suggestions&.dig(:locations) || []
    rescue Ai::OpenaiQueue::RequestError => e
      Rails.logger.error "[AI::CountryWideLocationGenerator] AI hidden gems failed: #{e.message}"
      []
    end

    # JSON Schema for location suggestions
    # Note: OpenAI structured output requires additionalProperties: false at all levels
    # and all properties must be listed in required array
    def location_suggestions_schema
      {
        type: "object",
        properties: {
          locations: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                name_local: { type: "string" },
                lat: { type: "number" },
                lng: { type: "number" },
                city_name: { type: "string" },
                location_type: { type: "string" },
                category: { type: "string" },
                experience_types: { type: "array", items: { type: "string" } },
                why_notable: { type: "string" },
                estimated_visit_duration: { type: "integer" }
              },
              required: %w[name name_local lat lng city_name location_type category experience_types why_notable estimated_visit_duration],
              additionalProperties: false
            }
          }
        },
        required: ["locations"],
        additionalProperties: false
      }
    end

    def build_region_suggestions_prompt(region_name, region_data)
      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Suggest notable tourist locations in the #{region_name} region of Bosnia and Herzegovina.

        Region center: #{region_data[:lat]}, #{region_data[:lng]}
        Approximate radius: #{region_data[:radius] / 1000}km

        Please suggest up to #{@options[:max_locations_per_region]} notable locations that tourists should visit in this region.

        For EACH location, provide:
        1. name: The official/common name of the place
        2. name_local: Local Bosnian name if different
        3. lat: Latitude (precise, 6 decimal places)
        4. lng: Longitude (precise, 6 decimal places)
        5. city_name: The nearest city/town name
        6. location_type: One of: place, restaurant, accommodation, artisan, guide, business
        7. category: Primary category (historical, natural, religious, culinary, cultural, adventure)
        8. experience_types: Array from: #{supported_experience_types.join(", ")}
        9. why_notable: Brief explanation of why this place is worth visiting (1 sentence)
        10. estimated_visit_duration: In minutes

        IMPORTANT:
        - PRIORITIZE important tourist attractions: historical sites, cultural landmarks, natural wonders, and religious monuments should be listed FIRST
        - Hotels, accommodations, and less significant locations should be listed LAST
        - Include a mix of well-known attractions AND lesser-known gems
        - Ensure coordinates are accurate and within BiH borders
        - Include diverse categories: Ottoman heritage, Austro-Hungarian architecture, natural wonders, medieval sites, religious sites, traditional crafts, local cuisine
        - Don't just list obvious tourist spots - think like a knowledgeable local guide

        Return ONLY valid JSON:
        {
          "locations": [
            {
              "name": "Stari Most",
              "name_local": "Stari Most",
              "lat": 43.337222,
              "lng": 17.815278,
              "city_name": "Mostar",
              "location_type": "place",
              "category": "historical",
              "experience_types": ["culture", "history"],
              "why_notable": "UNESCO World Heritage iconic Ottoman bridge rebuilt after the war",
              "estimated_visit_duration": 60
            }
          ]
        }
      PROMPT
    end

    def build_category_suggestions_prompt(category)
      category_descriptions = {
        "natural" => "natural wonders - waterfalls, caves, mountains, rivers, lakes, springs, canyons, national parks",
        "historical" => "historical sites - medieval fortresses, Ottoman monuments, Austro-Hungarian buildings, archaeological sites, stećci tombstones",
        "religious" => "religious sites - mosques, churches, monasteries, synagogues, tekke (dervish lodges), pilgrimage sites",
        "culinary" => "culinary destinations - traditional restaurants, ćevabdžinice, coffee houses, markets, wineries, food producers",
        "cultural" => "cultural attractions - museums, galleries, theaters, traditional craft workshops, cultural centers",
        "adventure" => "adventure activities - rafting spots, hiking trails, ski resorts, climbing areas, paragliding sites"
      }

      description = category_descriptions[category] || category

      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Suggest the most notable #{description} across ALL of Bosnia and Herzegovina.

        Please suggest 20-30 locations that represent the BEST #{category} destinations in the country.

        For EACH location, provide:
        1. name: The official/common name of the place
        2. name_local: Local Bosnian name if different
        3. lat: Latitude (precise, 6 decimal places)
        4. lng: Longitude (precise, 6 decimal places)
        5. city_name: The nearest city/town name
        6. location_type: One of: place, restaurant, accommodation, artisan, guide, business
        7. category: "#{category}"
        8. experience_types: Array from: #{supported_experience_types.join(", ")}
        9. why_notable: Brief explanation of why this place is worth visiting (1 sentence)
        10. estimated_visit_duration: In minutes
        11. region: Which region of BiH (Sarajevo, Herzegovina, Bosanska Krajina, Centralna Bosna, Istočna Bosna, Posavina, Podrinje)

        IMPORTANT:
        - PRIORITIZE the most significant and notable locations FIRST
        - Places/landmarks should be listed before restaurants, hotels, or service providers
        - Cover ALL regions of BiH, not just famous areas
        - Include both famous and lesser-known locations
        - Ensure geographic diversity across the country
        - Coordinates must be accurate

        Return ONLY valid JSON:
        {
          "locations": [...]
        }
      PROMPT
    end

    def build_hidden_gems_prompt(count)
      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Discover #{count} HIDDEN GEMS in Bosnia and Herzegovina - places that are amazing but not well-known to international tourists.

        Think like a passionate local guide who wants to show visitors the "real" Bosnia beyond the usual tourist trail.

        PRIORITIZE these types of hidden gems (in order of importance):
        1. Historic sites that deserve more attention (highest priority)
        2. Secret viewpoints and natural wonders
        3. Villages with unique traditions
        4. Forgotten architectural gems
        5. Artisan workshops keeping old crafts alive
        6. Local festivals and gathering places
        7. Traditional food producers
        8. Family-run establishments with authentic experiences (lowest priority)

        For EACH hidden gem, provide:
        1. name: The name of the place
        2. name_local: Local Bosnian name
        3. lat: Latitude (precise, 6 decimal places)
        4. lng: Longitude (precise, 6 decimal places)
        5. city_name: The nearest city/town name
        6. location_type: One of: place, restaurant, accommodation, artisan, guide, business
        7. category: Primary category
        8. experience_types: Array from: #{supported_experience_types.join(", ")}
        9. why_notable: What makes this a special hidden gem (1-2 paragraphs, 100-200 words - paint a vivid picture!)
        10. best_time_to_visit: When is the ideal time to visit
        11. insider_tip: A tip that only locals would know

        Return ONLY valid JSON:
        {
          "locations": [...]
        }
      PROMPT
    end

    def process_ai_suggestion(suggestion, source_region)
      return if suggestion[:name].blank? || suggestion[:lat].blank? || suggestion[:lng].blank?

      # Pre-validate the AI suggestion (Option 3: Coordinate Validation Before Generation)
      validation = validate_ai_suggestion(suggestion)

      unless validation[:valid]
        if @options[:strict_mode]
          # In strict mode, queue invalid suggestions for review instead of creating them
          queue_for_review(suggestion, reason: validation[:reason], details: validation)
          return
        else
          # In non-strict mode, log warning but continue (legacy behavior)
          Rails.logger.warn "[AI::CountryWideLocationGenerator] Validation failed for #{suggestion[:name]}: #{validation[:reason]}"
          # Skip if coordinates are outside BiH (always enforced)
          return if validation[:reason] == "coordinates_outside_bih"
        end
      end

      # Check if location already exists
      if @options[:skip_existing]
        existing = find_existing_location(suggestion)
        if existing
          Rails.logger.info "[AI::CountryWideLocationGenerator] Skipping existing: #{suggestion[:name]}"
          return
        end
      end

      # Try to enrich with Geoapify data
      geoapify_data = fetch_geoapify_data(suggestion)

      # Create the location with verified city from validation
      location = create_location(suggestion, geoapify_data, source_region, verified_city: validation[:verified_city])
      @locations_created << location if location
    rescue StandardError => e
      Rails.logger.error "[AI::CountryWideLocationGenerator] Error processing #{suggestion[:name]}: #{e.message}"
    end

    def coordinates_in_bih?(lat, lng)
      lat.to_f.between?(BIH_BOUNDS[:south], BIH_BOUNDS[:north]) &&
        lng.to_f.between?(BIH_BOUNDS[:west], BIH_BOUNDS[:east])
    end

    # Validate AI suggestion by checking if geocoded city matches AI-suggested city
    # This prevents creating locations with incorrect city names
    # @param suggestion [Hash] AI-generated location suggestion
    # @return [Hash] Validation result with :valid, :verified_city, :reason keys
    def validate_ai_suggestion(suggestion)
      return { valid: false, reason: "missing_coordinates" } if suggestion[:lat].blank? || suggestion[:lng].blank?
      return { valid: false, reason: "missing_name" } if suggestion[:name].blank?

      unless coordinates_in_bih?(suggestion[:lat], suggestion[:lng])
        return { valid: false, reason: "coordinates_outside_bih" }
      end

      # Get the actual city from coordinates via reverse geocoding
      verified_city = get_city_from_coordinates(suggestion[:lat], suggestion[:lng])

      if verified_city.blank?
        return {
          valid: false,
          reason: "geocoding_failed",
          ai_city: suggestion[:city_name]
        }
      end

      # Check if the AI-suggested city matches the geocoded city
      if cities_match?(verified_city, suggestion[:city_name])
        {
          valid: true,
          verified_city: verified_city,
          city_match: true
        }
      else
        # Cities don't match - geocoding found a different city
        # We still consider this valid but use the geocoded city
        Rails.logger.info "[AI::CountryWideLocationGenerator] City corrected during validation: AI suggested '#{suggestion[:city_name]}', geocoding returned '#{verified_city}'"
        {
          valid: true,
          verified_city: verified_city,
          city_match: false,
          ai_city: suggestion[:city_name]
        }
      end
    end

    # Check if two city names refer to the same city (fuzzy matching)
    # Handles variations like "Sarajevo" vs "Grad Sarajevo", diacritics, etc.
    # @param city1 [String] First city name
    # @param city2 [String] Second city name
    # @return [Boolean] True if cities match
    def cities_match?(city1, city2)
      return true if city1.blank? && city2.blank?
      return false if city1.blank? || city2.blank?

      normalize = ->(name) {
        name.to_s
            .downcase
            .gsub(/^(grad|općina|opština|city of|municipality of)\s+/i, "")
            .gsub(/[čćž]/, "c" => "c", "ć" => "c", "ž" => "z")
            .gsub(/[šđ]/, "š" => "s", "đ" => "dj")
            .gsub(/[^a-z0-9]/, "")
            .strip
      }

      normalize.call(city1) == normalize.call(city2)
    end

    # Queue a location suggestion for manual review instead of creating it
    # Used when we can't verify the city name with confidence
    # @param suggestion [Hash] AI-generated location suggestion
    # @param reason [String] Why this location needs review
    # @param details [Hash] Additional context for the review
    def queue_for_review(suggestion, reason:, details: {})
      review_entry = {
        name: suggestion[:name],
        lat: suggestion[:lat],
        lng: suggestion[:lng],
        ai_city: suggestion[:city_name],
        reason: reason,
        details: details,
        queued_at: Time.current
      }

      @locations_queued_for_review << review_entry

      Rails.logger.warn "[AI::CountryWideLocationGenerator] Queued for review: #{suggestion[:name]} - #{reason}"
      Rails.logger.warn "  AI suggested city: #{suggestion[:city_name]}"
      Rails.logger.warn "  Coordinates: #{suggestion[:lat]}, #{suggestion[:lng]}"
      Rails.logger.warn "  Details: #{details.inspect}" if details.present?
    end

    # Known coordinate overrides for areas where geocoding services return incorrect data
    # These are manually verified corrections for problem areas
    COORDINATE_OVERRIDES = [
      # Zvornik area coordinates incorrectly mapped to Srebrenica by some services
      { lat_range: (44.38..44.42), lng_range: (19.08..19.14), city: "Zvornik" }
      # Add more overrides here as needed
    ].freeze

    # Use reverse geocoding to get the actual city name from coordinates
    # This corrects AI-suggested city names that may be incorrect
    # @param lat [Float] Latitude
    # @param lng [Float] Longitude
    # @return [String, nil] City name or nil if geocoding fails
    def get_city_from_coordinates(lat, lng)
      return nil if lat.blank? || lng.blank?

      lat_f = lat.to_f
      lng_f = lng.to_f

      # Check for known coordinate overrides first (manually verified corrections)
      override_city = check_coordinate_overrides(lat_f, lng_f)
      if override_city
        Rails.logger.info "[AI::CountryWideLocationGenerator] Using coordinate override for #{lat}, #{lng}: #{override_city}"
        return override_city
      end

      # Try Geoapify first (more reliable for Balkan regions)
      city_name = get_city_from_geoapify(lat_f, lng_f)
      return city_name if city_name.present?

      # Fallback to Nominatim via Geocoder gem
      get_city_from_nominatim(lat_f, lng_f)
    end

    # Check if coordinates fall within a known problematic area with manual override
    def check_coordinate_overrides(lat, lng)
      COORDINATE_OVERRIDES.each do |override|
        if override[:lat_range].cover?(lat) && override[:lng_range].cover?(lng)
          return override[:city]
        end
      end
      nil
    end

    # Use Geoapify reverse geocoding API (primary method)
    def get_city_from_geoapify(lat, lng)
      geoapify = GeoapifyService.new
      city = geoapify.get_city_from_coordinates(lat, lng)

      if city.present?
        Rails.logger.info "[AI::CountryWideLocationGenerator] Geoapify returned city '#{city}' for #{lat}, #{lng}"
      else
        Rails.logger.debug "[AI::CountryWideLocationGenerator] Geoapify returned no city for #{lat}, #{lng}"
      end

      city
    rescue GeoapifyService::ConfigurationError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] Geoapify not configured: #{e.message}. Falling back to Nominatim."
      nil
    rescue StandardError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] Geoapify geocoding failed for #{lat}, #{lng}: #{e.message}"
      nil
    end

    # Fallback to Nominatim via Geocoder gem
    def get_city_from_nominatim(lat, lng)
      # Rate limit to avoid overwhelming Nominatim (max 1 req/sec)
      sleep(1.1)

      results = Geocoder.search([lat, lng])
      if results.blank?
        Rails.logger.debug "[AI::CountryWideLocationGenerator] Nominatim returned empty results for #{lat}, #{lng}"
        return nil
      end

      result = results.first
      return nil unless result

      city_name = extract_city_from_geocoder_result(result)

      # Fallback: Try to extract from display_name
      if city_name.blank?
        city_name = extract_city_from_display_name(result.data["display_name"])
        Rails.logger.debug "[AI::CountryWideLocationGenerator] Extracted city from display_name: #{city_name}" if city_name.present?
      end

      if city_name.blank?
        Rails.logger.debug "[AI::CountryWideLocationGenerator] Nominatim could not determine city for #{lat}, #{lng}"
        return nil
      end

      cleaned = clean_city_name(city_name)
      Rails.logger.info "[AI::CountryWideLocationGenerator] Nominatim returned city '#{cleaned}' for #{lat}, #{lng}"
      cleaned
    rescue StandardError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] Nominatim geocoding failed for #{lat}, #{lng}: #{e.message}"
      nil
    end

    # Extract city using Geocoder accessor methods and raw address data
    def extract_city_from_geocoder_result(result)
      # Priority chain using Geocoder accessors - prefer specific fields over administrative regions
      %i[city town village suburb neighbourhood].each do |method|
        if result.respond_to?(method)
          value = result.send(method)
          return value if value.present?
        end
      end

      # Fall back to raw address data for additional fields
      address_data = result.data&.dig("address") || {}

      # Check hamlet/locality before falling back to municipality
      %w[hamlet locality].each do |field|
        return address_data[field] if address_data[field].present?
      end

      # Municipality/county are less reliable - they're administrative regions
      %w[municipality county state_district].each do |field|
        return address_data[field] if address_data[field].present?
      end

      nil
    end

    # Parse display_name to extract the most likely city/town name
    def extract_city_from_display_name(display_name)
      return nil if display_name.blank?

      parts = display_name.split(",").map(&:strip)
      return nil if parts.length < 2

      parts[1..4].each do |part|
        next if part.blank?
        next if part.match?(/\d{5}/)  # Skip postal codes
        next if part.match?(/^(Bosnia|Herzegovina|Bosna|Srbija|Serbia|Croatia|Hrvatska)/i)
        next if part.match?(/^(Republika Srpska|Federacija|Federation)/i)
        return part
      end

      nil
    end

    # Clean up city name by removing administrative prefixes
    def clean_city_name(city_name)
      city_name.to_s
               .gsub(/^Grad\s+/i, "")
               .gsub(/^Općina\s+/i, "")
               .gsub(/^Opština\s+/i, "")
               .gsub(/^Miasto\s+/i, "")
               .gsub(/^City of\s+/i, "")
               .gsub(/^Municipality of\s+/i, "")
               .strip
    end

    def find_existing_location(suggestion)
      # Try to find by name and proximity
      Location.where("LOWER(name) = ?", suggestion[:name].downcase)
              .with_coordinates
              .find do |loc|
                distance = Geocoder::Calculations.distance_between(
                  [loc.lat, loc.lng],
                  [suggestion[:lat], suggestion[:lng]],
                  units: :km
                )
                distance < 1 # Within 1km
              end
    end


    def fetch_geoapify_data(suggestion)
      # Search for the location in Geoapify to get additional data
      results = @places_service.text_search(
        query: "#{suggestion[:name]} #{suggestion[:city_name]} Bosnia",
        lat: suggestion[:lat],
        lng: suggestion[:lng],
        radius: 5000,
        max_results: 3
      )

      # Find the best match
      results.find do |result|
        next unless result[:lat] && result[:lng]

        distance = Geocoder::Calculations.distance_between(
          [result[:lat], result[:lng]],
          [suggestion[:lat], suggestion[:lng]],
          units: :km
        )
        distance < 2
      end
    rescue StandardError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] Geoapify lookup failed for #{suggestion[:name]}: #{e.message}"
      nil
    end

    # Create a location from an AI suggestion
    # @param suggestion [Hash] AI-generated location suggestion
    # @param geoapify_data [Hash, nil] Additional data from Geoapify
    # @param source_region [String] Region where this location was discovered
    # @param verified_city [String, nil] Pre-validated city name from validation step
    # @return [Location, nil] Created location or nil if creation failed
    def create_location(suggestion, geoapify_data, source_region, verified_city: nil)
      # Option 1: Strict Mode - Use pre-validated city, never fall back to AI suggestion
      if @options[:strict_mode]
        if verified_city.blank?
          # This shouldn't happen if process_ai_suggestion is working correctly,
          # but guard against it anyway
          Rails.logger.error "[AI::CountryWideLocationGenerator] Strict mode: Cannot create location without verified city: #{suggestion[:name]}"
          queue_for_review(suggestion, reason: "no_verified_city_in_strict_mode")
          return nil
        end
        city_name = verified_city
      else
        # Legacy behavior: Try geocoding, fall back to AI suggestion if it fails
        city_from_geocoding = verified_city || get_city_from_coordinates(suggestion[:lat], suggestion[:lng])

        if city_from_geocoding.present?
          city_name = city_from_geocoding
          if city_from_geocoding != suggestion[:city_name]
            Rails.logger.info "[AI::CountryWideLocationGenerator] City corrected: AI suggested '#{suggestion[:city_name]}', geocoding returned '#{city_from_geocoding}'"
          end
        else
          city_name = suggestion[:city_name]
          Rails.logger.warn "[AI::CountryWideLocationGenerator] Geocoding failed for #{suggestion[:name]} (#{suggestion[:lat]}, #{suggestion[:lng]}). Using AI suggestion: '#{city_name}' - THIS MAY BE INCORRECT!"
        end
      end

      # Check if location already exists at these coordinates (fuzzy match for small precision differences)
      existing = Location.find_by_coordinates_fuzzy(suggestion[:lat], suggestion[:lng])
      if existing
        Rails.logger.info "[AI::CountryWideLocationGenerator] Found existing location at coordinates: #{existing.name} (#{existing.id})"
        return existing
      end

      # Merge AI suggestion with Geoapify data
      location = Location.new(
        name: suggestion[:name],
        lat: suggestion[:lat].to_f,
        lng: suggestion[:lng].to_f,
        city: city_name,
        location_type: suggestion[:location_type]&.to_sym || :place,
        budget: :medium,
        website: geoapify_data&.dig(:website),
        phone: geoapify_data&.dig(:phone),
        tags: build_tags(suggestion, source_region)
      )

      # Generate rich content with AI (use verified city name)
      enrichment = enrich_location_with_ai(suggestion, verified_city: city_name)

      # Set translations
      set_location_translations(location, suggestion, enrichment)

      if location.save
        Rails.logger.info "[AI::CountryWideLocationGenerator] Created location: #{location.name} (city: #{city_name})"

        # Add experience types
        add_experience_types(location, suggestion[:experience_types])

        location
      else
        Rails.logger.error "[AI::CountryWideLocationGenerator] Failed to create location: #{location.errors.full_messages}"
        nil
      end
    end

    def build_tags(suggestion, source_region)
      tags = []
      tags << suggestion[:category] if suggestion[:category].present?
      tags << source_region.parameterize if source_region.present?
      tags << "hidden-gem" if suggestion[:insider_tip].present?
      tags << "ai-discovered"
      tags.compact.uniq
    end

    # Calculate priority score for a suggestion (lower = higher priority)
    # Prioritizes important tourist locations, leaves hotels/accommodation for last
    def calculate_suggestion_priority(suggestion)
      type_priority = LOCATION_TYPE_PRIORITY[suggestion[:location_type].to_s] || 5
      category_priority = CATEGORY_PRIORITY[suggestion[:category].to_s] || 5

      # Combined priority: weight category slightly more than type
      (category_priority * 2) + type_priority
    end

    # Sort suggestions by priority (most important first, hotels last)
    def sort_suggestions_by_priority(suggestions)
      suggestions.sort_by { |suggestion| calculate_suggestion_priority(suggestion) }
    end

    def add_experience_types(location, experience_type_keys)
      return if experience_type_keys.blank?

      experience_type_keys.each do |key|
        location.add_experience_type(key)
      rescue StandardError => e
        Rails.logger.warn "[AI::CountryWideLocationGenerator] Could not add experience type '#{key}': #{e.message}"
      end
    end

    def enrich_location_with_ai(suggestion, verified_city: nil)
      city_name = verified_city.presence || suggestion[:city_name] || "Bosnia and Herzegovina"

      # Process locales in batches to avoid token limit errors
      locale_batches = supported_locales.each_slice(LOCALES_PER_BATCH).to_a
      combined_result = { descriptions: {}, historical_context: {} }

      locale_batches.each_with_index do |batch_locales, batch_index|
        Rails.logger.info "[AI::CountryWideLocationGenerator] Processing locale batch #{batch_index + 1}/#{locale_batches.count} for #{suggestion[:name]}: #{batch_locales.join(', ')}"

        prompt = build_enrichment_prompt(suggestion, city_name, batch_locales)

        # Use OpenaiQueue for rate-limited requests
        batch_result = Ai::OpenaiQueue.request(
          prompt: prompt,
          schema: location_enrichment_schema(batch_locales),
          context: "CountryWideLocationGenerator:enrich:#{suggestion[:name]}"
        )
        next if batch_result.nil?

        # Merge batch results
        combined_result[:descriptions].merge!(batch_result[:descriptions] || {})
        combined_result[:historical_context].merge!(batch_result[:historical_context] || {})
      end

      combined_result
    rescue Ai::OpenaiQueue::RequestError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] AI enrichment failed: #{e.message}"
      { descriptions: {}, historical_context: {} }
    end

    def build_enrichment_prompt(suggestion, city_name, locales)
      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Create rich tourism content for this location in #{city_name}, Bosnia and Herzegovina.

        Location Information:
        - Name: #{suggestion[:name]}
        - Local name: #{suggestion[:name_local]}
        - City/Area: #{city_name}
        - Category: #{suggestion[:category]}
        - Why notable: #{suggestion[:why_notable]}
        #{suggestion[:insider_tip] ? "- Insider tip: #{suggestion[:insider_tip]}" : ""}

        Provide a JSON response with:
        1. descriptions: Object with localized descriptions (1-2 paragraphs, 100-200 words) for these languages: #{locales.join(", ")}
        2. historical_context: Object with localized historical/cultural context (2-4 paragraphs, 200-400 words for audio narration) for the same languages

        IMPORTANT FOR DESCRIPTIONS (1-2 paragraphs, 100-200 words):
        - Paint a vivid, sensory-rich picture of this place
        - Connect this place to Bosnia's rich cultural heritage
        - Use local Bosnian terminology (with brief explanations for tourists)
        - Highlight what makes this place special and worth visiting
        - Include atmosphere, sounds, smells, and the feeling of being there
        - Write naturally in each language (not just translations)

        IMPORTANT FOR HISTORICAL_CONTEXT (essay-style, 2-4 paragraphs, 200-400 words for audio narration):
        - Tell the complete story of this place in an engaging, narrative style
        - Include interesting facts, legends, local stories, and anecdotes
        - Mention specific dates, people, events, and their significance
        - Describe how this place has evolved through different historical eras
        - Make it captivating for audio narration by a tour guide
        - Connect to broader Bosnian history and culture
        - Add personal touches that bring the history to life

        Return ONLY valid JSON:
        {
          "descriptions": {
            "en": "English description...",
            "bs": "Bosanski opis...",
            ...
          },
          "historical_context": {
            "en": "Historical context for audio...",
            "bs": "Historijski kontekst za audio...",
            ...
          }
        }
      PROMPT
    end

    # JSON Schema for location enrichment content
    # Note: OpenAI structured output requires additionalProperties: false at all levels
    # and all properties must be listed in required array
    # @param locales [Array<String>] List of locale codes to include in schema (defaults to all)
    def location_enrichment_schema(locales = nil)
      locales ||= supported_locales
      locale_properties = locales.to_h { |loc| [loc, { type: "string" }] }

      {
        type: "object",
        properties: {
          descriptions: {
            type: "object",
            properties: locale_properties,
            required: locales,
            additionalProperties: false,
            description: "Localized descriptions keyed by locale code"
          },
          historical_context: {
            type: "object",
            properties: locale_properties,
            required: locales,
            additionalProperties: false,
            description: "Localized historical context for audio narration"
          }
        },
        required: %w[descriptions historical_context],
        additionalProperties: false
      }
    end

    def set_location_translations(location, suggestion, enrichment)
      default_description = suggestion[:why_notable] || "A notable location in Bosnia and Herzegovina."

      supported_locales.each do |locale|
        description = enrichment.dig(:descriptions, locale.to_s) ||
                     enrichment.dig(:descriptions, locale.to_sym) ||
                     default_description

        location.set_translation(:description, description, locale)

        if (context = enrichment.dig(:historical_context, locale.to_s) || enrichment.dig(:historical_context, locale.to_sym))
          location.set_translation(:historical_context, context, locale)
        end

        location.set_translation(:name, suggestion[:name], locale)
      end
    end

    def parse_ai_json_response(content)
      json_match = content.match(/```(?:json)?\s*([\s\S]*?)```/) ||
                  content.match(/(\{[\s\S]*\})/)

      json_str = json_match ? json_match[1] : content
      json_str = sanitize_ai_json(json_str)

      JSON.parse(json_str, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.warn "[AI::CountryWideLocationGenerator] Failed to parse AI response: #{e.message}"
      {}
    end

    def sanitize_ai_json(json_str)
      json_str = json_str.dup
      # Replace smart/curly quotes with straight quotes
      json_str.gsub!(/[""]/, '"')
      json_str.gsub!(/['']/, "'")
      # Remove trailing commas (invalid JSON but common in AI output)
      json_str.gsub!(/,(\s*[\}\]])/, '\1')
      # Escape control characters and fix structural issues within JSON strings
      json_str = escape_chars_in_json_strings(json_str)
      json_str
    end

    # Escapes problematic characters that appear within JSON string values
    # This handles cases where the AI includes literal newlines, unescaped
    # quotes, or other control characters in text content
    def escape_chars_in_json_strings(json_str)
      result = []
      in_string = false
      escape_next = false
      i = 0

      while i < json_str.length
        char = json_str[i]
        next_char = json_str[i + 1]

        if escape_next
          result << char
          escape_next = false
        elsif char == '\\'
          if in_string
            # Check if this backslash is followed by a valid JSON escape character
            if next_char && '"\\/bfnrtu'.include?(next_char)
              result << char
              escape_next = true
            else
              # Invalid escape sequence - escape the backslash itself
              result << '\\\\'
            end
          else
            result << char
            escape_next = true
          end
        elsif char == '"'
          if in_string
            # Check if this quote might be inside a string value (not ending it)
            # Look ahead to see if this looks like a premature string end
            if looks_like_embedded_quote?(json_str, i)
              result << '\\"'
            else
              result << char
              in_string = false
            end
          else
            result << char
            in_string = true
          end
        elsif in_string
          # Handle control characters within strings
          case char
          when "\n"
            result << '\\n'
          when "\r"
            result << '\\r'
          when "\t"
            result << '\\t'
          when "\f"
            result << '\\f'
          when "\b"
            result << '\\b'
          else
            # Escape any other control characters (0x00-0x1F)
            if char.ord < 32
              result << format('\\u%04x', char.ord)
            else
              result << char
            end
          end
        else
          result << char
        end

        i += 1
      end

      result.join
    end

    # Heuristic to detect if a quote inside a string is likely an embedded quote
    # rather than the actual end of the string value
    def looks_like_embedded_quote?(json_str, pos)
      return false if pos + 1 >= json_str.length

      remaining = json_str[(pos + 1)..-1]

      # If immediately followed by valid JSON structure, it's probably a real end quote
      return false if remaining.match?(/\A\s*[,\}\]:]/m)

      # If followed by a key pattern like `"key":`, it's probably a real end quote
      return false if remaining.match?(/\A\s*,?\s*"[^"]+"\s*:/m)

      # If followed by array/object closing, it's probably a real end quote
      return false if remaining.match?(/\A\s*[\}\]]/m)

      # Otherwise, this quote is likely embedded in text content
      # Look for patterns that suggest continuation of text
      remaining.match?(/\A[a-zA-Z0-9\s,.'!?;:\-]/m)
    end

    def build_summary
      summary = {
        locations_created: @locations_created.count,
        experiences_created: @experiences_created.count,
        locations_queued_for_review: @locations_queued_for_review.count,
        locations: @locations_created.map { |l| { id: l.id, name: l.name, city: l.city } },
        experiences: @experiences_created.map { |e| { id: e.id, title: e.title } }
      }

      # Include queued locations details if any exist
      if @locations_queued_for_review.any?
        summary[:review_queue] = @locations_queued_for_review.map do |entry|
          {
            name: entry[:name],
            ai_city: entry[:ai_city],
            coordinates: "#{entry[:lat]}, #{entry[:lng]}",
            reason: entry[:reason]
          }
        end

        # Group by reason for easier analysis
        summary[:review_queue_by_reason] = @locations_queued_for_review
          .group_by { |e| e[:reason] }
          .transform_values(&:count)
      end

      summary
    end
  end
end
