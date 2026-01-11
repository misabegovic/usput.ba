# frozen_string_literal: true

module Ai
  # Obogaćuje lokaciju sa AI-generisanim sadržajem
  # Koristi postojeća polja Location modela bez migracija
  class LocationEnricher
    include Concerns::ErrorReporting

    class EnrichmentError < StandardError; end

    # Maximum locales per batch to avoid token limit errors
    # We split descriptions and historical_context into separate requests,
    # and process locales in batches to stay well under 128K token limit
    LOCALES_PER_DESCRIPTION_BATCH = 5  # ~150 words each = ~750 words output
    LOCALES_PER_HISTORY_BATCH = 3      # ~300 words each = ~900 words output

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
        ai_generated: true  # Explicitly mark as AI-generated
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
      combined_result = { suitable_experiences: [], descriptions: {}, historical_context: {}, tags: [], practical_info: {} }

      # Step 1: Generate metadata (suitable_experiences, tags, practical_info) - single request
      log_info "Generating metadata for #{location.name}"
      metadata = generate_metadata(location, place_data)
      if metadata.present?
        combined_result[:suitable_experiences] = metadata[:suitable_experiences] || []
        combined_result[:tags] = metadata[:tags] || []
        combined_result[:practical_info] = metadata[:practical_info] || {}
      end

      # Step 2: Generate descriptions in batches
      description_batches = supported_locales.each_slice(LOCALES_PER_DESCRIPTION_BATCH).to_a
      description_batches.each_with_index do |batch_locales, batch_index|
        log_info "Generating descriptions batch #{batch_index + 1}/#{description_batches.count} for #{location.name}: #{batch_locales.join(', ')}"

        descriptions = generate_descriptions(location, place_data, batch_locales)
        combined_result[:descriptions].merge!(descriptions) if descriptions.present?
      end

      # Step 3: Generate historical_context in batches
      history_batches = supported_locales.each_slice(LOCALES_PER_HISTORY_BATCH).to_a
      history_batches.each_with_index do |batch_locales, batch_index|
        log_info "Generating historical context batch #{batch_index + 1}/#{history_batches.count} for #{location.name}: #{batch_locales.join(', ')}"

        history = generate_historical_context(location, place_data, batch_locales)
        combined_result[:historical_context].merge!(history) if history.present?
      end

      combined_result
    rescue Ai::OpenaiQueue::RequestError => e
      log_warn "AI enrichment failed for #{location.name}: #{e.message}"
      {}
    end

    def generate_metadata(location, place_data)
      prompt = build_metadata_prompt(location, place_data)
      Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: metadata_schema,
        context: "LocationEnricher:metadata:#{location.name}"
      )
    rescue Ai::OpenaiQueue::RequestError => e
      log_warn "Metadata generation failed for #{location.name}: #{e.message}"
      {}
    end

    def generate_descriptions(location, place_data, locales)
      prompt = build_descriptions_prompt(location, place_data, locales)
      result = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: descriptions_schema(locales),
        context: "LocationEnricher:descriptions:#{location.name}"
      )
      result&.dig(:descriptions) || {}
    rescue Ai::OpenaiQueue::RequestError => e
      log_warn "Descriptions generation failed for #{location.name}: #{e.message}"
      {}
    end

    def generate_historical_context(location, place_data, locales)
      prompt = build_historical_context_prompt(location, place_data, locales)
      result = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: historical_context_schema(locales),
        context: "LocationEnricher:history:#{location.name}"
      )
      result&.dig(:historical_context) || {}
    rescue Ai::OpenaiQueue::RequestError => e
      log_warn "Historical context generation failed for #{location.name}: #{e.message}"
      {}
    end

    # Schema for metadata only (suitable_experiences, tags, practical_info)
    def metadata_schema
      {
        type: "object",
        properties: {
          suitable_experiences: {
            type: "array",
            items: { type: "string" },
            description: "Experience types this location is suitable for"
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "Relevant tags in English (lowercase, hyphens instead of spaces)"
          },
          practical_info: {
            type: "object",
            properties: {
              best_time: { type: "string", description: "Best time to visit (morning, afternoon, evening, any)" },
              duration_minutes: { type: "integer", description: "Suggested visit duration in minutes" },
              tips: { type: "array", items: { type: "string" }, description: "Practical tips for visitors" }
            },
            required: %w[best_time duration_minutes tips],
            additionalProperties: false
          }
        },
        required: %w[suitable_experiences tags practical_info],
        additionalProperties: false
      }
    end

    # Schema for descriptions only
    def descriptions_schema(locales)
      locale_properties = locales.to_h { |loc| [loc, { type: "string" }] }
      {
        type: "object",
        properties: {
          descriptions: {
            type: "object",
            properties: locale_properties,
            required: locales,
            additionalProperties: false
          }
        },
        required: %w[descriptions],
        additionalProperties: false
      }
    end

    # Schema for historical context only
    def historical_context_schema(locales)
      locale_properties = locales.to_h { |loc| [loc, { type: "string" }] }
      {
        type: "object",
        properties: {
          historical_context: {
            type: "object",
            properties: locale_properties,
            required: locales,
            additionalProperties: false
          }
        },
        required: %w[historical_context],
        additionalProperties: false
      }
    end

    def location_info_block(location, place_data)
      <<~INFO
        LOCATION INFORMATION:
        - Name: #{location.name}
        - City: #{location.city}
        - Type: #{place_data[:categories]&.first || location.location_type}
        - Categories: #{place_data[:categories]&.join(', ')}
        - Address: #{place_data[:formatted] || place_data[:address_line1]}
        - Coordinates: #{location.lat}, #{location.lng}
      INFO
    end

    def build_metadata_prompt(location, place_data)
      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Provide metadata for this tourism location in #{location.city}.

        #{location_info_block(location, place_data)}

        Provide a JSON response with:

        1. suitable_experiences: Array of experience types this place is good for
           Choose from: #{supported_experience_types.join(', ')}

        2. tags: Array of 3-5 relevant tags in English (lowercase, no spaces - use hyphens)
           Examples: historical-site, ottoman-heritage, local-cuisine, scenic-view

        3. practical_info: Object with practical information for tourists
           - best_time: Best time to visit (morning, afternoon, evening, any)
           - duration_minutes: Suggested visit duration in minutes
           - tips: Array of 3-5 practical tips for visitors
      PROMPT
    end

    def build_descriptions_prompt(location, place_data, locales)
      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Write engaging descriptions for this tourism location in #{location.city}.

        #{location_info_block(location, place_data)}

        Write descriptions in these languages: #{locales.join(', ')}

        For each language, write a rich, engaging description (1-2 paragraphs, around 100-150 words):
        - Paint a vivid picture of what makes this place special
        - Connect to local culture and heritage where relevant
        - Use local terminology with brief explanations
        - Include sensory details and atmosphere
        - Write naturally in each target language (not just translations)

        Return JSON with a "descriptions" object containing each locale code as a key.
      PROMPT
    end

    def build_historical_context_prompt(location, place_data, locales)
      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Write historical/cultural context for audio narration at this tourism location in #{location.city}.

        #{location_info_block(location, place_data)}

        Write historical context in these languages: #{locales.join(', ')}

        For each language, write an engaging essay-style narrative (2-3 paragraphs, around 200-300 words):
        - Tell the complete story of this place with rich historical details
        - Include interesting facts, legends, local stories, and anecdotes
        - Mention specific dates, people, events, and their significance
        - Describe how this place has evolved through different eras
        - Make it engaging and captivating for audio narration
        - Write naturally in each target language (not just translations)

        Return JSON with a "historical_context" object containing each locale code as a key.
      PROMPT
    end

    def apply_enrichment(location, enrichment)
      # Set translations for description and historical_context
      supported_locales.each do |locale|
        if (desc = enrichment.dig(:descriptions, locale.to_s) || enrichment.dig(:descriptions, locale.to_sym))
          location.set_translation(:description, desc, locale)
        end

        if (context = enrichment.dig(:historical_context, locale.to_s) || enrichment.dig(:historical_context, locale.to_sym))
          location.set_translation(:historical_context, context, locale)
        end

        # Set name translation (usually same as original)
        location.set_translation(:name, location.name, locale)
      end

      # Set suitable_experiences
      if enrichment[:suitable_experiences].present?
        location.suitable_experiences = enrichment[:suitable_experiences]

        # Also add through associations
        enrichment[:suitable_experiences].each do |exp_key|
          location.add_experience_type(exp_key)
        rescue StandardError => e
          log_warn "Could not add experience type '#{exp_key}': #{e.message}"
        end
      end

      # Set tags
      if enrichment[:tags].present?
        location.tags = (location.tags + enrichment[:tags]).uniq
      end

      # Store practical info in audio_tour_metadata (existing JSONB field)
      if enrichment[:practical_info].present?
        location.audio_tour_metadata ||= {}
        location.audio_tour_metadata = location.audio_tour_metadata.merge(
          "practical_info" => enrichment[:practical_info]
        )
      end
    end

    def add_tags_from_categories(location, categories)
      return if categories.blank?

      # Convert Geoapify categories to tags
      category_tags = categories.map do |cat|
        cat.to_s.split('.').last.gsub('_', '-')
      end.uniq.first(3)

      location.tags = (location.tags + category_tags).uniq
      location.save
    end

    def determine_location_type(categories)
      return :place if categories.blank?

      category_str = categories.join(' ')

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
      str.gsub(/[\x00]/, '').gsub(/[\x01-\x08\x0B\x0C\x0E-\x1F]/, '')
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
      Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT
    end

    def supported_locales
      @supported_locales ||= Locale.ai_supported_codes.presence ||
        %w[en bs hr de es fr it pt nl pl cs sk sl sr]
    end

    def supported_experience_types
      @supported_experience_types ||= ExperienceType.active_keys.presence ||
        %w[culture history sport food nature adventure relaxation]
    end

    def parse_ai_json_response(content)
      json_match = content.match(/```(?:json)?\s*([\s\S]*?)```/) ||
                  content.match(/(\{[\s\S]*\})/)
      json_str = json_match ? json_match[1] : content
      json_str = sanitize_ai_json(json_str)
      # Final cleanup: strip any trailing comma that might remain after sanitization
      json_str = json_str.strip.sub(/,\s*\z/, '')
      JSON.parse(json_str, symbolize_names: true)
    rescue JSON::ParserError => e
      log_error "Failed to parse AI response: #{e.message}"
      {}
    end

    def sanitize_ai_json(json_str)
      json_str = json_str.dup
      # Replace smart/curly quotes with straight quotes
      json_str.gsub!(/[""]/, '"')
      json_str.gsub!(/['']/, "'")
      # Remove trailing commas (invalid JSON but common in AI output)
      json_str.gsub!(/,(\s*[\}\]])/, '\1')
      # Remove trailing comma at end of stream (e.g., "{ ... },\n" or "{ ... }, ")
      json_str.gsub!(/,\s*\z/, '')
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
      # Note: We check for `: "` (colon then quote) separately to avoid false positives
      # when text contains quotes followed by colons like: "Unity": our strength
      return false if remaining.match?(/\A\s*[,\}\]]/m)

      # Check for JSON key-value separator pattern (colon followed by a value)
      return false if remaining.match?(/\A\s*:\s*"/m)

      # If followed by a key pattern like `"key":`, it's probably a real end quote
      return false if remaining.match?(/\A\s*,?\s*"[^"]+"\s*:/m)

      # Otherwise, this quote is likely embedded in text content
      # Look for patterns that suggest continuation of text
      remaining.match?(/\A[a-zA-Z0-9\s,.'!?;:\-]/m)
    end

  end
end
