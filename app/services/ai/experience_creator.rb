# frozen_string_literal: true

module Ai
  # Kreira Experience-e od postojećih lokacija
  # Može kreirati lokalne (unutar grada) i tematske (cross-city) Experience-e
  # Poštuje max_experiences limit za kontrolu broja kreiranih Experience-a
  class ExperienceCreator
    include Concerns::ErrorReporting

    class CreationError < StandardError; end

    def initialize(max_experiences: nil)
      @chat = RubyLLM.chat
      @max_experiences = max_experiences # nil = unlimited
      @created_count = 0
    end

    # Kreira lokalne Experience-e za grad (lokacije samo iz tog grada)
    # @param city [String] Naziv grada
    # @return [Array<Experience>] Kreirani Experience-i
    def create_local_experiences(city:)
      return [] if limit_reached?

      log_info "Creating local experiences for #{city}"

      city_locations = Location.where(city: city).with_coordinates.includes(:experience_types)
      return [] if city_locations.count < min_locations_per_experience

      proposals = ai_propose_local_experiences(city_locations, city)
      create_experiences_from_proposals(proposals, city_locations)
    end

    # Kreira tematske Experience-e (lokacije iz različitih gradova)
    # Npr: "Tvrđave BiH", "UNESCO spomenici", "Mostovi Hercegovine"
    # @return [Array<Experience>] Kreirani Experience-i
    def create_thematic_experiences
      return [] if limit_reached?

      log_info "Creating thematic cross-city experiences"

      all_locations = Location.with_coordinates.includes(:experience_types, :location_categories)
      return [] if all_locations.count < min_locations_per_experience

      proposals = ai_propose_thematic_experiences(all_locations)
      create_experiences_from_proposals(proposals, all_locations)
    end

    # Vraća broj preostalih slotova za kreiranje
    def remaining_slots
      @max_experiences ? (@max_experiences - @created_count) : Float::INFINITY
    end

    # Da li je dostignut limit
    def limit_reached?
      @max_experiences && @created_count >= @max_experiences
    end

    private

    def create_experiences_from_proposals(proposals, available_locations)
      created = []

      proposals.take(remaining_slots.to_i).each do |proposal|
        experience = create_experience_from_proposal(proposal, available_locations)
        if experience
          created << experience
          @created_count += 1
        end
        break if limit_reached?
      end

      log_info "Created #{created.count} experiences (total: #{@created_count})"
      created
    end

    def create_experience_from_proposal(proposal, available_locations)
      # Pronađi lokacije iz proposal-a
      location_ids = proposal[:location_ids] || []
      locations = available_locations.where(id: location_ids).to_a

      # Fallback ako AI nije vratio validne ID-jeve
      if locations.count < min_locations_per_experience && proposal[:location_names].present?
        locations = find_locations_by_names(proposal[:location_names], available_locations)
      end

      return nil if locations.count < min_locations_per_experience

      # Pronađi kategoriju ako je specificirana
      category = find_or_create_category(proposal[:category_key])

      # Extract initial title from proposal (required for validation)
      initial_title = extract_initial_title(proposal)

      experience = Experience.new(
        title: initial_title,
        estimated_duration: proposal[:estimated_duration] || calculate_duration(locations),
        experience_category: category,
        seasons: proposal[:seasons] || []
      )

      if experience.save
        # Set translations after save to ensure translatable_id is present
        set_experience_translations(experience, proposal)
        # Dodaj lokacije u redoslijedu
        locations.each_with_index do |loc, index|
          experience.add_location(loc, position: index + 1)
        end

        # Pokušaj dodati cover photo
        attach_cover_photo(experience, locations)

        log_info "Created experience: #{experience.title} with #{locations.count} locations"
        experience
      else
        log_error "Failed to create experience: #{experience.errors.full_messages.join(', ')}"
        nil
      end
    rescue StandardError => e
      log_error "Error creating experience: #{e.message}"
      nil
    end

    def ai_propose_local_experiences(locations, city)
      prompt = build_local_experiences_prompt(locations, city)
      response = @chat.with_schema(experiences_proposal_schema).ask(prompt)

      result = response.content.is_a?(Hash) ? response.content.deep_symbolize_keys : parse_ai_json_response(response.content)
      result[:experiences] || []
    rescue StandardError => e
      log_warn "AI proposal failed for #{city}: #{e.message}"
      []
    end

    def ai_propose_thematic_experiences(locations)
      prompt = build_thematic_experiences_prompt(locations)
      response = @chat.with_schema(experiences_proposal_schema).ask(prompt)

      result = response.content.is_a?(Hash) ? response.content.deep_symbolize_keys : parse_ai_json_response(response.content)
      result[:experiences] || []
    rescue StandardError => e
      log_warn "AI thematic proposal failed: #{e.message}"
      []
    end

    # JSON Schema for experience proposals - ensures structured output from AI
    # Note: OpenAI structured output requires additionalProperties: false at all levels
    # and all properties must be listed in required array
    def experiences_proposal_schema
      locale_properties = supported_locales.to_h { |loc| [loc, { type: "string" }] }

      {
        type: "object",
        properties: {
          experiences: {
            type: "array",
            items: {
              type: "object",
              properties: {
                location_ids: { type: "array", items: { type: "integer" } },
                location_names: { type: "array", items: { type: "string" } },
                category_key: { type: "string" },
                estimated_duration: { type: "integer" },
                seasons: { type: "array", items: { type: "string" } },
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
                theme_reasoning: { type: "string" }
              },
              required: %w[location_ids location_names category_key estimated_duration seasons titles descriptions theme_reasoning],
              additionalProperties: false
            }
          }
        },
        required: ["experiences"],
        additionalProperties: false
      }
    end

    def build_local_experiences_prompt(locations, city)
      locations_info = format_locations_for_prompt(locations)
      max_to_create = [remaining_slots, 5].min

      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Create #{max_to_create} curated tourism experiences for #{city}.

        AVAILABLE LOCATIONS IN #{city.upcase}:
        #{locations_info}

        GUIDELINES:
        1. Group locations THEMATICALLY (history, food, nature, culture, etc.)
        2. Each experience should have 3-5 locations that make sense together
        3. Consider walking distance and logical route flow
        4. One location CAN appear in multiple experiences if it fits
        5. Create diverse experiences for different types of tourists

        TITLES:
        - Use authentic Bosnian names where appropriate
        - Examples: "Tragovima Sevdaha", "Čaršijska Šetnja", "Ukus Bosne"
        - NOT generic like "City Tour" or "Cultural Walk"

        ⚠️ KRITIČNO ZA BOSANSKI JEZIK ("bs"):
        - OBAVEZNO koristiti IJEKAVICU: "lijepo", "vrijeme", "mjesto", "vidjeti", "bijelo"
        - NIKAD ekavicu: NE "lepo", "vreme", "mesto", "videti", "belo"
        - Koristiti "historija" (NE "istorija"), "hiljada" (NE "tisuća")

        Return ONLY valid JSON:
        {
          "experiences": [
            {
              "location_ids": [1, 2, 3],
              "location_names": ["Name 1", "Name 2", "Name 3"],
              "category_key": "cultural_heritage",
              "estimated_duration": 180,
              "seasons": [],
              "titles": {
                "en": "English title...",
                "bs": "Bosanski naslov (IJEKAVICA!)...",
                "hr": "Hrvatski naslov...",
                "de": "Deutscher Titel..."
              },
              "descriptions": {
                "en": "Rich, engaging description (1-2 paragraphs, 100-200 words) that captures the essence of this experience...",
                "bs": "Bogat, privlačan opis (1-2 pasusa, 100-200 RIJEČI - ne reči!) koji hvata suštinu ovog ISKUSTVA sa LIJEPIM detaljima o POVIJESNOM MJESTU...",
                "hr": "Bogat, privlačan opis (1-2 odlomka, 100-200 riječi) koji hvata bit ovog iskustva...",
                "de": "Reichhaltige, ansprechende Beschreibung (1-2 Absätze, 100-200 Wörter), die das Wesen dieses Erlebnisses einfängt..."
              },
              "theme_reasoning": "Why these locations work together..."
            }
          ]
        }

        Languages to include: #{supported_locales.join(', ')}
        REMINDER: For "bs" (Bosnian) use IJEKAVICA (lijepo, rijeka, vrijeme), NOT ekavica!
      PROMPT
    end

    def build_thematic_experiences_prompt(locations)
      # Grupiši lokacije po gradu za bolji pregled
      locations_by_city = locations.group_by(&:city)
      locations_info = locations_by_city.map do |city, city_locs|
        city_section = "=== #{city} ===\n"
        city_section + city_locs.map { |loc| format_single_location(loc) }.join("\n")
      end.join("\n\n")

      max_to_create = [remaining_slots, 3].min

      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Create #{max_to_create} CROSS-CITY thematic experiences that connect locations from DIFFERENT cities.

        AVAILABLE LOCATIONS BY CITY:
        #{locations_info}

        IMPORTANT: These experiences should span MULTIPLE CITIES!
        Examples of good thematic groupings:
        - "Tvrđave BiH" - fortresses from Travnik, Jajce, Banja Luka, Počitelj
        - "UNESCO spomenici" - heritage sites across the country
        - "Mostovi Hercegovine" - bridges in Mostar, Konjic, Trebinje
        - "Stećci - Kameni stražari" - medieval tombstones from different regions
        - "Rijeke Bosne" - river experiences across multiple cities

        GUIDELINES:
        1. Connect locations from AT LEAST 2 different cities
        2. Find a compelling THEME that unites distant locations
        3. 4-6 locations per experience (balanced across cities)
        4. Consider practical multi-day itinerary flow
        5. Highlight what makes BiH unique as a whole

        ⚠️ KRITIČNO ZA BOSANSKI JEZIK ("bs"):
        - OBAVEZNO koristiti IJEKAVICU: "lijepo", "vrijeme", "mjesto", "vidjeti", "bijelo", "stoljeća"
        - NIKAD ekavicu: NE "lepo", "vreme", "mesto", "videti", "belo", "stoleća"
        - Koristiti "historija" (NE "istorija"), "hiljada" (NE "tisuća")

        Return ONLY valid JSON:
        {
          "experiences": [
            {
              "location_ids": [1, 5, 12, 18],
              "location_names": ["Name from City A", "Name from City B", ...],
              "category_key": "cultural_heritage",
              "estimated_duration": 480,
              "seasons": [],
              "titles": {
                "en": "Fortresses of Bosnia...",
                "bs": "Tvrđave Bosne (IJEKAVICA!)...",
                ...
              },
              "descriptions": {
                "en": "Rich, engaging description (1-2 paragraphs, 100-200 words) - Journey through centuries of history...",
                "bs": "Bogat opis (1-2 pasusa, 100-200 RIJEČI) - Putovanje kroz STOLJEĆA historije, LIJEPIM MJESTIMA...",
                ...
              },
              "cities_included": ["Travnik", "Jajce", "Banja Luka"],
              "theme_reasoning": "Why these distant locations belong together..."
            }
          ]
        }

        Languages to include: #{supported_locales.join(', ')}
        REMINDER: For "bs" (Bosnian) use IJEKAVICA (lijepo, rijeka, vrijeme), NOT ekavica!
      PROMPT
    end

    def format_locations_for_prompt(locations)
      locations.map { |loc| format_single_location(loc) }.join("\n\n")
    end

    def format_single_location(loc)
      experience_types = loc.experience_types.pluck(:key).join(", ").presence || "general"
      categories = loc.location_categories.pluck(:key).join(", ").presence || loc.location_type

      info = "ID: #{loc.id} | #{loc.name}\n"
      info += "  City: #{loc.city}\n"
      info += "  Type: #{categories}\n"
      info += "  Experiences: #{experience_types}\n"
      info += "  Coords: #{loc.lat}, #{loc.lng}\n"

      if loc.description.present?
        info += "  Description: #{loc.description.to_s.truncate(150)}\n"
      end

      if loc.tags.present?
        info += "  Tags: #{loc.tags.join(', ')}"
      end

      info
    end

    def find_locations_by_names(names, available_locations)
      names.filter_map do |name|
        available_locations.find { |loc| loc.name.downcase.include?(name.to_s.downcase) }
      end.uniq
    end

    def find_or_create_category(category_key)
      return nil if category_key.blank?

      ExperienceCategory.find_by(key: category_key) ||
        ExperienceCategory.find_by("LOWER(key) = ?", category_key.to_s.downcase)
    end

    # Extract the initial title from proposal for validation
    # Prioritizes English, then any available title, then fallback
    def extract_initial_title(proposal)
      proposal.dig(:titles, "en") ||
        proposal.dig(:titles, :en) ||
        proposal[:titles]&.values&.first ||
        "Experience"
    end

    def set_experience_translations(experience, proposal)
      supported_locales.each do |locale|
        title = proposal.dig(:titles, locale.to_s) ||
                proposal.dig(:titles, locale.to_sym) ||
                proposal[:titles]&.values&.first ||
                "Experience"

        description = proposal.dig(:descriptions, locale.to_s) ||
                      proposal.dig(:descriptions, locale.to_sym) ||
                      proposal[:descriptions]&.values&.first ||
                      ""

        experience.set_translation(:title, title, locale)
        experience.set_translation(:description, description, locale)
      end
    end

    def calculate_duration(locations)
      # Procijeni 30-45 minuta po lokaciji
      base_per_location = 35
      travel_time = (locations.count - 1) * 15 # 15 min između lokacija
      (locations.count * base_per_location) + travel_time
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
      log_warn "Could not attach cover photo: #{e.message}"
    end

    def min_locations_per_experience
      @min_locations ||= Setting.get("experience.min_locations", default: 1).to_i
    end

    def cultural_context
      Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT
    end

    def supported_locales
      @supported_locales ||= Locale.ai_supported_codes.presence ||
        %w[en bs hr de es fr it pt nl pl cs sk sl sr]
    end

    def parse_ai_json_response(content)
      json_match = content.match(/```(?:json)?\s*([\s\S]*?)```/) ||
                   content.match(/(\{[\s\S]*\})/)
      json_str = json_match ? json_match[1] : content
      json_str = sanitize_ai_json(json_str)
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
