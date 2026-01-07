module Ai
  # AI-powered experience generator that uses RubyLLM to create
  # curated experiences for a city based on Geoapify Places data
  class ExperienceGenerator
    include Concerns::ErrorReporting

    class GenerationError < StandardError; end

    # Bosnia and Herzegovina cultural context for AI-generated content
    BIH_CULTURAL_CONTEXT = <<~CONTEXT
      You are creating content specifically for Bosnia and Herzegovina tourism.

      IMPORTANT CULTURAL ELEMENTS TO EMPHASIZE:

      🕌 Ottoman Heritage (1463-1878):
      - Čaršije (old bazaar quarters) - heart of every Bosnian town
      - Mosques (džamije), hammams, bezistans (covered markets)
      - Ćuprije (bridges) - Stari Most in Mostar being the most famous
      - Traditional mahale (neighborhoods)

      🏛️ Austro-Hungarian Legacy (1878-1918):
      - Vijećnica (Sarajevo City Hall), National Museum
      - European architecture blending with Ottoman
      - Ferhadija street, Baščaršija transition areas

      ⚱️ Medieval Bosnia:
      - Stećci (UNESCO medieval tombstones) - unique to this region
      - Medieval fortresses: Travnik, Jajce, Počitelj, Blagaj
      - Bogomil heritage and mysteries

      🍽️ Traditional Cuisine:
      - Ćevapi (grilled minced meat) - national dish, served in somun bread
      - Burek (phyllo pie with meat), sirnica (cheese), zeljanica (spinach)
      - Bosanska kahva (Bosnian coffee) - ritual, not just a drink
      - Sogan-dolma, japrak, klepe, begova čorba
      - Tufahije, hurmasice, baklava (sweets)

      🎵 Music & Arts:
      - Sevdalinka - traditional love songs (sevdah = longing)
      - Traditional instruments: saz, šargija, def
      - Ganga singing in Herzegovina

      🛠️ Traditional Crafts:
      - Ćilimarstvo (carpet weaving)
      - Filigran (silver filigree work)
      - Bakarstvo (copper crafting) - džezve, ibrici
      - Woodcarving, pottery

      ⛪🕌✡️ Religious Coexistence:
      - Mosques, Orthodox churches, Catholic churches, synagogues
      - Centuries of coexistence - unique in Europe

      🏔️ Natural Heritage:
      - Sutjeska National Park (primeval forest Perućica)
      - Una National Park (waterfalls, rafting)
      - Blidinje, Prokoško Lake, Vrelo Bosne
      - Kravice waterfalls, Štrbački buk

      🕊️ Recent History (1992-1995):
      - War remembrance sites (Tunnel of Hope, Srebrenica Memorial)
      - Resilience and reconstruction stories
      - Meaningful historical context for visitors

      CONTENT GUIDELINES:
      - Use local terminology with brief explanations for tourists
      - Highlight what makes each place uniquely Bosnian
      - Connect locations to broader cultural narratives
      - Be respectful of all religious and ethnic communities
      - Emphasize the blend of East and West that defines BiH

      CRITICAL LANGUAGE REQUIREMENTS:
      When writing in South Slavic languages, you MUST use these distinct variants:

      - "bs" = BOSNIAN (bosanski jezik):
        * MUST use LATIN script (latinica), NEVER Cyrillic
        * MUST use IJEKAVIAN pronunciation: "rijeka", "mlijeko", "lijepo", "historija"
        * Use Bosnian-specific words: "hiljada" (not "tisuća"), "historija" (not "povijest")
        * Use "h" in words: "lahko", "mehko", "kahva"
        * Common phrases: "Dobro došli", "Hvala lijepa", "Može li...?"

      - "hr" = CROATIAN (hrvatski jezik):
        * Use LATIN script (latinica)
        * Use IJEKAVIAN pronunciation: "rijeka", "mlijeko", "lijepo"
        * Use Croatian-specific words: "tisuća", "povijest", "kazalište", "kolodvor"
        * Common phrases: "Dobrodošli", "Hvala lijepo"

      - "sr" = SERBIAN (srpski jezik):
        * Use LATIN script (latinica) for this platform
        * Use EKAVIAN pronunciation: "reka", "mleko", "lepo", "istorija"
        * Use Serbian-specific words: "hiljada", "istorija", "pozorište"
        * Common phrases: "Dobrodošli", "Hvala lepo"

      DO NOT mix these languages! Each has distinct vocabulary and pronunciation.
      For "bs" (Bosnian): ALWAYS ijekavica + latinica + Bosnian vocabulary.
    CONTEXT

    # @param city_name [String] The city name
    # @param coordinates [Hash] Hash with :lat and :lng keys for the city center
    # @param options [Hash] Additional options
    def initialize(city_name, coordinates:, **options)
      @city_name = city_name
      @coordinates = coordinates
      @places_service = GeoapifyService.new
      @chat = RubyLLM.chat
      @locations_created = []
      @experiences_created = []
      @options = {
        generate_audio: options.fetch(:generate_audio, true),
        audio_locale: options.fetch(:audio_locale, "bs"),
        skip_existing_locations: options.fetch(:skip_existing_locations, true)
      }
    end

    # Generate everything for a city
    # @return [Hash] Summary of what was created
    def generate_all
      Rails.logger.info "[AI::ExperienceGenerator] Starting full generation for #{@city_name}"

      # Step 1: Fetch places from Geoapify
      places = fetch_places

      # Step 2: Create locations from places using AI enrichment
      create_locations_from_places(places)

      # Step 3: Generate audio tours for locations with historical context
      audio_results = generate_audio_tours if @options[:generate_audio]

      # Step 4: Generate experiences using AI
      generate_experiences

      {
        city: @city_name,
        locations_created: @locations_created.count,
        experiences_created: @experiences_created.count,
        audio_tours_generated: audio_results&.dig(:generated) || 0,
        locations: @locations_created.map(&:name),
        experiences: @experiences_created.map(&:title)
      }
    end

    # Only generate locations (no experiences)
    def generate_locations_only
      Rails.logger.info "[AI::ExperienceGenerator] Generating locations for #{@city_name}"

      places = fetch_places
      create_locations_from_places(places)

      # Generate audio tours if enabled
      audio_results = generate_audio_tours if @options[:generate_audio]

      {
        city: @city_name,
        locations_created: @locations_created.count,
        audio_tours_generated: audio_results&.dig(:generated) || 0,
        locations: @locations_created.map(&:name)
      }
    end

    # Only generate experiences (using existing locations)
    def generate_experiences_only
      Rails.logger.info "[AI::ExperienceGenerator] Generating experiences for #{@city_name}"

      generate_experiences

      {
        city: @city_name,
        experiences_created: @experiences_created.count,
        experiences: @experiences_created.map(&:title)
      }
    end

    # Generate audio tours for all existing locations in the city
    # @param locale [String] Language code for the tour (default: "bs")
    # @param force [Boolean] Force regeneration even if audio exists
    # @return [Hash] Summary of audio generation results
    def generate_audio_tours_for_city(locale: "bs", force: false)
      Rails.logger.info "[AI::ExperienceGenerator] Generating audio tours for all locations in #{@city_name}"

      locations_with_context = Location.where(city: @city_name).select do |loc|
        loc.translate(:historical_context, locale).present?
      end

      if locations_with_context.empty?
        Rails.logger.info "[AI::ExperienceGenerator] No locations with historical context in #{@city_name}"
        return { generated: 0, skipped: 0, failed: 0, errors: [] }
      end

      AudioTourGenerator.generate_batch(
        locations_with_context,
        locale: locale,
        force: force
      )
    end

    private

    # Get supported locales from database
    def supported_locales
      @supported_locales ||= Locale.ai_supported_codes.presence || %w[en bs hr de es fr it pt nl pl cs sk sl sr]
    end

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

    # Get supported experience types from database
    def supported_experience_types
      @supported_experience_types ||= ExperienceType.active_keys.presence || %w[culture history sport food nature]
    end

    # Get configurable settings
    def geoapify_search_radius
      Setting.get("geoapify.search_radius", default: 15_000)
    end

    def geoapify_max_results
      Setting.get("geoapify.max_results", default: 50)
    end

    def photo_download_timeout
      Setting.get("photo.download_timeout", default: 10)
    end

    def photo_open_timeout
      Setting.get("photo.open_timeout", default: 5)
    end

    def photo_max_size
      Setting.get("photo.max_size", default: 5 * 1024 * 1024)
    end

    def allowed_photo_hosts
      Setting.get("photo.allowed_hosts", default: nil)&.then { |v| JSON.parse(v) rescue nil } ||
        %w[upload.wikimedia.org commons.wikimedia.org api.geoapify.com]
    end

    def fetch_places
      Rails.logger.info "[AI::ExperienceGenerator] Fetching places from Geoapify for #{@city_name}"

      @places_service.search_nearby(
        lat: @coordinates[:lat],
        lng: @coordinates[:lng],
        radius: geoapify_search_radius,
        max_results: geoapify_max_results
      )
    rescue GeoapifyService::ApiError => e
      log_error("Geoapify API error: #{e.message}", exception: e)
      []
    end

    def create_locations_from_places(places)
      Rails.logger.info "[AI::ExperienceGenerator] Creating #{places.count} locations"

      places.each do |place|
        next if place[:name].blank? || place[:lat].blank?

        # Skip if location already exists
        existing = Location.where(city: @city_name)
                          .where("LOWER(name) = ?", place[:name].downcase)
                          .first
        next if existing

        location = create_enriched_location(place)
        @locations_created << location if location
      end
    end

    def create_enriched_location(place)
      # Use AI to enrich the location data
      enrichment = enrich_location_with_ai(place)

      location = Location.new(
        name: place[:name],
        lat: place[:lat],
        lng: place[:lng],
        city: @city_name,
        location_type: determine_location_type(place[:types]),
        budget: place[:price_level] || :medium,
        website: place[:website],
        phone: place[:phone],
        tags: extract_tags(place[:types])
      )

      # Set translations (name, description, historical_context)
      set_location_translations(location, place, enrichment)

      if location.save
        Rails.logger.info "[AI::ExperienceGenerator] Created location: #{location.name}"

        # Add experience types using proper associations
        add_experience_types_to_location(location, enrichment[:suitable_experiences])

        # Attach photos from wiki data if available
        if place[:photos]&.any?
          attach_photo_to_location(location, place[:photos].first)
        end

        location
      else
        Rails.logger.error "[AI::ExperienceGenerator] Failed to create location: #{location.errors.full_messages}"
        nil
      end
    rescue StandardError => e
      log_error("Error creating location #{place[:name]}: #{e.message}", exception: e, place: place[:name])
      nil
    end

    def add_experience_types_to_location(location, experience_type_keys)
      return if experience_type_keys.blank?

      experience_type_keys.each do |key|
        location.add_experience_type(key)
      rescue StandardError => e
        log_warn("Could not add experience type '#{key}' to #{location.name}: #{e.message}", exception: e)
      end
    end

    def enrich_location_with_ai(place)
      prompt = build_location_enrichment_prompt(place)

      response = @chat.with_schema(location_enrichment_schema).ask(prompt)

      # with_schema automatically parses JSON, but content might still be string on error
      result = response.content.is_a?(Hash) ? response.content.deep_symbolize_keys : parse_ai_json_response(response.content)
      result
    rescue StandardError => e
      log_error("AI enrichment failed for #{place[:name]}: #{e.message}", exception: e, place: place[:name])
      { suitable_experiences: [], descriptions: {} }
    end

    # JSON Schema for location enrichment - ensures structured output from AI
    # Note: OpenAI structured output requires additionalProperties: false at all levels
    # and all properties must be listed in required array
    def location_enrichment_schema
      locale_properties = supported_locales.to_h { |loc| [loc, { type: "string" }] }

      {
        type: "object",
        properties: {
          suitable_experiences: {
            type: "array",
            items: { type: "string" },
            description: "Experience types this location is suitable for"
          },
          descriptions: {
            type: "object",
            properties: locale_properties,
            required: supported_locales,
            additionalProperties: false,
            description: "Localized descriptions keyed by locale code (en, bs, hr, etc.)"
          },
          historical_context: {
            type: "object",
            properties: locale_properties,
            required: supported_locales,
            additionalProperties: false,
            description: "Localized historical context for audio narration keyed by locale code"
          }
        },
        required: %w[suitable_experiences descriptions historical_context],
        additionalProperties: false
      }
    end

    def build_location_enrichment_prompt(place)
      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Analyze this place in #{@city_name}, Bosnia and Herzegovina and provide enriched tourism content.

        Place Information:
        - Name: #{place[:name]}
        - City: #{@city_name}
        - Address: #{place[:address]}
        - Type: #{place[:primary_type_display] || place[:primary_type]}
        - Types: #{place[:types]&.join(", ")}
        - Description: #{place[:description]}
        - Rating: #{place[:rating]} (#{place[:rating_count]} reviews)

        Provide a JSON response with:
        1. suitable_experiences: Array of experience types this place is good for. Choose from: #{supported_experience_types.join(", ")}
        2. descriptions: Object with localized descriptions for these languages: #{supported_locales.join(", ")}
        3. historical_context: Object with localized historical/cultural context for the same languages

        IMPORTANT FOR DESCRIPTIONS (write rich, engaging content - 1-2 paragraphs, 100-200 words):
        - Paint a vivid picture that transports the reader to this place
        - Connect this place to Bosnia's rich cultural heritage where relevant
        - Use local Bosnian terminology (with brief explanations for tourists)
        - Highlight what makes this place special in the Bosnian context
        - Include sensory details - what visitors will see, hear, smell, taste
        - If it's a restaurant/cafe, describe the atmosphere and traditional Bosnian dishes or coffee culture
        - If it's a historical site, connect it to Ottoman, Austro-Hungarian, or medieval Bosnian history
        - Write naturally in each language (not just translations)

        IMPORTANT FOR HISTORICAL_CONTEXT (write an essay-style narrative for audio narration - 2-4 paragraphs, 200-400 words):
        - Tell the complete story of this place in an engaging, narrative style
        - Include rich historical details, interesting facts, legends, and local stories
        - Mention specific dates, people, events, and their significance
        - Describe what visitors would have seen here in different eras
        - Explain how this place has evolved through Ottoman, Austro-Hungarian, Yugoslav, and modern periods
        - Connect to broader Bosnian history and culture
        - Make it captivating for audio narration by a tour guide
        - Even for modern places (restaurants, shops), include historical context about the building, neighborhood, or tradition
        - Add personal touches and anecdotes that bring the history to life

        Return ONLY valid JSON, no markdown or explanation:
        {
          "suitable_experiences": ["culture", "history"],
          "descriptions": {
            "en": "Rich English description (1-2 paragraphs, 100-200 words)...",
            "bs": "Bogat bosanski opis (1-2 pasusa, 100-200 riječi)...",
            ...
          },
          "historical_context": {
            "en": "Essay-style historical context for audio narration (2-4 paragraphs, 200-400 words)...",
            "bs": "Esej o historijskom kontekstu za audio naraciju (2-4 pasusa, 200-400 riječi)...",
            ...
          }
        }
      PROMPT
    end

    def set_location_translations(location, place, enrichment)
      # Default description from place data if AI didn't provide
      default_description = place[:description] || "A notable location in #{@city_name}."

      supported_locales.each do |locale|
        description = enrichment.dig(:descriptions, locale.to_s) ||
                     enrichment.dig(:descriptions, locale.to_sym) ||
                     default_description

        location.set_translation(:description, description, locale)

        if (context = enrichment.dig(:historical_context, locale.to_s) || enrichment.dig(:historical_context, locale.to_sym))
          location.set_translation(:historical_context, context, locale)
        end

        # Name is usually not translated, but we could if needed
        location.set_translation(:name, place[:name], locale)
      end
    end

    def determine_location_type(types)
      return :place if types.blank?

      # Get type mapping from settings or use defaults
      type_mapping = Setting.get("location.type_mapping", default: nil)&.then { |v| JSON.parse(v) rescue nil } || {
        "restaurant" => "restaurant",
        "cafe" => "restaurant",
        "bar" => "restaurant",
        "bakery" => "restaurant",
        "lodging" => "accommodation",
        "hotel" => "accommodation",
        "guest_house" => "accommodation"
      }

      types.each do |type|
        return type_mapping[type].to_sym if type_mapping[type]
      end

      :place
    end

    def extract_tags(types)
      return [] if types.blank?

      max_tags = Setting.get("location.max_tags", default: 5)
      types.first(max_tags).map { |t| t.gsub("_", " ") }
    end

    def attach_photo_to_location(location, photo)
      return unless photo

      # Geoapify provides wiki images with direct URLs
      photo_url = photo[:url] || photo[:name]
      return unless photo_url.present?

      # Security: Validate URL before downloading
      unless valid_photo_url?(photo_url)
        Rails.logger.warn "[AI::ExperienceGenerator] Invalid or disallowed photo URL for #{location.name}: #{photo_url}"
        return
      end

      # Download photo using Faraday with timeout and size limits
      downloaded_file = download_photo_safely(photo_url)
      return unless downloaded_file

      location.photos.attach(
        io: downloaded_file,
        filename: "#{location.name.parameterize}-photo.jpg",
        content_type: downloaded_file.content_type || "image/jpeg"
      )
    rescue StandardError => e
      log_warn("Failed to attach photo for #{location.name}: #{e.message}", exception: e)
    end

    def valid_photo_url?(url)
      uri = URI.parse(url)

      # Only allow https (or http for local dev)
      return false unless %w[https http].include?(uri.scheme)

      # Check against allowed hosts
      allowed_photo_hosts.any? { |host| uri.host&.end_with?(host) }
    rescue URI::InvalidURIError
      false
    end

    def download_photo_safely(url)
      connection = Faraday.new do |faraday|
        faraday.options.timeout = photo_download_timeout
        faraday.options.open_timeout = photo_open_timeout
        faraday.adapter Faraday.default_adapter
      end

      response = connection.get(url)

      return nil unless response.success?

      # Validate content type
      content_type = response.headers["content-type"]
      unless content_type&.start_with?("image/")
        Rails.logger.warn "[AI::ExperienceGenerator] Invalid content type: #{content_type}"
        return nil
      end

      # Limit file size
      if response.body.bytesize > photo_max_size
        Rails.logger.warn "[AI::ExperienceGenerator] Photo too large: #{response.body.bytesize} bytes"
        return nil
      end

      # Return a StringIO with content_type accessor
      file = StringIO.new(response.body)
      file.define_singleton_method(:content_type) { content_type }
      file
    rescue Faraday::Error => e
      log_warn("Failed to download photo: #{e.message}", exception: e, url: url)
      nil
    end

    def generate_experiences
      Rails.logger.info "[AI::ExperienceGenerator] Generating experiences for #{@city_name}"

      city_locations = Location.where(city: @city_name).with_coordinates.includes(:experience_types)

      return if city_locations.empty?

      # Generate experiences for each category from database
      experience_categories.each do |category_data|
        # Find the ExperienceCategory record
        category_record = ExperienceCategory.find_by(key: category_data[:key])

        matching_locations = city_locations.select do |loc|
          (loc.suitable_experiences & category_data[:experiences]).any?
        end

        min_locations = Setting.get("experience.min_locations", default: 1)
        next if matching_locations.count < min_locations

        experience = create_ai_experience(category_data, category_record, matching_locations)
        @experiences_created << experience if experience
      end
    end

    # Generate audio tours for newly created locations
    # @return [Hash] Summary of audio generation results
    def generate_audio_tours
      locations_for_audio = @locations_created.select do |loc|
        # Only generate audio for locations with historical context
        loc.translate(:historical_context, @options[:audio_locale]).present?
      end

      if locations_for_audio.empty?
        Rails.logger.info "[AI::ExperienceGenerator] No locations with historical context for audio generation"
        return { generated: 0, skipped: 0, failed: 0, errors: [] }
      end

      Rails.logger.info "[AI::ExperienceGenerator] Generating audio tours for #{locations_for_audio.count} locations"

      AudioTourGenerator.generate_batch(
        locations_for_audio,
        locale: @options[:audio_locale],
        force: false
      )
    end

    def create_ai_experience(category_data, category_record, locations)
      # Use AI to create the experience
      experience_data = generate_experience_with_ai(category_data, locations)

      experience = Experience.new(
        estimated_duration: category_data[:duration],
        experience_category: category_record
      )

      # Set translations
      supported_locales.each do |locale|
        title = experience_data.dig(:titles, locale.to_s) ||
               experience_data.dig(:titles, locale.to_sym) ||
               "#{category_data[:key].to_s.titleize} in #{@city_name}"

        description = experience_data.dig(:descriptions, locale.to_s) ||
                     experience_data.dig(:descriptions, locale.to_sym) ||
                     "Explore #{category_data[:key].to_s.humanize.downcase} in #{@city_name}."

        experience.set_translation(:title, title, locale)
        experience.set_translation(:description, description, locale)
      end

      if experience.save
        # Add locations to experience in the recommended order
        selected_locations = select_experience_locations(experience_data, locations)

        selected_locations.each_with_index do |loc, index|
          experience.add_location(loc, position: index + 1)
        end

        # Attach cover photo from the first location that has photos
        attach_cover_photo_to_experience(experience, selected_locations)

        Rails.logger.info "[AI::ExperienceGenerator] Created experience: #{experience.title} with #{selected_locations.count} locations"
        experience
      else
        Rails.logger.error "[AI::ExperienceGenerator] Failed to create experience: #{experience.errors.full_messages}"
        nil
      end
    rescue StandardError => e
      log_error("Error creating experience: #{e.message}", exception: e)
      nil
    end

    def select_experience_locations(experience_data, locations)
      max_locations = Setting.get("experience.max_locations", default: 5)

      # Try to use AI-recommended location IDs
      if experience_data[:location_ids].present?
        selected = experience_data[:location_ids].filter_map { |id| Location.find_by(id: id) }
        return selected if selected.any?
      end

      # Fallback to random selection
      locations.sample([ locations.count, max_locations ].min)
    end

    def attach_cover_photo_to_experience(experience, locations)
      # Find the first location with photos
      location_with_photo = locations.find { |loc| loc.photos.attached? }
      return unless location_with_photo

      # Copy the first photo from the location to the experience
      source_photo = location_with_photo.photos.first
      return unless source_photo

      experience.cover_photo.attach(
        io: StringIO.new(source_photo.download),
        filename: "experience-#{experience.id}-cover#{File.extname(source_photo.filename.to_s)}",
        content_type: source_photo.content_type
      )

      log_info("Attached cover photo to experience: #{experience.title}")
    rescue StandardError => e
      log_warn("Could not attach cover photo: #{e.message}", exception: e)
    end

    def generate_experience_with_ai(category_data, locations)
      prompt = build_experience_prompt(category_data, locations)

      response = @chat.with_schema(experience_generation_schema).ask(prompt)

      # with_schema automatically parses JSON, but content might still be string on error
      result = response.content.is_a?(Hash) ? response.content.deep_symbolize_keys : parse_ai_json_response(response.content)
      result
    rescue StandardError => e
      log_error("AI experience generation failed: #{e.message}", exception: e)
      { titles: {}, descriptions: {}, location_ids: [] }
    end

    # JSON Schema for experience generation - ensures structured output from AI
    # Note: OpenAI structured output requires additionalProperties: false at all levels
    # and all properties must be listed in required array
    def experience_generation_schema
      locale_properties = supported_locales.to_h { |loc| [loc, { type: "string" }] }

      {
        type: "object",
        properties: {
          titles: {
            type: "object",
            properties: locale_properties,
            required: supported_locales,
            additionalProperties: false,
            description: "Localized experience titles keyed by locale code (en, bs, hr, etc.)"
          },
          descriptions: {
            type: "object",
            properties: locale_properties,
            required: supported_locales,
            additionalProperties: false,
            description: "Localized experience descriptions keyed by locale code"
          },
          location_ids: {
            type: "array",
            items: { type: "integer" },
            description: "Array of location IDs to include in the experience"
          },
          route_narrative: {
            type: "string",
            description: "Brief explanation of how the locations connect thematically and geographically"
          }
        },
        required: %w[titles descriptions location_ids route_narrative],
        additionalProperties: false
      }
    end

    def build_experience_prompt(category_data, locations)
      locations_info = locations.map do |loc|
        description = loc.translate(:description, :bs).presence || loc.translate(:description, :en)
        historical = loc.translate(:historical_context, :bs).presence || loc.translate(:historical_context, :en)

        info = "- ID: #{loc.id}\n"
        info += "  Name: #{loc.name}\n"
        info += "  Type: #{loc.location_type}\n"
        info += "  Experience Types: #{loc.experience_types.pluck(:key).join(", ")}\n"
        info += "  Description: #{description.to_s.truncate(200)}\n" if description.present?
        info += "  Historical Context: #{historical.to_s.truncate(200)}\n" if historical.present?
        info += "  Coordinates: #{loc.lat}, #{loc.lng}"
        info
      end.join("\n\n")

      locale_examples = supported_locales.map do |locale|
        %("#{locale}": "Title in #{locale}")
      end.join(",\n            ")

      <<~PROMPT
        #{BIH_CULTURAL_CONTEXT}

        ---

        TASK: Create a curated tourism experience for travelers visiting #{@city_name}, Bosnia and Herzegovina.

        Experience Category: #{category_data[:key].to_s.titleize}
        Target Activities: #{category_data[:experiences].join(", ")}
        Estimated Duration: #{category_data[:duration]} minutes

        Available Locations in #{@city_name}:
        #{locations_info}

        EXPERIENCE CREATION GUIDELINES:

        1. THEME & NARRATIVE:
           - Create a compelling theme that connects the locations through Bosnian culture and heritage
           - Tell a story that flows naturally from one location to the next
           - Connect to Bosnia's Ottoman, Austro-Hungarian, or medieval heritage where relevant

        2. ROUTE PLANNING:
           - Consider geographical proximity (use coordinates) for a logical walking/driving route
           - Start and end points should be convenient for tourists
           - Select 3-5 locations that work best together

        3. TITLES (must capture the Bosnian spirit):
           - Bosnian (bs): Use authentic local names (e.g., "Tragovima Sevdaha", "Čaršijska Šetnja", "Ukus Bosne")
           - Other languages: Translate the meaning while keeping key Bosnian terms (čaršija, sevdah, ćevapi, etc.)
           - Make titles poetic and memorable, NOT generic like "Cultural Tour" or "City Walk"

        4. DESCRIPTIONS (write rich, engaging content - 1-2 paragraphs, 100-200 words per language):
           - Paint a vivid picture of the journey visitors will experience
           - Capture the essence of what makes this experience uniquely Bosnian
           - Describe the atmosphere, sights, sounds, and emotions visitors will encounter
           - Mention specific highlights and unforgettable moments
           - Create anticipation and emotional connection
           - Tell a mini-story about what awaits the traveler

        Return ONLY valid JSON:
        {
          "titles": {
            #{locale_examples}
          },
          "descriptions": {
            "en": "Engaging description that captures the essence of this Bosnian experience...",
            "bs": "Opis koji hvata suštinu ovog bosanskog iskustva...",
            ...
          },
          "location_ids": [1, 2, 3],
          "route_narrative": "Brief explanation of how the locations connect thematically and geographically"
        }

        Write naturally in each language - not just translations. Each language should feel native.
      PROMPT
    end

    def parse_ai_json_response(content)
      # Extract JSON from response (handle markdown code blocks)
      json_match = content.match(/```(?:json)?\s*([\s\S]*?)```/) ||
                  content.match(/(\{[\s\S]*\})/)

      json_str = json_match ? json_match[1] : content
      json_str = sanitize_ai_json(json_str)

      JSON.parse(json_str, symbolize_names: true)
    rescue JSON::ParserError => e
      log_error("Failed to parse AI response: #{e.message}", exception: e, content: content.to_s.truncate(500))
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
  end
end
