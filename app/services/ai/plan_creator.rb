# frozen_string_literal: true

module Ai
  # Kreira Plan-ove za različite profile turista
  # Koristi SVE dostupne Experience-e iz baze (ne samo nove)
  # Jedan Experience može biti u više Plan-ova
  class PlanCreator
    include Concerns::ErrorReporting

    class CreationError < StandardError; end

    # Podržani profili turista
    TOURIST_PROFILES = {
      "family" => {
        description: "Families with children",
        preferences: { pace: "relaxed", activities: %w[nature culture food], budget: "medium" }
      },
      "couple" => {
        description: "Romantic getaway for couples",
        preferences: { pace: "moderate", activities: %w[culture food relaxation], budget: "medium" }
      },
      "adventure" => {
        description: "Adventure seekers and outdoor enthusiasts",
        preferences: { pace: "active", activities: %w[adventure sport nature], budget: "medium" }
      },
      "culture" => {
        description: "History and culture enthusiasts",
        preferences: { pace: "moderate", activities: %w[culture history], budget: "medium" }
      },
      "budget" => {
        description: "Budget-conscious backpackers",
        preferences: { pace: "active", activities: %w[culture nature], budget: "low" }
      },
      "luxury" => {
        description: "Luxury travelers",
        preferences: { pace: "relaxed", activities: %w[culture food relaxation], budget: "high" }
      },
      "foodie" => {
        description: "Food and culinary enthusiasts",
        preferences: { pace: "relaxed", activities: %w[food culture], budget: "medium" }
      },
      "solo" => {
        description: "Solo travelers",
        preferences: { pace: "flexible", activities: %w[culture nature adventure], budget: "medium" }
      }
    }.freeze

    def initialize
      @chat = RubyLLM.chat
    end

    # Kreira Plan za specifičan profil i grad
    # @param profile [String] Profil turista (family, couple, adventure, etc.)
    # @param city [String, nil] Grad (nil za multi-city plan)
    # @param duration_days [Integer, nil] Broj dana (nil = AI odlučuje)
    # @return [Plan, nil] Kreirani Plan ili nil
    def create_for_profile(profile:, city: nil, duration_days: nil)
      profile_data = TOURIST_PROFILES[profile.to_s]
      unless profile_data
        log_warn "Unknown profile: #{profile}"
        return nil
      end

      log_info "Creating #{profile} plan for #{city || 'multi-city'}"

      # Dohvati dostupne Experience-e
      experiences = fetch_available_experiences(city)
      return nil if experiences.count < min_experiences_per_plan

      # AI predlaže strukturu plana
      proposal = ai_propose_plan(experiences, profile, profile_data, city, duration_days)
      return nil if proposal.blank?

      # Kreiraj Plan
      create_plan_from_proposal(proposal, experiences, profile, city)
    end

    # Kreira Plan-ove za sve profile za grad
    # @param city [String, nil] Grad (nil za multi-city)
    # @param profiles [Array<String>] Lista profila (default: svi)
    # @return [Array<Plan>] Kreirani Plan-ovi
    def create_for_all_profiles(city: nil, profiles: nil)
      profiles ||= TOURIST_PROFILES.keys
      created = []

      profiles.each do |profile|
        plan = create_for_profile(profile: profile, city: city)
        created << plan if plan
      end

      log_info "Created #{created.count} plans for #{city || 'multi-city'}"
      created
    end

    # Dodaje Experience u postojeći Plan
    # @param experience [Experience] Experience za dodati
    # @param plan [Plan] Plan u koji se dodaje
    # @param day_number [Integer] Dan u planu
    # @param position [Integer, nil] Pozicija (nil = na kraj)
    # @return [PlanExperience, nil]
    def add_experience_to_plan(experience, plan, day_number:, position: nil)
      return nil if plan.plan_experiences.exists?(experience: experience, day_number: day_number)

      pos = position || (plan.plan_experiences.where(day_number: day_number).maximum(:position) || 0) + 1

      PlanExperience.create(
        plan: plan,
        experience: experience,
        day_number: day_number,
        position: pos
      )
    end

    private

    def fetch_available_experiences(city)
      if city.present?
        # Experience-i koji imaju bar jednu lokaciju u tom gradu
        Experience.joins(:locations)
                  .where(locations: { city: city })
                  .distinct
                  .includes(:locations, :experience_category)
      else
        # Svi Experience-i za multi-city planove
        Experience.includes(:locations, :experience_category).all
      end
    end

    def ai_propose_plan(experiences, profile, profile_data, city, duration_days)
      prompt = build_plan_prompt(experiences, profile, profile_data, city, duration_days)
      response = @chat.ask(prompt)
      parse_ai_json_response(response.content)
    rescue StandardError => e
      log_warn "AI plan proposal failed: #{e.message}"
      nil
    end

    def build_plan_prompt(experiences, profile, profile_data, city, duration_days)
      experiences_info = experiences.map do |exp|
        cities = exp.locations.pluck(:city).uniq.join(", ")
        duration = exp.formatted_duration || "#{exp.estimated_duration || 60} min"
        category = exp.category_name || "General"

        "ID: #{exp.id} | #{exp.title}\n" \
        "  Category: #{category}\n" \
        "  Duration: #{duration}\n" \
        "  Cities: #{cities}\n" \
        "  Locations: #{exp.locations.count}"
      end.join("\n\n")

      duration_instruction = if duration_days
        "Plan MUST be exactly #{duration_days} days."
      else
        "Decide optimal duration (1-5 days) based on available experiences."
      end

      <<~PROMPT
        #{cultural_context}

        ---

        TASK: Create a #{profile.upcase} travel plan for #{city || 'Bosnia and Herzegovina'}.

        TOURIST PROFILE: #{profile_data[:description]}
        Preferred pace: #{profile_data[:preferences][:pace]}
        Preferred activities: #{profile_data[:preferences][:activities].join(', ')}
        Budget level: #{profile_data[:preferences][:budget]}

        #{duration_instruction}

        AVAILABLE EXPERIENCES:
        #{experiences_info}

        PLAN CREATION GUIDELINES:

        1. EXPERIENCE SELECTION:
           - Choose experiences that match the #{profile} profile
           - Balance variety with thematic coherence
           - Consider #{profile_data[:preferences][:pace]} pace
           - 2-4 experiences per day depending on duration

        2. DAY ORGANIZATION:
           - Logical geographical flow (minimize travel)
           - Balance between active and relaxed activities
           - Consider meal times and rest periods
           - Start each day with energetic activities, wind down later

        3. TITLES (create compelling names):
           - Bosnian: Use authentic local expressions
           - English: Capture the essence for international tourists
           - Examples: "Romantični Vikend u Mostaru", "Porodična Avantura BiH"

        4. NOTES (travel tips specific to this plan):
           - Practical tips for #{profile} travelers
           - Best times to visit certain experiences
           - Recommended pacing and breaks

        Return ONLY valid JSON:
        {
          "duration_days": 3,
          "titles": {
            "en": "English plan title...",
            "bs": "Bosanski naslov plana...",
            ...
          },
          "notes": {
            "en": "Practical travel notes in English...",
            "bs": "Praktične bilješke na bosanskom...",
            ...
          },
          "days": [
            {
              "day_number": 1,
              "theme": "Day theme",
              "experience_ids": [1, 2, 3]
            },
            {
              "day_number": 2,
              "theme": "Day theme",
              "experience_ids": [4, 5]
            }
          ],
          "reasoning": "Why this plan works for #{profile} travelers..."
        }

        Languages to include: #{supported_locales.join(', ')}
      PROMPT
    end

    def create_plan_from_proposal(proposal, experiences, profile, city)
      duration_days = proposal[:duration_days] || proposal[:days]&.count || 1

      plan = Plan.new(
        city_name: city || determine_primary_city(proposal, experiences),
        visibility: :public_plan,
        preferences: {
          "tourist_profile" => profile,
          "generated_by_ai" => true,
          "generation_metadata" => {
            "generated_at" => Time.current.iso8601,
            "reasoning" => proposal[:reasoning],
            "duration_days" => duration_days
          }
        }
      )

      # Postavi prijevode
      set_plan_translations(plan, proposal, profile, city)

      if plan.save
        # Dodaj Experience-e po danima
        add_experiences_to_plan(plan, proposal[:days], experiences)

        log_info "Created plan: #{plan.title} (#{plan.plan_experiences.count} experiences, #{duration_days} days)"
        plan
      else
        log_error "Failed to create plan: #{plan.errors.full_messages.join(', ')}"
        nil
      end
    rescue StandardError => e
      log_error "Error creating plan: #{e.message}"
      nil
    end

    def set_plan_translations(plan, proposal, profile, city)
      supported_locales.each do |locale|
        title = proposal.dig(:titles, locale.to_s) ||
                proposal.dig(:titles, locale.to_sym) ||
                generate_default_title(profile, city, locale)

        notes = proposal.dig(:notes, locale.to_s) ||
                proposal.dig(:notes, locale.to_sym) ||
                ""

        plan.set_translation(:title, title, locale)
        plan.set_translation(:notes, notes, locale)
      end
    end

    def generate_default_title(profile, city, locale)
      profile_names = {
        "en" => {
          "family" => "Family Adventure",
          "couple" => "Romantic Getaway",
          "adventure" => "Adventure Experience",
          "culture" => "Cultural Discovery",
          "budget" => "Budget Explorer",
          "luxury" => "Luxury Escape",
          "foodie" => "Culinary Journey",
          "solo" => "Solo Discovery"
        },
        "bs" => {
          "family" => "Porodična avantura",
          "couple" => "Romantični bijeg",
          "adventure" => "Avanturističko iskustvo",
          "culture" => "Kulturno otkriće",
          "budget" => "Budget putovanje",
          "luxury" => "Luksuzni odmor",
          "foodie" => "Kulinarska tura",
          "solo" => "Solo istraživanje"
        }
      }

      profile_name = profile_names.dig(locale, profile) ||
                     profile_names.dig("en", profile) ||
                     profile.to_s.titleize

      city_part = city.present? ? " - #{city}" : " BiH"
      "#{profile_name}#{city_part}"
    end

    def add_experiences_to_plan(plan, days_data, available_experiences)
      return if days_data.blank?

      experience_map = available_experiences.index_by(&:id)

      days_data.each do |day_data|
        day_number = day_data[:day_number] || 1
        experience_ids = day_data[:experience_ids] || []

        experience_ids.each_with_index do |exp_id, position|
          experience = experience_map[exp_id]
          next unless experience

          PlanExperience.create(
            plan: plan,
            experience: experience,
            day_number: day_number,
            position: position + 1
          )
        end
      end
    end

    def determine_primary_city(proposal, experiences)
      # Pokušaj odrediti primarni grad iz Experience-a u planu
      exp_ids = proposal[:days]&.flat_map { |d| d[:experience_ids] } || []
      return nil if exp_ids.empty?

      cities = experiences.select { |e| exp_ids.include?(e.id) }
                         .flat_map { |e| e.locations.pluck(:city) }
                         .compact

      cities.group_by(&:itself).max_by { |_, v| v.size }&.first
    end

    def min_experiences_per_plan
      @min_experiences ||= Setting.get("plan.min_experiences", default: 2).to_i
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
      nil
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
