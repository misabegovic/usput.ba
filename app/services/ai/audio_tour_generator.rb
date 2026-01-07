module Ai
  # AI-powered audio tour generator that creates narrated tours for locations
  # Uses TTS (Text-to-Speech) to generate audio from AI-written scripts
  #
  # Supports multilingual audio tour generation - creates audio tours in multiple
  # languages for each location, allowing users to listen in their preferred language.
  #
  # Default provider: ElevenLabs (eleven_multilingual_v2 model)
  # Configure via Settings:
  #   - tts.provider: "elevenlabs" (default), "openai", or "google"
  #   - tts.elevenlabs_api_key: Your ElevenLabs API key
  #   - tts.elevenlabs_voice_id: Voice ID (default: Rachel)
  #
  class AudioTourGenerator
    include Concerns::ErrorReporting

    class GenerationError < StandardError; end
    class AudioAlreadyExistsError < StandardError; end

    # Supported TTS providers (ElevenLabs is default for better multilingual support)
    TTS_PROVIDERS = %w[elevenlabs openai google].freeze
    DEFAULT_PROVIDER = "elevenlabs".freeze

    # Popular ElevenLabs voices for random selection
    # These are high-quality multilingual voices that work well for tour narration
    ELEVENLABS_VOICES = {
      "21m00Tcm4TlvDq8ikWAM" => { name: "Rachel", gender: "female", style: "calm, narrative" },
      "AZnzlk1XvdvUeBnXmlld" => { name: "Domi", gender: "female", style: "strong, expressive" },
      "EXAVITQu4vr4xnSDxMaL" => { name: "Bella", gender: "female", style: "soft, warm" },
      "ErXwobaYiN019PkySvjV" => { name: "Antoni", gender: "male", style: "well-rounded, expressive" },
      "MF3mGyEYCl7XYWbV9V6O" => { name: "Elli", gender: "female", style: "emotional, engaging" },
      "TxGEqnHWrfWFTfGW9XjX" => { name: "Josh", gender: "male", style: "deep, narrative" },
      "VR6AewLTigWG4xSOukaG" => { name: "Arnold", gender: "male", style: "confident, authoritative" },
      "pNInz6obpgDQGcFmaJgB" => { name: "Adam", gender: "male", style: "deep, warm" },
      "yoZ06aMxZJJ28mfd3POQ" => { name: "Sam", gender: "male", style: "dynamic, versatile" },
      "jBpfuIE2acCO8z3wKNLl" => { name: "Gigi", gender: "female", style: "childlike, animated" },
      "oWAxZDx7w5VEj9dCyTzz" => { name: "Grace", gender: "female", style: "gentle, soothing" },
      "pqHfZKP75CvOlQylNhV4" => { name: "Bill", gender: "male", style: "trustworthy, documentary" },
      "nPczCjzI2devNBz1zQrb" => { name: "Brian", gender: "male", style: "deep, narrative" },
      "N2lVS1w4EtoT3dr4eOWO" => { name: "Callum", gender: "male", style: "intense, transatlantic" },
      "IKne3meq5aSn9XLyUdCD" => { name: "Charlie", gender: "male", style: "natural, conversational" },
      "XB0fDUnXU5powFXDhCwa" => { name: "Charlotte", gender: "female", style: "natural, Swedish accent" },
      "Xb7hH8MSUJpSbSDYk0k2" => { name: "Alice", gender: "female", style: "confident, British" },
      "onwK4e9ZLuTAKqWW03F9" => { name: "Daniel", gender: "male", style: "authoritative, British" },
      "cjVigY5qzO86Huf0OWal" => { name: "Eric", gender: "male", style: "friendly, American" },
      "cgSgspJ2msm6clMCkdW9" => { name: "Jessica", gender: "female", style: "expressive, American" },
      "iP95p4xoKVk53GoZ742B" => { name: "Chris", gender: "male", style: "casual, American" },
      "XrExE9yKIg1WjnnlVkGX" => { name: "Lily", gender: "female", style: "warm, British" },
      "bIHbv24MWmeRgasZH58o" => { name: "Will", gender: "male", style: "friendly, American" },
      "JBFqnCBsd6RMkjVDRZzb" => { name: "George", gender: "male", style: "warm, British" },
      "FGY2WhTYpPnrIDTdsKH5" => { name: "Laura", gender: "female", style: "upbeat, American" }
    }.freeze

    def initialize(location)
      @location = location
      @chat = RubyLLM.chat
    end

    # Check if audio tour already exists for this location and locale
    # @param locale [String] Language code
    # @return [Boolean]
    def audio_exists?(locale: "bs")
      audio_tour = @location.audio_tour_for(locale)
      audio_tour&.audio_ready?
    end

    # Get audio tour info if it exists
    # @param locale [String] Language code
    # @return [Hash, nil]
    def audio_info(locale: "bs")
      audio_tour = @location.audio_tour_for(locale)
      return nil unless audio_tour&.audio_ready?

      attachment = audio_tour.audio_file
      {
        locale: locale,
        language: audio_tour.language_name,
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size,
        created_at: attachment.created_at,
        duration: audio_tour.estimated_duration,
        word_count: audio_tour.word_count
      }
    end

    # Generate an audio tour for the location in a single language
    # @param locale [String] Language code for the tour
    # @param force [Boolean] Force regeneration even if audio exists
    # @return [Hash] Result with audio file info
    def generate(locale: "bs", force: false)
      # Check if audio already exists
      if audio_exists?(locale: locale) && !force
        Rails.logger.info "[AI::AudioTourGenerator] Audio already exists for #{@location.name} in #{locale}, skipping (use force: true to regenerate)"
        return {
          location: @location.name,
          locale: locale,
          status: :already_exists,
          audio_info: audio_info(locale: locale)
        }
      end

      Rails.logger.info "[AI::AudioTourGenerator] Generating audio tour for #{@location.name} in #{locale}"

      # Find or create audio tour record
      audio_tour = @location.audio_tours.find_or_initialize_by(locale: locale.to_s)

      # Remove existing audio if forcing regeneration
      if audio_tour.audio_ready? && force
        Rails.logger.info "[AI::AudioTourGenerator] Force regenerating audio for #{@location.name} in #{locale}"
        audio_tour.audio_file.purge
      end

      # Step 1: Generate the tour script using AI
      script = generate_tour_script(locale)

      # Step 2: Select voice (do this before TTS so we use the same voice throughout)
      @selected_voice_id = get_voice_id
      voice_info = ELEVENLABS_VOICES[@selected_voice_id]
      voice_name = voice_info ? voice_info[:name] : "Custom"

      # Step 3: Convert script to speech using TTS
      audio_data = text_to_speech(script, locale)

      # Step 4: Update audio tour record with metadata
      audio_tour.assign_attributes(
        script: script,
        word_count: script.split.length,
        duration: estimate_duration(script),
        tts_provider: tts_provider,
        voice_id: @selected_voice_id,
        metadata: {
          generated_at: Time.current.iso8601,
          provider: tts_provider,
          voice_name: voice_name
        }
      )
      audio_tour.save!

      # Step 5: Attach audio file
      attach_audio(audio_tour, audio_data, locale)

      # Step 6: Also save to legacy metadata field for backwards compatibility
      save_script_metadata(script, locale)

      {
        location: @location.name,
        locale: locale,
        language: audio_tour.language_name,
        status: :generated,
        script_length: script.length,
        duration_estimate: audio_tour.estimated_duration,
        audio_info: audio_info(locale: locale)
      }
    end

    # Generate audio tours for multiple languages
    # @param locales [Array<String>] Language codes to generate
    # @param force [Boolean] Force regeneration even if audio exists
    # @return [Hash] Summary of results per locale
    def generate_multilingual(locales: AudioTour::DEFAULT_GENERATION_LOCALES, force: false)
      results = {
        location: @location.name,
        locales: {},
        summary: { generated: 0, skipped: 0, failed: 0 }
      }

      locales.each do |locale|
        begin
          result = generate(locale: locale.to_s, force: force)
          results[:locales][locale] = result

          case result[:status]
          when :generated
            results[:summary][:generated] += 1
          when :already_exists
            results[:summary][:skipped] += 1
          end
        rescue StandardError => e
          results[:summary][:failed] += 1
          results[:locales][locale] = {
            locale: locale,
            status: :failed,
            error: e.message
          }
          log_error("Failed for #{@location.name} in #{locale}: #{e.message}", exception: e, locale: locale)
        end
      end

      log_info("Multilingual generation complete for #{@location.name}: #{results[:summary]}")
      results
    end

    # Generate audio for multiple locations in multiple languages
    # @param locations [Array<Location>] Locations to generate audio for
    # @param locales [Array<String>] Language codes
    # @param force [Boolean] Force regeneration
    # @return [Hash] Summary of results
    def self.generate_batch(locations, locales: AudioTour::DEFAULT_GENERATION_LOCALES, force: false)
      results = {
        total_locations: locations.count,
        locales: locales,
        generated: 0,
        skipped: 0,
        failed: 0,
        errors: [],
        details: []
      }

      locations.each do |location|
        begin
          generator = new(location)
          result = generator.generate_multilingual(locales: locales, force: force)

          results[:generated] += result[:summary][:generated]
          results[:skipped] += result[:summary][:skipped]
          results[:failed] += result[:summary][:failed]
          results[:details] << result
        rescue StandardError => e
          results[:failed] += locales.count
          results[:errors] << { location: location.name, error: e.message }
          Rails.logger.error "[AI::AudioTourGenerator] Batch failed for #{location.name}: #{e.message}"
          Rollbar.error(e, location: location.name) if defined?(Rollbar)
        end
      end

      results
    end

    # Generate audio for a single location in a single language (for backwards compatibility)
    # @param locations [Array<Location>] Locations to generate audio for
    # @param locale [String] Language code
    # @param force [Boolean] Force regeneration
    # @return [Hash] Summary of results
    def self.generate_batch_single_locale(locations, locale: "bs", force: false)
      results = { generated: 0, skipped: 0, failed: 0, errors: [] }

      locations.each do |location|
        begin
          generator = new(location)
          result = generator.generate(locale: locale, force: force)

          if result[:status] == :generated
            results[:generated] += 1
          else
            results[:skipped] += 1
          end
        rescue StandardError => e
          results[:failed] += 1
          results[:errors] << { location: location.name, error: e.message }
          Rails.logger.error "[AI::AudioTourGenerator] Failed for #{location.name}: #{e.message}"
          Rollbar.error(e, location: location.name) if defined?(Rollbar)
        end
      end

      results
    end

    # Generate tour script only (for preview)
    # @param locale [String] Language code
    # @return [String] The tour script
    def generate_tour_script(locale = "bs")
      prompt = build_script_prompt(locale)
      response = @chat.ask(prompt)

      # Clean up the response
      script = response.content.strip
      script = script.gsub(/^```.*\n/, "").gsub(/```$/, "") # Remove markdown code blocks

      Rails.logger.info "[AI::AudioTourGenerator] Generated script: #{script.length} characters"
      script
    end

    # Get all available languages for this location
    def available_languages
      @location.audio_tours.with_audio.map do |tour|
        {
          locale: tour.locale,
          language: tour.language_name,
          duration: tour.estimated_duration
        }
      end
    end

    private

    def build_script_prompt(locale)
      language_name = locale_to_language(locale)

      <<~PROMPT
        #{Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT}

        ---

        TASK: Write an engaging audio tour narration for a location in Bosnia and Herzegovina.
        The narration should be written in #{language_name} and designed to be read aloud by a guide.

        LOCATION DETAILS:
        - Name: #{@location.name}
        - City: #{@location.city&.name || 'Bosnia and Herzegovina'}
        - Type: #{@location.location_type}
        - Description: #{@location.translate(:description, locale)}
        - Historical Context: #{@location.translate(:historical_context, locale) || 'N/A'}
        - Tags: #{@location.tags.join(', ')}
        - Experience Types: #{@location.suitable_experiences.join(', ')}

        NARRATION REQUIREMENTS:
        1. Length: 4-6 minutes when read aloud (approximately 600-900 words)
           - This is an in-depth audio tour, not a brief overview
           - Take time to tell the complete story of this place
        2. Style: Warm, engaging, conversational - like a passionate local guide sharing their favorite place
        3. Structure:
           - Atmospheric welcome and scene-setting introduction
           - Rich historical narrative with multiple eras and perspectives
           - Fascinating details, legends, local secrets, and anecdotes
           - Deep connection to Bosnian culture, traditions, and identity
           - Personal stories and local voices (quotes, sayings, proverbs)
           - Practical observations for visitors (what to notice, best viewpoints)
           - Thoughtful closing that invites reflection and further exploration

        4. Include:
           - Vivid sensory details (what visitors see, hear, smell, feel)
           - Local terminology with natural, conversational explanations
           - Personal touches ("Imagine standing here 500 years ago..." / "Notice how the light...")
           - Cultural context connecting to broader Bosnian and Balkan heritage
           - Stories of real people who lived, worked, or visited here
           - Interesting comparisons or connections to other places
           - Seasonal changes and different times of day

        5. Avoid:
           - Dry, encyclopedia-style descriptions
           - Overwhelming lists of dates and numbers (use them sparingly, meaningfully)
           - Generic tourism language
           - Rushing through important details

        Write the narration directly in #{language_name}. Do not include any stage directions,
        speaker names, or formatting - just the pure spoken text.

        ⚠️ KRITIČNO ZA BOSANSKI JEZIK (ako je locale "bs"):
        - OBAVEZNO koristiti IJEKAVICU: "lijepo", "vrijeme", "mjesto", "vidjeti", "bijelo", "stoljeća"
        - NIKAD ekavicu: NE "lepo", "vreme", "mesto", "videti", "belo", "stoleća"
        - Koristiti "historija" (NE "istorija"), "hiljada" (NE "tisuća")

        Begin the narration:
      PROMPT
    end

    def text_to_speech(script, locale)
      provider = tts_provider
      Rails.logger.info "[AI::AudioTourGenerator] Using TTS provider: #{provider}"

      case provider
      when "openai"
        openai_tts(script, locale)
      when "elevenlabs"
        elevenlabs_tts(script, locale)
      when "google"
        google_tts(script, locale)
      else
        raise GenerationError, "Unknown TTS provider: #{provider}"
      end
    end

    def openai_tts(script, locale)
      api_key = Setting.get("tts.openai_api_key")
      raise GenerationError, "OpenAI API key not configured" unless api_key.present?

      voice = Setting.get("tts.openai_voice", default: "nova")
      model = Setting.get("tts.openai_model", default: "tts-1")

      connection = Faraday.new(url: "https://api.openai.com") do |faraday|
        faraday.request :json
        faraday.options.timeout = 120
        faraday.adapter Faraday.default_adapter
      end

      response = connection.post("/v1/audio/speech") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: model,
          voice: voice,
          input: script,
          response_format: "mp3"
        }.to_json
      end

      unless response.success?
        error = JSON.parse(response.body) rescue { "error" => response.body }
        raise GenerationError, "OpenAI TTS failed: #{error}"
      end

      {
        data: response.body,
        content_type: "audio/mpeg",
        filename: "#{@location.name.parameterize}-tour-#{locale}.mp3"
      }
    end

    def elevenlabs_tts(script, locale)
      api_key = ENV["ELEVENLABS_API_KEY"] || Setting.get("tts.elevenlabs_api_key")
      raise GenerationError, "ElevenLabs API key not configured. Set ELEVENLABS_API_KEY env variable." unless api_key.present?

      # Use pre-selected voice if available, otherwise select now
      voice_id = @selected_voice_id || get_voice_id
      model_id = Setting.get("tts.elevenlabs_model_id", default: "eleven_multilingual_v2")

      connection = Faraday.new(url: "https://api.elevenlabs.io") do |faraday|
        faraday.request :json
        faraday.options.timeout = 120
        faraday.adapter Faraday.default_adapter
      end

      response = connection.post("/v1/text-to-speech/#{voice_id}") do |req|
        req.headers["xi-api-key"] = api_key
        req.headers["Content-Type"] = "application/json"
        req.headers["Accept"] = "audio/mpeg"
        req.body = {
          text: script,
          model_id: model_id,
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.75
          }
        }.to_json
      end

      unless response.success?
        error = JSON.parse(response.body) rescue { "error" => response.body }
        raise GenerationError, "ElevenLabs TTS failed: #{error}"
      end

      {
        data: response.body,
        content_type: "audio/mpeg",
        filename: "#{@location.name.parameterize}-tour-#{locale}.mp3"
      }
    end

    def google_tts(script, locale)
      # Google Cloud TTS implementation placeholder
      # Requires google-cloud-text_to_speech gem
      raise GenerationError, "Google TTS not yet implemented"
    end

    def attach_audio(audio_tour, audio_data, locale)
      audio_tour.audio_file.attach(
        io: StringIO.new(audio_data[:data]),
        filename: audio_data[:filename],
        content_type: audio_data[:content_type]
      )

      Rails.logger.info "[AI::AudioTourGenerator] Attached audio to #{@location.name} for locale #{locale}"
    end

    def save_script_metadata(script, locale)
      # Store the script in location metadata for backwards compatibility
      metadata = @location.audio_tour_metadata || {}
      metadata[locale] = {
        script: script,
        generated_at: Time.current.iso8601,
        word_count: script.split.length,
        provider: tts_provider
      }

      @location.update_column(:audio_tour_metadata, metadata) if @location.has_attribute?(:audio_tour_metadata)
    rescue StandardError => e
      # Non-critical, just log
      log_warn("Could not save script metadata: #{e.message}", exception: e)
    end

    def tts_provider
      # ElevenLabs is default for better multilingual support (Bosnian, Croatian, etc.)
      Setting.get("tts.provider", default: DEFAULT_PROVIDER)
    end

    def get_voice_id
      voice_setting = Setting.get("tts.elevenlabs_voice_id", default: "random")

      if voice_setting == "random"
        random_voice_id
      else
        voice_setting
      end
    end

    def random_voice_id
      voice_id = ELEVENLABS_VOICES.keys.sample
      voice_info = ELEVENLABS_VOICES[voice_id]
      Rails.logger.info "[AI::AudioTourGenerator] Randomly selected voice: #{voice_info[:name]} (#{voice_info[:gender]}, #{voice_info[:style]})"
      voice_id
    end

    # Get a random voice filtered by gender
    # @param gender [String] "male" or "female"
    # @return [String] Voice ID
    def random_voice_by_gender(gender)
      filtered = ELEVENLABS_VOICES.select { |_, info| info[:gender] == gender }
      voice_id = filtered.keys.sample
      voice_info = ELEVENLABS_VOICES[voice_id]
      Rails.logger.info "[AI::AudioTourGenerator] Randomly selected #{gender} voice: #{voice_info[:name]}"
      voice_id
    end

    # Get all available voices (static list)
    def self.available_voices
      ELEVENLABS_VOICES.map do |id, info|
        { id: id, name: info[:name], gender: info[:gender], style: info[:style] }
      end
    end

    # Fetch voices directly from ElevenLabs API (includes your cloned voices)
    # @return [Array<Hash>] List of available voices
    def self.fetch_voices_from_api
      api_key = ENV["ELEVENLABS_API_KEY"] || Setting.get("tts.elevenlabs_api_key")
      raise GenerationError, "ElevenLabs API key not configured. Set ELEVENLABS_API_KEY env variable." unless api_key.present?

      connection = Faraday.new(url: "https://api.elevenlabs.io") do |faraday|
        faraday.options.timeout = 30
        faraday.adapter Faraday.default_adapter
      end

      response = connection.get("/v1/voices") do |req|
        req.headers["xi-api-key"] = api_key
      end

      unless response.success?
        error = JSON.parse(response.body) rescue { "error" => response.body }
        raise GenerationError, "Failed to fetch voices: #{error}"
      end

      data = JSON.parse(response.body)
      data["voices"].map do |voice|
        {
          id: voice["voice_id"],
          name: voice["name"],
          category: voice["category"], # "premade", "cloned", "generated"
          labels: voice["labels"] || {},
          preview_url: voice["preview_url"]
        }
      end
    end

    # Cache voices from API and use for random selection
    # Falls back to static list if API fails
    def self.cached_voices
      @cached_voices ||= begin
        fetch_voices_from_api
      rescue StandardError => e
        Rails.logger.warn "[AI::AudioTourGenerator] Failed to fetch voices from API: #{e.message}, using static list"
        Rollbar.warning(e, message: "Failed to fetch voices from API, using static list") if defined?(Rollbar)
        available_voices
      end
    end

    # Clear cached voices (call after adding new cloned voices)
    def self.clear_voice_cache!
      @cached_voices = nil
    end

    def locale_to_language(locale)
      AudioTour::SUPPORTED_LOCALES[locale.to_sym] ||
        {
          "en" => "English",
          "bs" => "Bosnian",
          "hr" => "Croatian",
          "sr" => "Serbian",
          "de" => "German",
          "fr" => "French",
          "it" => "Italian",
          "es" => "Spanish",
          "pt" => "Portuguese",
          "nl" => "Dutch",
          "pl" => "Polish",
          "cs" => "Czech",
          "sk" => "Slovak",
          "sl" => "Slovenian",
          "tr" => "Turkish",
          "ar" => "Arabic"
        }[locale.to_s] || "English"
    end

    def estimate_duration(script)
      # Average speaking rate: ~150 words per minute
      word_count = script.split.length
      minutes = (word_count / 150.0).round(1)
      "#{minutes} min"
    end
  end
end
