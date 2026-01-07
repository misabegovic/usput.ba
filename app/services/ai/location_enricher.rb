# frozen_string_literal: true

module Ai
  # Obogaćuje lokaciju sa AI-generisanim sadržajem
  # Koristi postojeća polja Location modela bez migracija
  class LocationEnricher
    include Concerns::ErrorReporting

    class EnrichmentError < StandardError; end

    # Network errors that should trigger a retry
    RETRYABLE_ERRORS = [
      Net::ReadTimeout,
      Net::OpenTimeout,
      Faraday::TimeoutError,
      Faraday::ConnectionFailed,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
      Errno::ECONNREFUSED,
      OpenSSL::SSL::SSLError
    ].freeze

    MAX_RETRIES = 3
    BASE_RETRY_DELAY = 2 # seconds

    def initialize
      @chat = RubyLLM.chat
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
      location = Location.new(
        name: place_data[:name],
        lat: place_data[:lat],
        lng: place_data[:lng],
        city: city,
        location_type: determine_location_type(place_data[:categories]),
        budget: determine_budget(place_data),
        website: normalize_website_url(place_data[:website]),
        phone: place_data[:contact]&.dig(:phone),
        email: place_data[:contact]&.dig(:email)
      )

      # Obogati i spremi
      enrichment = generate_enrichment(location, place_data)
      apply_enrichment(location, enrichment) if enrichment.present?

      if location.save
        # Dodaj tagove iz kategorija
        add_tags_from_categories(location, place_data[:categories])

        log_info "Created and enriched location: #{location.name}"
        location
      else
        log_error "Failed to create location: #{location.errors.full_messages.join(', ')}"
        nil
      end
    rescue StandardError => e
      log_error "Error creating location #{place_data[:name]}: #{e.message}"
      nil
    end

    private

    def generate_enrichment(location, place_data)
      prompt = build_enrichment_prompt(location, place_data)
      response = request_with_retry(location.name) { @chat.with_schema(location_enrichment_schema).ask(prompt) }
      return {} if response.nil?

      # with_schema automatically parses JSON
      response.content.is_a?(Hash) ? response.content.deep_symbolize_keys : parse_ai_json_response(response.content)
    rescue StandardError => e
      log_warn "AI enrichment failed for #{location.name}: #{e.message}"
      {}
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
            description: "Localized descriptions keyed by locale code"
          },
          historical_context: {
            type: "object",
            properties: locale_properties,
            required: supported_locales,
            additionalProperties: false,
            description: "Localized historical context for audio narration"
          }
        },
        required: %w[suitable_experiences descriptions historical_context],
        additionalProperties: false
      }
    end

    def request_with_retry(context_name, &block)
      retries = 0

      begin
        yield
      rescue *RETRYABLE_ERRORS => e
        retries += 1
        if retries <= MAX_RETRIES
          delay = BASE_RETRY_DELAY * (2**(retries - 1)) # Exponential backoff: 2s, 4s, 8s
          log_warn "Network error for #{context_name} (attempt #{retries}/#{MAX_RETRIES}): #{e.class.name}. Retrying in #{delay}s..."
          sleep(delay)
          retry
        else
          log_error "Network error for #{context_name} after #{MAX_RETRIES} retries: #{e.class.name} - #{e.message}"
          nil
        end
      end
    end

    def build_enrichment_prompt(location, place_data)
      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Enrich this location in #{location.city} with detailed tourism content.

        LOCATION INFORMATION:
        - Name: #{location.name}
        - City: #{location.city}
        - Type: #{place_data[:categories]&.first || location.location_type}
        - Categories: #{place_data[:categories]&.join(', ')}
        - Address: #{place_data[:formatted] || place_data[:address_line1]}
        - Coordinates: #{location.lat}, #{location.lng}

        Provide a JSON response with:

        1. descriptions: Object with localized descriptions for: #{supported_locales.join(', ')}
           - Write a rich, engaging description (1-2 paragraphs, around 100-200 words)
           - Paint a vivid picture of what makes this place special
           - Connect to local culture and heritage where relevant
           - Use local terminology with brief explanations
           - Include sensory details and atmosphere

        2. historical_context: Object with localized historical/cultural context for audio narration
           - Write an engaging essay-style narrative (2-4 paragraphs, around 200-400 words)
           - Tell the complete story of this place with rich historical details
           - Include interesting facts, legends, local stories, and anecdotes
           - Mention specific dates, people, events, and their significance
           - Describe how this place has evolved through different eras
           - Make it engaging and captivating for audio narration

        3. suitable_experiences: Array of experience types this place is good for
           Choose from: #{supported_experience_types.join(', ')}

        4. tags: Array of 3-5 relevant tags in English (lowercase, no spaces - use hyphens)

        5. practical_info: Object with practical information for tourists
           - best_time: Best time to visit (morning, afternoon, evening, any)
           - duration_minutes: Suggested visit duration in minutes
           - tips: Array of 3-5 practical tips for visitors (be detailed and helpful)

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
          },
          "suitable_experiences": ["culture", "history"],
          "tags": ["historical-site", "ottoman-heritage", "must-see"],
          "practical_info": {
            "best_time": "morning",
            "duration_minutes": 45,
            "tips": ["Tip 1", "Tip 2"]
          }
        }
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

      # Already has a valid scheme
      return url if url.match?(%r{\Ahttps?://}i)

      # Prepend https:// if no scheme present
      "https://#{url}"
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
