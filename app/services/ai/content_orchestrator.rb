# frozen_string_literal: true

module Ai
  # Glavni orkestratar za autonomno AI generiranje sadržaja
  # Admin samo klikne jedan gumb - AI odlučuje SVE:
  # - Koje gradove obraditi
  # - Koje kategorije lokacija dohvatiti
  # - Kako grupirati lokacije u Experience-e
  # - Koje planove kreirati za koje profile turista
  #
  # NAPOMENA: Audio ture se NE generišu ovdje - pokreću se odvojeno
  # zbog troškova ElevenLabs API-ja
  class ContentOrchestrator
    include Concerns::ErrorReporting

    class GenerationError < StandardError; end
    class CancellationError < StandardError; end

    # Default upper limits to prevent runaway generation
    DEFAULT_MAX_LOCATIONS = 100
    DEFAULT_MAX_EXPERIENCES = 200
    DEFAULT_MAX_PLANS = 50

    # @param max_locations [Integer, nil] Maximum locations to create (default: 100, nil = unlimited)
    # @param max_experiences [Integer, nil] Maximum experiences to create (default: 200, nil = unlimited)
    # @param max_plans [Integer, nil] Maximum plans to create (default: 50, nil = unlimited)
    # @param skip_locations [Boolean] Skip location fetching/creation
    # @param skip_experiences [Boolean] Skip experience creation
    # @param skip_plans [Boolean] Skip plan creation
    def initialize(max_locations: nil, max_experiences: nil, max_plans: nil, skip_locations: false, skip_experiences: false, skip_plans: false)
      # Use provided limits, or defaults to prevent runaway generation
      # Note: explicitly passing nil means "use default", pass 0 for truly unlimited (not recommended)
      @max_locations = max_locations.nil? ? DEFAULT_MAX_LOCATIONS : (max_locations.zero? ? nil : max_locations)
      @max_experiences = max_experiences.nil? ? DEFAULT_MAX_EXPERIENCES : (max_experiences.zero? ? nil : max_experiences)
      @max_plans = max_plans.nil? ? DEFAULT_MAX_PLANS : (max_plans.zero? ? nil : max_plans)
      # No longer using @chat directly - using OpenaiQueue for rate limiting
      @geoapify = GeoapifyService.new
      @skip_locations = skip_locations
      @skip_experiences = skip_experiences
      @skip_plans = skip_plans
      @results = {
        started_at: Time.current,
        locations_created: 0,
        locations_enriched: 0,
        experiences_created: 0,
        plans_created: 0,
        errors: [],
        cities_processed: [],
        skipped: { locations: skip_locations, experiences: skip_experiences, plans: skip_plans }
      }
    end

    # JEDINA METODA KOJU ADMIN POZIVA
    # AI autonomno odlučuje sve i generira sadržaj
    # @return [Hash] Rezultati generiranja
    def generate
      log_info "Starting autonomous content generation"
      self.class.clear_cancellation!
      save_generation_status("in_progress", "AI reasoning phase")

      begin
        # Faza 1: AI reasoning - šta treba uraditi?
        check_cancellation!
        plan = analyze_and_plan
        log_info "AI plan: #{plan[:analysis]}"
        save_generation_status("in_progress", "Executing plan", plan: plan)

        # Faza 2-5: Izvršavanje plana
        execute_plan(plan)

        # Završeno
        @results[:finished_at] = Time.current
        @results[:status] = "completed"
        save_generation_status("completed", "Generation complete", results: @results)

        log_info "Generation complete: #{@results[:locations_created]} locations, " \
                 "#{@results[:experiences_created]} experiences, #{@results[:plans_created]} plans"

        @results
      rescue CancellationError
        @results[:finished_at] = Time.current
        @results[:status] = "cancelled"
        save_generation_status("cancelled", "Generation was stopped by user", results: @results)
        log_info "Generation cancelled by user"
        @results
      rescue StandardError => e
        @results[:status] = "failed"
        @results[:error] = e.message
        save_generation_status("failed", e.message)
        log_error "Generation failed: #{e.message}"
        raise GenerationError, e.message
      end
    end

    # Vraća trenutni status generiranja
    def self.current_status
      {
        status: Setting.get("ai.generation.status", default: "idle"),
        message: Setting.get("ai.generation.message", default: nil),
        started_at: Setting.get("ai.generation.started_at", default: nil),
        plan: JSON.parse(Setting.get("ai.generation.plan", default: "{}") || "{}"),
        results: JSON.parse(Setting.get("ai.generation.results", default: "{}") || "{}")
      }
    rescue JSON::ParserError
      { status: "idle", message: nil, started_at: nil, plan: {}, results: {} }
    end

    # Označava generiranje kao otkazano
    # Koristi odvojeni ključ da se izbjegne race condition sa save_generation_status
    def self.cancel_generation!
      Setting.set("ai.generation.cancelled", "true")
      Setting.set("ai.generation.message", "Generation was stopped by user")
    end

    # Provjerava da li je generiranje otkazano
    # Koristi odvojeni ključ koji se ne prepisuje od strane save_generation_status
    def self.cancelled?
      Setting.get("ai.generation.cancelled", default: "false") == "true"
    end

    # Briše zastavicu otkazivanja (pozvati prije novog generiranja)
    def self.clear_cancellation!
      Setting.set("ai.generation.cancelled", "false")
    end

    # Force-resets generation status to idle (use when job is stuck)
    def self.force_reset!
      Setting.set("ai.generation.status", "idle")
      Setting.set("ai.generation.cancelled", "false")
      Setting.set("ai.generation.message", nil)
    end

    # Vraća statistiku sadržaja - optimizirano sa grupisanim upitima
    def self.content_stats
      # Jedan upit za sve lokacije po gradu
      locations_by_city = Location.group(:city).count

      # Jedan upit za sve experience-e po gradu
      experiences_by_city = Experience.joins(:locations)
                                      .group("locations.city")
                                      .distinct
                                      .count("experiences.id")

      # Jedan upit za sve planove po gradu
      plans_by_city = Plan.group(:city_name).count

      # Jedan upit za AI planove po gradu
      ai_plans_by_city = Plan.where("preferences->>'generated_by_ai' = 'true'")
                             .group(:city_name).count

      # Jedan upit za audio ture po gradu
      audio_by_city = Location.joins(audio_tours: :audio_file_attachment)
                              .group(:city)
                              .distinct
                              .count("locations.id")

      # Konstruiši statistiku iz grupisanih rezultata
      cities = locations_by_city.keys.compact
      stats = cities.map do |city|
        locations_count = locations_by_city[city] || 0
        audio_count = audio_by_city[city] || 0

        {
          city: city,
          locations: locations_count,
          experiences: experiences_by_city[city] || 0,
          plans: plans_by_city[city] || 0,
          ai_plans: ai_plans_by_city[city] || 0,
          audio: audio_count,
          audio_coverage: locations_count > 0 ? (audio_count.to_f / locations_count * 100).round(1) : 0
        }
      end

      {
        cities: stats.sort_by { |s| -s[:locations] },
        totals: {
          locations: stats.sum { |s| s[:locations] },
          experiences: stats.sum { |s| s[:experiences] },
          plans: stats.sum { |s| s[:plans] },
          ai_plans: stats.sum { |s| s[:ai_plans] },
          audio: stats.sum { |s| s[:audio] }
        }
      }
    end

    private

    # ═══════════════════════════════════════════════════════════
    # FAZA 1: AI REASONING
    # ═══════════════════════════════════════════════════════════
    def analyze_and_plan
      current_state = gather_current_state
      prompt = build_reasoning_prompt(current_state)

      # Use OpenaiQueue for rate-limited requests
      result = Ai::OpenaiQueue.request(
        prompt: prompt,
        schema: orchestration_plan_schema,
        context: "ContentOrchestrator:reasoning"
      )
      result || create_fallback_plan(current_state)
    rescue Ai::OpenaiQueue::RequestError => e
      log_error "AI reasoning failed: #{e.message}"
      # Fallback plan ako AI reasoning ne uspije
      create_fallback_plan(current_state)
    end

    # JSON Schema for orchestration plan - ensures structured output from AI
    # Note: OpenAI structured output requires additionalProperties: false at all levels
    # and all properties must be listed in required array
    def orchestration_plan_schema
      {
        type: "object",
        properties: {
          analysis: { type: "string", description: "Brief analysis of current state" },
          target_cities: {
            type: "array",
            items: {
              type: "object",
              properties: {
                city: { type: "string" },
                country: { type: "string" },
                coordinates: {
                  type: "object",
                  properties: { lat: { type: "number" }, lng: { type: "number" } },
                  required: %w[lat lng],
                  additionalProperties: false
                },
                locations_to_fetch: { type: "integer" },
                categories: { type: "array", items: { type: "string" } },
                reasoning: { type: "string" }
              },
              required: %w[city country coordinates locations_to_fetch categories reasoning],
              additionalProperties: false
            }
          },
          tourist_profiles_to_generate: { type: "array", items: { type: "string" } },
          estimated_new_content: {
            type: "object",
            properties: {
              locations: { type: "integer" },
              experiences: { type: "integer" },
              plans: { type: "integer" }
            },
            required: %w[locations experiences plans],
            additionalProperties: false
          }
        },
        required: %w[analysis target_cities tourist_profiles_to_generate estimated_new_content],
        additionalProperties: false
      }
    end

    def gather_current_state
      existing_cities = Location.distinct.pluck(:city).compact

      {
        existing_cities: existing_cities,
        locations_per_city: Location.group(:city).count,
        experiences_per_city: Experience.joins(:locations)
                                        .group("locations.city").count,
        plans_per_city: Plan.where("preferences->>'generated_by_ai' = 'true'")
                            .group(:city_name).count,
        target_country: Setting.get("ai.target_country", default: "Bosnia and Herzegovina"),
        target_country_code: Setting.get("ai.target_country_code", default: "ba"),
        max_experiences: @max_experiences
      }
    end

    def build_reasoning_prompt(state)
      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Analyze the current state of tourism content and create an action plan.

        TARGET COUNTRY: #{state[:target_country]} (#{state[:target_country_code]})

        CURRENT STATE:
        - Existing cities: #{state[:existing_cities].presence&.join(", ") || "None"}
        - Locations per city: #{state[:locations_per_city]}
        - Experiences per city: #{state[:experiences_per_city]}
        - AI plans per city: #{state[:plans_per_city]}
        #{state[:max_experiences] ? "- Maximum experiences to create: #{state[:max_experiences]}" : ""}

        YOUR TASK:
        1. Analyze which cities have insufficient content (less than 10 locations)
        2. Suggest new cities that should be covered (major tourist destinations in #{state[:target_country]})
        3. Decide which location categories are needed
        4. Suggest tourist profiles for plans (e.g., family, couple, adventure, nature, culture, budget, luxury, foodie, solo)

        GEOAPIFY CATEGORIES (choose relevant ones for tourism):
        tourism.attraction, tourism.sights, tourism.sights.castle, tourism.sights.fort,
        tourism.sights.monastery, tourism.sights.memorial, tourism.viewpoint,
        catering.restaurant, catering.cafe, catering.bar,
        entertainment.museum, entertainment.culture.theatre, entertainment.culture.gallery,
        tourism.sights.place_of_worship.mosque, tourism.sights.place_of_worship.church,
        natural.water, natural.water.spring, natural.water.hot_spring,
        natural.mountain.peak, natural.mountain.cave_entrance, natural.protected_area,
        heritage.unesco,
        leisure.park, leisure.spa,
        accommodation.hotel, accommodation.hostel

        IMPORTANT:
        - Prioritize cities with UNESCO sites: Mostar (Stari Most), Višegrad (Mehmed-paša Sokolović Bridge)
        - Include major tourist cities: Sarajevo, Mostar, Jajce, Travnik, Banja Luka
        - Consider natural attractions: Una National Park, Sutjeska, Blidinje
        - Balance between cultural and natural content

        Return ONLY valid JSON:
        {
          "analysis": "Brief analysis of current state (2-3 sentences)...",
          "target_cities": [
            {
              "city": "City Name",
              "country": "#{state[:target_country]}",
              "coordinates": {"lat": 43.8563, "lng": 18.4131},
              "locations_to_fetch": 30,
              "categories": ["tourism.attraction", "catering.restaurant", "heritage"],
              "reasoning": "Why this city needs more content..."
            }
          ],
          "tourist_profiles_to_generate": ["family", "couple", "culture", "adventure", "nature"],
          "estimated_new_content": {
            "locations": 50,
            "experiences": 10,
            "plans": 16
          }
        }
      PROMPT
    end

    def create_fallback_plan(state)
      # Ako AI reasoning ne uspije, koristi osnovni plan
      target_cities = []

      # Dodaj gradove koji nemaju dovoljno lokacija
      state[:existing_cities].each do |city|
        count = state[:locations_per_city][city] || 0
        if count < 10
          target_cities << {
            city: city,
            locations_to_fetch: 20,
            categories: default_categories,
            reasoning: "Existing city with insufficient content"
          }
        end
      end

      # Dodaj default gradove ako nema postojećih
      if target_cities.empty?
        target_cities = default_target_cities
      end

      {
        analysis: "Fallback plan - using default configuration",
        target_cities: target_cities.first(3),
        tourist_profiles_to_generate: %w[family couple culture],
        estimated_new_content: { locations: 60, experiences: 10, plans: 12 }
      }
    end

    def default_categories
      %w[
        tourism.attraction
        tourism.sights
        catering.restaurant
        catering.cafe
        entertainment.museum
        heritage
        religion.place_of_worship
        natural
      ]
    end

    def default_target_cities
      [
        {
          city: "Sarajevo",
          coordinates: { lat: 43.8563, lng: 18.4131 },
          locations_to_fetch: 30,
          categories: default_categories,
          reasoning: "Capital city, main tourist destination"
        },
        {
          city: "Mostar",
          coordinates: { lat: 43.3438, lng: 17.8078 },
          locations_to_fetch: 25,
          categories: default_categories,
          reasoning: "UNESCO World Heritage Site - Stari Most"
        },
        {
          city: "Jajce",
          coordinates: { lat: 44.3422, lng: 17.2703 },
          locations_to_fetch: 15,
          categories: default_categories,
          reasoning: "Historic town with waterfall"
        }
      ]
    end

    # ═══════════════════════════════════════════════════════════
    # FAZA 2-5: IZVRŠAVANJE
    # ═══════════════════════════════════════════════════════════
    def execute_plan(plan)
      target_cities = plan[:target_cities] || []
      profiles = plan[:tourist_profiles_to_generate] || %w[family couple culture]

      target_cities.each do |city_plan|
        check_cancellation!
        process_city(city_plan, profiles)
      end

      check_cancellation!
      # Kreiraj cross-city tematske Experience-e
      create_cross_city_experiences

      check_cancellation!
      # Kreiraj multi-city planove
      create_multi_city_plans(profiles)
    end

    def process_city(city_plan, profiles)
      city = city_plan[:city]
      log_info "Processing city: #{city}"
      save_generation_status("in_progress", "Processing #{city}")

      city_result = { city: city, locations: 0, experiences: 0, plans: 0 }

      begin
        # Faza 2-3: Prikupljanje i spremanje lokacija
        unless @skip_locations || locations_limit_reached?
          raw_places = fetch_locations(city_plan)
          log_info "Fetched #{raw_places.count} places for #{city}"

          locations_before = @results[:locations_created]
          new_locations = enrich_and_save_locations(raw_places, city)
          # Count is already updated inside enrich_and_save_locations
          city_result[:locations] = @results[:locations_created] - locations_before
          log_info "Created #{city_result[:locations]} new locations in #{city}"
        end

        # Faza 4: Kreiranje lokalnih Experience-a
        unless @skip_experiences || experiences_limit_reached?
          experiences = create_local_experiences(city)
          @results[:experiences_created] += experiences.count
          city_result[:experiences] = experiences.count
          log_info "Created #{experiences.count} experiences for #{city}"
        end

        # Faza 5: Kreiranje Plan-ova za ovaj grad
        unless @skip_plans || plans_limit_reached?
          plans = create_city_plans(city, profiles)
          @results[:plans_created] += plans.count
          city_result[:plans] = plans.count
          log_info "Created #{plans.count} plans for #{city}"
        end

        @results[:cities_processed] << city_result
      rescue StandardError => e
        log_error "Error processing #{city}: #{e.message}"
        @results[:errors] << { city: city, error: e.message }
      end
    end

    def fetch_locations(city_plan)
      categories = city_plan[:categories].presence || default_categories
      coordinates = city_plan[:coordinates]
      locations_to_fetch = city_plan[:locations_to_fetch] || 20
      country_code = Setting.get("ai.target_country_code", default: "ba")

      all_places = []

      # Guard against empty categories to avoid division by zero (Infinity)
      return all_places if categories.empty?

      # Calculate max results per category safely
      results_per_category = (locations_to_fetch.to_f / categories.count).ceil + 5

      # Rate limiting za Geoapify (5 req/sec)
      RateLimiter.with_geoapify_limit(categories) do |batch|
        batch.each do |category|
          break if all_places.count >= locations_to_fetch

          begin
            places = if coordinates
              @geoapify.search_nearby(
                lat: coordinates[:lat],
                lng: coordinates[:lng],
                radius: 15_000, # 15km radius
                types: [category],
                max_results: results_per_category
              )
            else
              @geoapify.text_search(
                query: "#{category.split('.').last} #{city_plan[:city]}",
                max_results: results_per_category
              )
            end

            # Filtriraj samo lokacije iz ciljane države
            filtered = places.select do |place|
              valid_location_for_country?(place, country_code, city_plan[:city])
            end

            all_places.concat(filtered)
          rescue GeoapifyService::ApiError => e
            log_warn "Geoapify error for category #{category}: #{e.message}"
          end
        end
      end

      all_places.uniq { |p| p[:place_id] }.first(locations_to_fetch)
    end

    def valid_location_for_country?(place, country_code, city_name)
      # Provjeri da li adresa sadrži naziv grada ili države
      address = place[:address].to_s.downcase
      city_match = address.include?(city_name.to_s.downcase)
      country_match = address.include?(country_code) ||
                      address.include?("bosnia") ||
                      address.include?("herzegovina") ||
                      address.include?("bih")

      city_match || country_match
    end

    def enrich_and_save_locations(places, city)
      return [] if locations_limit_reached?

      enricher = LocationEnricher.new
      created = []

      places.each do |place|
        break if locations_limit_reached?
        next if place[:name].blank? || place[:lat].blank?

        location = enricher.create_and_enrich(place, city: city)
        if location
          created << location
          @results[:locations_created] += 1
        end
      end

      # Return created locations (count already tracked above)
      created
    end

    def create_local_experiences(city)
      return [] if experiences_limit_reached?

      creator = ExperienceCreator.new(max_experiences: remaining_experience_slots)
      creator.create_local_experiences(city: city)
    end

    def create_cross_city_experiences
      return if @skip_experiences
      return if experiences_limit_reached?

      log_info "Creating cross-city thematic experiences"
      save_generation_status("in_progress", "Creating thematic experiences")

      creator = ExperienceCreator.new(max_experiences: remaining_experience_slots)
      experiences = creator.create_thematic_experiences
      @results[:experiences_created] += experiences.count
    end

    def create_city_plans(city, profiles)
      return [] if plans_limit_reached?

      creator = PlanCreator.new
      created = []

      profiles.each do |profile|
        break if plans_limit_reached?

        plan = creator.create_for_profile(profile: profile, city: city)
        created << plan if plan
      end

      created
    end

    def create_multi_city_plans(profiles)
      return [] if @skip_plans || plans_limit_reached?

      log_info "Creating multi-city plans"
      save_generation_status("in_progress", "Creating multi-city plans")

      creator = PlanCreator.new
      created = []

      # Samo 2-3 profila za multi-city planove
      profiles.first(3).each do |profile|
        break if plans_limit_reached?

        plan = creator.create_for_profile(profile: profile, city: nil)
        if plan
          created << plan
          @results[:plans_created] += 1
        end
      end

      created
    end

    def locations_limit_reached?
      return false unless @max_locations
      @results[:locations_created] >= @max_locations
    end

    def remaining_location_slots
      return nil unless @max_locations
      [@max_locations - @results[:locations_created], 0].max
    end

    def experiences_limit_reached?
      return false unless @max_experiences
      @results[:experiences_created] >= @max_experiences
    end

    def remaining_experience_slots
      return nil unless @max_experiences
      [@max_experiences - @results[:experiences_created], 0].max
    end

    def plans_limit_reached?
      return false unless @max_plans
      @results[:plans_created] >= @max_plans
    end

    def remaining_plan_slots
      return nil unless @max_plans
      [@max_plans - @results[:plans_created], 0].max
    end

    def save_generation_status(status, message, plan: nil, results: nil)
      Setting.set("ai.generation.status", status)
      Setting.set("ai.generation.message", message)
      Setting.set("ai.generation.started_at", @results[:started_at].iso8601) if @results[:started_at]
      Setting.set("ai.generation.plan", plan.to_json) if plan
      Setting.set("ai.generation.results", results.to_json) if results
    rescue StandardError => e
      log_warn "Could not save generation status: #{e.message}"
    end

    def cultural_context
      Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT
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

    def check_cancellation!
      raise CancellationError, "Generation cancelled by user" if self.class.cancelled?
    end

  end
end
