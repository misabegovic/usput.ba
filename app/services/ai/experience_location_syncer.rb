# frozen_string_literal: true

module Ai
  # Syncs locations mentioned in experience descriptions with actual location records
  # Identifies locations mentioned in the description that aren't already connected,
  # finds them in the database or creates them via Geoapify, and connects them to the experience
  #
  # Usage:
  #   syncer = Ai::ExperienceLocationSyncer.new
  #   result = syncer.sync_locations(experience)
  #   # => { locations_added: 2, locations_found_in_db: 1, locations_created: 1, errors: [] }
  class ExperienceLocationSyncer
    include Concerns::ErrorReporting

    class SyncError < StandardError; end

    # Minimum confidence score for location extraction (0.0 - 1.0)
    MIN_CONFIDENCE = 0.6

    def initialize
      @geoapify = GeoapifyService.new
    end

    # Sync locations mentioned in the experience description
    # @param experience [Experience] The experience to sync locations for
    # @param dry_run [Boolean] If true, just analyze but don't make changes
    # @return [Hash] Results of the sync operation
    def sync_locations(experience, dry_run: false)
      results = {
        experience_id: experience.id,
        experience_title: experience.title,
        locations_analyzed: 0,
        locations_already_connected: 0,
        locations_added: 0,
        locations_found_in_db: 0,
        locations_created_via_geoapify: 0,
        locations_not_found: 0,
        dry_run: dry_run,
        errors: [],
        details: []
      }

      # Get the experience's description (prefer English, fallback to Bosnian)
      description = experience.translation_for(:description, :en).presence ||
                    experience.translation_for(:description, :bs).presence ||
                    experience.description.to_s

      if description.blank?
        log_info "Experience #{experience.id} has no description to analyze"
        return results
      end

      # Get the experience's primary city for location search context
      primary_city = experience.city
      all_cities = experience.cities

      # Extract location names from the description using AI
      extracted_locations = extract_locations_from_description(description, primary_city)
      results[:locations_analyzed] = extracted_locations.count

      log_info "Extracted #{extracted_locations.count} potential locations from experience #{experience.id}"

      # Get currently connected location names (normalized for comparison)
      connected_location_names = experience.locations.pluck(:name).map { |n| normalize_name(n) }

      # Process each extracted location
      extracted_locations.each do |loc_data|
        location_name = loc_data[:name]
        confidence = loc_data[:confidence] || 1.0
        normalized_name = normalize_name(location_name)

        # Skip if already connected
        if connected_location_names.include?(normalized_name)
          results[:locations_already_connected] += 1
          results[:details] << { name: location_name, status: :already_connected }
          next
        end

        # Skip low confidence extractions
        if confidence < MIN_CONFIDENCE
          results[:details] << { name: location_name, status: :low_confidence, confidence: confidence }
          next
        end

        begin
          # Try to find or create the location
          location, source = find_or_create_location(
            name: location_name,
            city: loc_data[:city] || primary_city,
            all_cities: all_cities,
            context: loc_data[:context]
          )

          if location
            unless dry_run
              # Add location to experience at the end
              max_position = experience.experience_locations.maximum(:position) || 0
              experience.add_location(location, position: max_position + 1)
            end

            results[:locations_added] += 1
            if source == :database
              results[:locations_found_in_db] += 1
            else
              results[:locations_created_via_geoapify] += 1
            end

            results[:details] << {
              name: location_name,
              status: :added,
              source: source,
              location_id: location.id
            }

            log_info "#{dry_run ? '[DRY RUN] Would add' : 'Added'} location '#{location.name}' to experience #{experience.id}"
          else
            results[:locations_not_found] += 1
            results[:details] << { name: location_name, status: :not_found }
            log_warn "Could not find or create location '#{location_name}' for experience #{experience.id}"
          end
        rescue StandardError => e
          results[:errors] << { name: location_name, error: e.message }
          log_error "Error processing location '#{location_name}': #{e.message}"
        end
      end

      log_info "Sync complete for experience #{experience.id}: #{results[:locations_added]} locations added"
      results
    end

    # Sync locations for multiple experiences
    # @param experiences [Array<Experience>] Experiences to sync
    # @param dry_run [Boolean] If true, just analyze but don't make changes
    # @return [Hash] Aggregated results
    def sync_all(experiences, dry_run: false)
      total_results = {
        experiences_processed: 0,
        total_locations_added: 0,
        total_locations_found_in_db: 0,
        total_locations_created: 0,
        total_locations_not_found: 0,
        total_errors: 0,
        dry_run: dry_run,
        details: []
      }

      experiences.each do |experience|
        result = sync_locations(experience, dry_run: dry_run)

        total_results[:experiences_processed] += 1
        total_results[:total_locations_added] += result[:locations_added]
        total_results[:total_locations_found_in_db] += result[:locations_found_in_db]
        total_results[:total_locations_created] += result[:locations_created_via_geoapify]
        total_results[:total_locations_not_found] += result[:locations_not_found]
        total_results[:total_errors] += result[:errors].count
        total_results[:details] << result
      end

      total_results
    end

    private

    # Extract location names from a description using AI
    # @param description [String] The experience description to analyze
    # @param primary_city [String] The primary city context
    # @return [Array<Hash>] Array of extracted locations with name, confidence, and context
    def extract_locations_from_description(description, primary_city)
      prompt = build_extraction_prompt(description, primary_city)

      result = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: extraction_schema,
        context: "ExperienceLocationSyncer:extract"
      )

      locations = result&.dig(:locations) || []

      # Filter and validate extracted locations
      locations.select do |loc|
        loc[:name].present? &&
          loc[:name].length >= 3 &&
          !generic_location_name?(loc[:name])
      end
    rescue Ai::OpenaiQueue::RequestError => e
      log_warn "AI location extraction failed: #{e.message}"
      []
    end

    # Build the prompt for location extraction
    def build_extraction_prompt(description, primary_city)
      <<~PROMPT
        TASK: Extract specific location/place names mentioned in this tourism experience description.

        DESCRIPTION:
        #{description}

        PRIMARY CITY CONTEXT: #{primary_city || 'Unknown'}

        INSTRUCTIONS:
        1. Identify SPECIFIC named places mentioned in the description:
           - Monuments, landmarks, buildings (e.g., "Baščaršija", "Stari Most", "Gazi Husrev-begova džamija")
           - Museums, galleries (e.g., "Historijski muzej", "Galerija 11/07/95")
           - Natural sites (e.g., "Vrelo Bosne", "Trebević", "Skakavac waterfall")
           - Restaurants, cafes with specific names (e.g., "Čajdžinica Džirlo", "Park Princeva")
           - Streets, squares with proper names (e.g., "Ferhadija", "Trg oslobođenja")
           - Other notable places (e.g., "Avaz Twist Tower", "Vijećnica")

        2. DO NOT include:
           - Generic terms (e.g., "the old town", "a mosque", "the river")
           - Directions or vague references (e.g., "nearby", "in the center")
           - Categories without specific names (e.g., "traditional restaurants", "local cafes")
           - City names alone (we already know the city context)

        3. For each location, provide:
           - name: The exact name as it would appear on a map or in local usage
           - confidence: How confident you are this is a specific, real place (0.0-1.0)
           - city: Which city this location is in (if mentioned or inferrable)
           - context: Brief note about what type of place this is

        Return ONLY specific, identifiable places that a tourist could find and visit.
      PROMPT
    end

    # JSON Schema for location extraction
    def extraction_schema
      {
        type: "object",
        properties: {
          locations: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                confidence: { type: "number" },
                city: { type: "string" },
                context: { type: "string" }
              },
              required: %w[name confidence],
              additionalProperties: false
            }
          }
        },
        required: ["locations"],
        additionalProperties: false
      }
    end

    # Find an existing location in the database or create one via Geoapify
    # @param name [String] Location name to find
    # @param city [String] Primary city to search in
    # @param all_cities [Array<String>] All cities in the experience
    # @param context [String] Context about the location type
    # @return [Array(Location, Symbol)] Tuple of [location, source] or [nil, nil]
    def find_or_create_location(name:, city:, all_cities:, context:)
      # First, try to find in database by name match
      location = find_location_in_database(name, city, all_cities)
      return [location, :database] if location

      # If not found, try to find via Geoapify and create
      location = create_location_via_geoapify(name, city, context)
      return [location, :geoapify] if location

      [nil, nil]
    end

    # Search for a location in the database
    # @param name [String] Location name to find
    # @param city [String] Primary city
    # @param all_cities [Array<String>] All cities to search in
    # @return [Location, nil] Found location or nil
    def find_location_in_database(name, city, all_cities)
      normalized_name = normalize_name(name)

      # Try exact match first (case-insensitive)
      query = Location.where("LOWER(name) = ?", normalized_name.downcase)
      query = query.where(city: all_cities) if all_cities.present?
      location = query.first
      return location if location

      # Try partial match (name contains the search term)
      query = Location.where("LOWER(name) LIKE ?", "%#{normalized_name.downcase}%")
      query = query.where(city: all_cities) if all_cities.present?
      location = query.first
      return location if location

      # Try searching in translations
      if defined?(Translation)
        translation = Translation.where(
          translatable_type: "Location",
          key: "name"
        ).where("LOWER(value) LIKE ?", "%#{normalized_name.downcase}%").first

        if translation
          location = Location.find_by(id: translation.translatable_id)
          return location if location && (all_cities.blank? || all_cities.include?(location.city))
        end
      end

      nil
    end

    # Create a location via Geoapify search
    # @param name [String] Location name to search for
    # @param city [String] City to search in
    # @param context [String] Context about the location type
    # @return [Location, nil] Created location or nil
    def create_location_via_geoapify(name, city, context)
      # Get city coordinates for location bias
      city_coords = get_city_coordinates(city)

      # Search for the location via Geoapify
      search_query = city.present? ? "#{name}, #{city}, Bosnia and Herzegovina" : "#{name}, Bosnia and Herzegovina"

      results = @geoapify.text_search(
        query: search_query,
        lat: city_coords&.dig(:lat),
        lng: city_coords&.dig(:lng),
        radius: 50_000, # 50km radius
        max_results: 5
      )

      return nil if results.blank?

      # Find the best matching result
      best_result = find_best_match(results, name, city)
      return nil unless best_result

      # Verify the location is in Bosnia and Herzegovina
      return nil unless location_in_bih?(best_result)

      # Create the location
      create_location_from_geoapify(best_result, context)
    rescue GeoapifyService::ApiError => e
      log_warn "Geoapify search failed for '#{name}': #{e.message}"
      nil
    end

    # Get coordinates for a city
    # @param city [String] City name
    # @return [Hash, nil] Hash with :lat and :lng or nil
    def get_city_coordinates(city)
      return nil if city.blank?

      # Try to find a location in this city to get coordinates
      location = Location.where(city: city).with_coordinates.first
      return { lat: location.lat, lng: location.lng } if location

      # Fallback: Use Geoapify to geocode the city
      results = @geoapify.text_search(query: "#{city}, Bosnia and Herzegovina", max_results: 1)
      return nil if results.blank?

      result = results.first
      { lat: result[:lat], lng: result[:lng] } if result[:lat] && result[:lng]
    rescue StandardError
      nil
    end

    # Find the best matching result from Geoapify search
    # @param results [Array<Hash>] Geoapify search results
    # @param name [String] Original location name
    # @param city [String] Expected city
    # @return [Hash, nil] Best matching result or nil
    def find_best_match(results, name, city)
      normalized_name = normalize_name(name)

      # Score each result
      scored_results = results.map do |result|
        score = 0
        result_name = normalize_name(result[:name].to_s)

        # Exact name match
        score += 100 if result_name == normalized_name

        # Partial name match
        score += 50 if result_name.include?(normalized_name) || normalized_name.include?(result_name)

        # City match
        if city.present? && result[:address].to_s.downcase.include?(city.downcase)
          score += 30
        end

        # Has coordinates
        score += 10 if result[:lat].present? && result[:lng].present?

        { result: result, score: score }
      end

      # Get the highest scoring result that meets minimum threshold
      best = scored_results.max_by { |r| r[:score] }
      return nil unless best && best[:score] >= 50

      best[:result]
    end

    # Check if a location is within Bosnia and Herzegovina
    # Uses polygon-based border validation if available
    # @param geoapify_result [Hash] Geoapify search result
    # @return [Boolean] True if location is in BiH
    def location_in_bih?(geoapify_result)
      lat = geoapify_result[:lat]
      lng = geoapify_result[:lng]

      return false unless lat && lng

      # Use BiH border validator if available
      if defined?(BihBorderValidator)
        return BihBorderValidator.point_in_bih?(lat, lng)
      end

      # Fallback: Simple bounding box check for Bosnia and Herzegovina
      # Approximate bounds: lat 42.5-45.3, lng 15.7-19.6
      lat >= 42.5 && lat <= 45.3 && lng >= 15.7 && lng <= 19.6
    end

    # Create a Location record from Geoapify result
    # @param geoapify_result [Hash] Geoapify search result
    # @param context [String] Context about the location
    # @return [Location, nil] Created location or nil
    def create_location_from_geoapify(geoapify_result, context)
      return nil unless geoapify_result[:lat] && geoapify_result[:lng]

      # Check if location already exists at these coordinates
      existing = Location.find_by(lat: geoapify_result[:lat], lng: geoapify_result[:lng])
      return existing if existing

      # Get city from coordinates if not in the result
      city = extract_city_from_address(geoapify_result[:address]) ||
             @geoapify.get_city_from_coordinates(geoapify_result[:lat], geoapify_result[:lng])

      # Create the location
      location = Location.new(
        name: geoapify_result[:name],
        lat: geoapify_result[:lat],
        lng: geoapify_result[:lng],
        city: city,
        ai_generated: true
      )

      # Add description if context is available
      if context.present?
        location.description = context
      end

      # Add website and phone if available
      location.website = geoapify_result[:website] if geoapify_result[:website].present?
      location.phone = geoapify_result[:phone] if geoapify_result[:phone].present?

      if location.save
        log_info "Created new location '#{location.name}' in #{location.city} via Geoapify"
        location
      else
        log_error "Failed to create location: #{location.errors.full_messages.join(', ')}"
        nil
      end
    rescue StandardError => e
      log_error "Error creating location from Geoapify: #{e.message}"
      nil
    end

    # Extract city name from an address string
    # @param address [String] Full address string
    # @return [String, nil] City name or nil
    def extract_city_from_address(address)
      return nil if address.blank?

      # Common BiH cities to look for
      bih_cities = %w[
        Sarajevo Mostar Banja\ Luka Tuzla Zenica Bijeljina Bihać Brčko
        Trebinje Prijedor Doboj Cazin Konjic Livno Gradačac Gračanica
        Visoko Goražde Bugojno Travnik Jajce Srebrenica Stolac Neum
        Vogošća Ilidža Hadžići Novi\ Grad
      ]

      bih_cities.find { |city| address.include?(city) }
    end

    # Normalize a location name for comparison
    # @param name [String] Location name
    # @return [String] Normalized name
    def normalize_name(name)
      name.to_s
          .strip
          .gsub(/\s+/, " ")
          .gsub(/[„""'']/u, '"')
    end

    # Check if a location name is too generic
    # @param name [String] Location name
    # @return [Boolean] True if name is generic
    def generic_location_name?(name)
      generic_patterns = [
        /^the\s/i,
        /^a\s/i,
        /^an\s/i,
        /^some\s/i,
        /\brestaurant$/i,
        /\bcafe$/i,
        /\bmuseum$/i,
        /\bpark$/i,
        /\bchurch$/i,
        /\bmosque$/i,
        /^old\stown$/i,
        /^city\scenter$/i,
        /^downtown$/i,
        /^centar$/i
      ]

      name_lower = name.to_s.downcase.strip

      # Too short
      return true if name_lower.length < 3

      # Matches generic patterns
      return true if generic_patterns.any? { |pattern| name_lower.match?(pattern) }

      # Is just a city name
      bih_cities = %w[sarajevo mostar banja\ luka tuzla zenica bijeljina bihać brčko trebinje]
      return true if bih_cities.include?(name_lower)

      false
    end
  end
end
