# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class AudioTourGeneratorTest < ActiveSupport::TestCase
    setup do
      @location = create_mock_location
      @generator = Ai::AudioTourGenerator.new(@location)
    end

    # === Initialization tests ===

    test "initializes with location" do
      generator = Ai::AudioTourGenerator.new(@location)
      assert_equal @location, generator.instance_variable_get(:@location)
    end

    # === Constants tests ===

    test "TTS_PROVIDERS includes elevenlabs openai google" do
      assert_includes Ai::AudioTourGenerator::TTS_PROVIDERS, "elevenlabs"
      assert_includes Ai::AudioTourGenerator::TTS_PROVIDERS, "openai"
      assert_includes Ai::AudioTourGenerator::TTS_PROVIDERS, "google"
    end

    test "DEFAULT_PROVIDER is elevenlabs" do
      assert_equal "elevenlabs", Ai::AudioTourGenerator::DEFAULT_PROVIDER
    end

    test "ELEVENLABS_VOICES contains valid voice entries" do
      voices = Ai::AudioTourGenerator::ELEVENLABS_VOICES

      assert voices.any?, "Should have at least one voice"

      voices.each do |id, info|
        assert_kind_of String, id, "Voice ID should be a string"
        assert info[:name].present?, "Voice should have a name"
        assert info[:gender].present?, "Voice should have a gender"
        assert info[:style].present?, "Voice should have a style"
        assert %w[male female].include?(info[:gender]), "Gender should be male or female"
      end
    end

    # === audio_exists? tests ===

    test "audio_exists? returns false when no audio tour exists" do
      @location.define_singleton_method(:audio_tour_for) { |_locale| nil }

      refute @generator.audio_exists?(locale: "bs")
    end

    test "audio_exists? returns false when audio tour exists but audio not ready" do
      audio_tour = OpenStruct.new(audio_ready?: false)
      @location.define_singleton_method(:audio_tour_for) { |_locale| audio_tour }

      refute @generator.audio_exists?(locale: "bs")
    end

    test "audio_exists? returns true when audio tour exists and ready" do
      audio_tour = OpenStruct.new(audio_ready?: true)
      @location.define_singleton_method(:audio_tour_for) { |_locale| audio_tour }

      assert @generator.audio_exists?(locale: "bs")
    end

    test "audio_exists? uses default locale bs" do
      called_locale = nil
      @location.define_singleton_method(:audio_tour_for) do |locale|
        called_locale = locale
        nil
      end

      @generator.audio_exists?

      assert_equal "bs", called_locale
    end

    # === audio_info tests ===

    test "audio_info returns nil when no audio tour" do
      @location.define_singleton_method(:audio_tour_for) { |_locale| nil }

      result = @generator.audio_info(locale: "en")
      assert_nil result
    end

    test "audio_info returns nil when audio not ready" do
      audio_tour = OpenStruct.new(audio_ready?: false)
      @location.define_singleton_method(:audio_tour_for) { |_locale| audio_tour }

      result = @generator.audio_info(locale: "en")
      assert_nil result
    end

    test "audio_info returns hash with audio details when ready" do
      attachment = OpenStruct.new(
        filename: OpenStruct.new(to_s: "test-tour-en.mp3"),
        content_type: "audio/mpeg",
        byte_size: 1024000,
        created_at: Time.current
      )

      audio_tour = OpenStruct.new(
        audio_ready?: true,
        audio_file: attachment,
        language_name: "English",
        estimated_duration: "3.5 min",
        word_count: 525
      )

      @location.define_singleton_method(:audio_tour_for) { |_locale| audio_tour }

      result = @generator.audio_info(locale: "en")

      assert_equal "en", result[:locale]
      assert_equal "English", result[:language]
      assert_equal "test-tour-en.mp3", result[:filename]
      assert_equal "audio/mpeg", result[:content_type]
      assert_equal 1024000, result[:byte_size]
      assert_equal "3.5 min", result[:duration]
      assert_equal 525, result[:word_count]
    end

    # === generate tests ===

    test "generate returns already_exists status when audio exists and not forcing" do
      audio_tour = OpenStruct.new(
        audio_ready?: true,
        audio_file: OpenStruct.new(
          filename: OpenStruct.new(to_s: "test.mp3"),
          content_type: "audio/mpeg",
          byte_size: 1024,
          created_at: Time.current
        ),
        language_name: "Bosanski",
        estimated_duration: "4.0 min",
        word_count: 600
      )

      @location.define_singleton_method(:audio_tour_for) { |_locale| audio_tour }

      result = @generator.generate(locale: "bs", force: false)

      assert_equal :already_exists, result[:status]
      assert_equal @location.name, result[:location]
      assert_equal "bs", result[:locale]
      assert result[:audio_info].present?
    end

    test "generate creates new audio tour when none exists" do
      audio_tour = create_mock_audio_tour
      audio_tours_relation = create_audio_tours_relation(audio_tour)
      @location.define_singleton_method(:audio_tours) { audio_tours_relation }
      @location.define_singleton_method(:audio_tour_for) { |_| nil }
      @location.define_singleton_method(:audio_tour_metadata) { {} }
      @location.define_singleton_method(:has_attribute?) { |_| true }
      @location.define_singleton_method(:update_column) { |_col, _val| true }

      stub_ai_queue_response("This is a test script for the audio tour. " * 50) do
        stub_elevenlabs_success do
          stub_tts_settings do
            result = @generator.generate(locale: "bs", force: false)

            assert_equal :generated, result[:status]
            assert_equal @location.name, result[:location]
            assert_equal "bs", result[:locale]
            assert result[:script_length] > 0
          end
        end
      end
    end

    test "generate forces regeneration when force is true" do
      existing_audio_tour = create_mock_audio_tour_with_attachment
      audio_tours_relation = create_audio_tours_relation(existing_audio_tour)
      @location.define_singleton_method(:audio_tours) { audio_tours_relation }

      # audio_exists? should return true initially
      @location.define_singleton_method(:audio_tour_for) do |locale|
        existing_audio_tour
      end

      @location.define_singleton_method(:audio_tour_metadata) { {} }
      @location.define_singleton_method(:has_attribute?) { |_| true }
      @location.define_singleton_method(:update_column) { |_col, _val| true }

      stub_ai_queue_response("This is a regenerated script for the audio tour. " * 50) do
        stub_elevenlabs_success do
          stub_tts_settings do
            result = @generator.generate(locale: "bs", force: true)

            assert_equal :generated, result[:status]
          end
        end
      end
    end

    # === generate_multilingual tests ===

    test "generate_multilingual generates for multiple locales" do
      generated_locales = []
      @generator.define_singleton_method(:generate) do |locale:, force:|
        generated_locales << locale
        { locale: locale, status: :generated }
      end

      result = @generator.generate_multilingual(locales: %w[bs en de], force: false)

      assert_equal @location.name, result[:location]
      assert_equal 3, result[:summary][:generated]
      assert_equal %w[bs en de].sort, generated_locales.sort
    end

    test "generate_multilingual counts skipped correctly" do
      @generator.define_singleton_method(:generate) do |locale:, force:|
        { locale: locale, status: :already_exists }
      end

      result = @generator.generate_multilingual(locales: %w[bs en], force: false)

      assert_equal 0, result[:summary][:generated]
      assert_equal 2, result[:summary][:skipped]
    end

    test "generate_multilingual handles failures gracefully" do
      call_count = 0
      @generator.define_singleton_method(:generate) do |locale:, force:|
        call_count += 1
        if call_count == 2
          raise StandardError, "TTS service unavailable"
        end
        { locale: locale, status: :generated }
      end

      result = @generator.generate_multilingual(locales: %w[bs en de], force: false)

      assert_equal 2, result[:summary][:generated]
      assert_equal 1, result[:summary][:failed]
      assert result[:locales]["en"][:error].present?
    end

    test "generate_multilingual uses default locales when not specified" do
      generated_locales = []
      @generator.define_singleton_method(:generate) do |locale:, force:|
        generated_locales << locale
        { locale: locale, status: :generated }
      end

      @generator.generate_multilingual

      assert_equal AudioTour::DEFAULT_GENERATION_LOCALES.sort, generated_locales.sort
    end

    # === generate_batch class method tests ===

    test "generate_batch processes multiple locations" do
      locations = [
        create_mock_location(name: "Location 1"),
        create_mock_location(name: "Location 2")
      ]

      Ai::AudioTourGenerator.stub :new, ->(loc) {
        mock_gen = Object.new
        mock_gen.define_singleton_method(:generate_multilingual) do |locales:, force:|
          { summary: { generated: 2, skipped: 1, failed: 0 } }
        end
        mock_gen
      } do
        result = Ai::AudioTourGenerator.generate_batch(locations, locales: %w[bs en], force: false)

        assert_equal 2, result[:total_locations]
        assert_equal 4, result[:generated]
        assert_equal 2, result[:skipped]
      end
    end

    test "generate_batch handles location-level errors" do
      locations = [
        create_mock_location(name: "Good Location"),
        create_mock_location(name: "Bad Location")
      ]

      call_count = 0
      Ai::AudioTourGenerator.stub :new, ->(loc) {
        call_count += 1
        mock_gen = Object.new
        if call_count == 2
          mock_gen.define_singleton_method(:generate_multilingual) do |**_|
            raise StandardError, "Location processing failed"
          end
        else
          mock_gen.define_singleton_method(:generate_multilingual) do |**_|
            { summary: { generated: 2, skipped: 0, failed: 0 } }
          end
        end
        mock_gen
      } do
        result = Ai::AudioTourGenerator.generate_batch(locations, locales: %w[bs en])

        assert_equal 2, result[:generated]
        assert_equal 2, result[:failed] # Both locales failed for bad location
        assert result[:errors].any? { |e| e[:location] == "Bad Location" }
      end
    end

    # === generate_batch_single_locale class method tests ===

    test "generate_batch_single_locale processes locations with single locale" do
      locations = [
        create_mock_location(name: "Location 1"),
        create_mock_location(name: "Location 2")
      ]

      Ai::AudioTourGenerator.stub :new, ->(loc) {
        mock_gen = Object.new
        mock_gen.define_singleton_method(:generate) do |locale:, force:|
          { status: :generated }
        end
        mock_gen
      } do
        result = Ai::AudioTourGenerator.generate_batch_single_locale(locations, locale: "en")

        assert_equal 2, result[:generated]
        assert_equal 0, result[:skipped]
        assert_equal 0, result[:failed]
      end
    end

    test "generate_batch_single_locale counts skipped and failed" do
      locations = [
        create_mock_location(name: "Location 1"),
        create_mock_location(name: "Location 2"),
        create_mock_location(name: "Location 3")
      ]

      call_count = 0
      Ai::AudioTourGenerator.stub :new, ->(loc) {
        call_count += 1
        mock_gen = Object.new
        case call_count
        when 1
          mock_gen.define_singleton_method(:generate) { |**_| { status: :generated } }
        when 2
          mock_gen.define_singleton_method(:generate) { |**_| { status: :already_exists } }
        when 3
          mock_gen.define_singleton_method(:generate) { |**_| raise StandardError, "Error" }
        end
        mock_gen
      } do
        result = Ai::AudioTourGenerator.generate_batch_single_locale(locations)

        assert_equal 1, result[:generated]
        assert_equal 1, result[:skipped]
        assert_equal 1, result[:failed]
      end
    end

    # === generate_tour_script tests ===

    test "generate_tour_script uses OpenaiQueue for script generation" do
      prompt_sent = nil

      Ai::OpenaiQueue.stub :request, ->(prompt:, schema:, context:) {
        prompt_sent = prompt
        "This is the generated tour script."
      } do
        result = @generator.generate_tour_script("en")

        assert_equal "This is the generated tour script.", result
        assert prompt_sent.include?(@location.name)
        assert prompt_sent.include?("English")
      end
    end

    test "generate_tour_script strips markdown code blocks from response" do
      Ai::OpenaiQueue.stub :request, ->(**_) {
        "```\nThis is the script.```"
      } do
        result = @generator.generate_tour_script("bs")

        # The service removes markdown code blocks and strips the result
        assert_equal "This is the script.", result
      end
    end

    test "generate_tour_script includes cultural context" do
      prompt_sent = nil

      Ai::OpenaiQueue.stub :request, ->(prompt:, **_) {
        prompt_sent = prompt
        "Script content"
      } do
        @generator.generate_tour_script("bs")

        # The cultural context uses "IJEKAVICU" (Bosnian accusative form) in the warning text
        assert prompt_sent.include?("IJEKAVICU"), "Prompt should include ijekavica warning for Bosnian (IJEKAVICU)"
      end
    end

    # === available_languages tests ===

    test "available_languages returns array of language info" do
      audio_tour_1 = OpenStruct.new(locale: "bs", language_name: "Bosanski", estimated_duration: "4.0 min")
      audio_tour_2 = OpenStruct.new(locale: "en", language_name: "English", estimated_duration: "3.5 min")

      audio_tours_relation = Object.new
      audio_tours_relation.define_singleton_method(:with_audio) { [ audio_tour_1, audio_tour_2 ] }
      @location.define_singleton_method(:audio_tours) { audio_tours_relation }

      result = @generator.available_languages

      assert_equal 2, result.length
      assert result.any? { |l| l[:locale] == "bs" && l[:language] == "Bosanski" }
      assert result.any? { |l| l[:locale] == "en" && l[:language] == "English" }
    end

    # === available_voices class method tests ===

    test "available_voices returns array of voice hashes" do
      voices = Ai::AudioTourGenerator.available_voices

      assert_kind_of Array, voices
      assert voices.any?

      voice = voices.first
      assert voice[:id].present?
      assert voice[:name].present?
      assert voice[:gender].present?
      assert voice[:style].present?
    end

    # === TTS provider tests ===

    test "openai_tts raises error when API key not configured" do
      Setting.stub :get, ->(key, **opts) {
        key == "tts.openai_api_key" ? nil : opts[:default]
      } do
        error = assert_raises(Ai::AudioTourGenerator::GenerationError) do
          @generator.send(:openai_tts, "Test script", "en")
        end

        assert_match(/API key not configured/, error.message)
      end
    end

    test "elevenlabs_tts raises error when API key not configured" do
      ENV.stub :[], ->(key) { key == "ELEVENLABS_API_KEY" ? nil : nil } do
        Setting.stub :get, ->(key, **opts) {
          key == "tts.elevenlabs_api_key" ? nil : opts[:default]
        } do
          error = assert_raises(Ai::AudioTourGenerator::GenerationError) do
            @generator.send(:elevenlabs_tts, "Test script", "en")
          end

          assert_match(/ElevenLabs API key not configured/, error.message)
        end
      end
    end

    test "google_tts raises not implemented error" do
      error = assert_raises(Ai::AudioTourGenerator::GenerationError) do
        @generator.send(:google_tts, "Test script", "en")
      end

      assert_match(/not yet implemented/, error.message)
    end

    test "text_to_speech raises error for unknown provider" do
      Setting.stub :get, ->(key, **opts) {
        key == "tts.provider" ? "unknown_provider" : opts[:default]
      } do
        error = assert_raises(Ai::AudioTourGenerator::GenerationError) do
          @generator.send(:text_to_speech, "Test script", "en")
        end

        assert_match(/Unknown TTS provider/, error.message)
      end
    end

    # === Voice selection tests ===

    test "get_voice_id returns configured voice when not random" do
      Setting.stub :get, ->(key, **opts) {
        key == "tts.elevenlabs_voice_id" ? "custom_voice_123" : opts[:default]
      } do
        result = @generator.send(:get_voice_id)
        assert_equal "custom_voice_123", result
      end
    end

    test "get_voice_id returns random voice when set to random" do
      Setting.stub :get, ->(key, **opts) {
        key == "tts.elevenlabs_voice_id" ? "random" : opts[:default]
      } do
        result = @generator.send(:get_voice_id)
        assert Ai::AudioTourGenerator::ELEVENLABS_VOICES.keys.include?(result)
      end
    end

    test "random_voice_id returns valid voice from list" do
      voice_id = @generator.send(:random_voice_id)
      assert Ai::AudioTourGenerator::ELEVENLABS_VOICES.keys.include?(voice_id)
    end

    test "random_voice_by_gender returns voice of correct gender" do
      male_voice = @generator.send(:random_voice_by_gender, "male")
      female_voice = @generator.send(:random_voice_by_gender, "female")

      male_info = Ai::AudioTourGenerator::ELEVENLABS_VOICES[male_voice]
      female_info = Ai::AudioTourGenerator::ELEVENLABS_VOICES[female_voice]

      assert_equal "male", male_info[:gender]
      assert_equal "female", female_info[:gender]
    end

    # === locale_to_language tests ===

    test "locale_to_language returns correct language names" do
      # These are returned from AudioTour::SUPPORTED_LOCALES with native names
      mappings = {
        "en" => "English",
        "bs" => "Bosanski",  # Native Bosnian name
        "hr" => "Hrvatski",  # Native Croatian name
        "de" => "Deutsch",   # Native German name
        "fr" => "Français"   # Native French name
      }

      mappings.each do |locale, expected_language|
        result = @generator.send(:locale_to_language, locale)
        assert_equal expected_language, result, "Expected #{expected_language} for locale #{locale}"
      end
    end

    test "locale_to_language returns English for unknown locale" do
      result = @generator.send(:locale_to_language, "unknown")
      assert_equal "English", result
    end

    # === estimate_duration tests ===

    test "estimate_duration calculates based on 150 words per minute" do
      # 150 words = 1 minute
      script_150_words = ([ "word" ] * 150).join(" ")
      result = @generator.send(:estimate_duration, script_150_words)
      assert_equal "1.0 min", result

      # 300 words = 2 minutes
      script_300_words = ([ "word" ] * 300).join(" ")
      result = @generator.send(:estimate_duration, script_300_words)
      assert_equal "2.0 min", result

      # 225 words = 1.5 minutes
      script_225_words = ([ "word" ] * 225).join(" ")
      result = @generator.send(:estimate_duration, script_225_words)
      assert_equal "1.5 min", result
    end

    # === Error classes tests ===

    test "GenerationError is a subclass of StandardError" do
      assert Ai::AudioTourGenerator::GenerationError < StandardError
    end

    test "AudioAlreadyExistsError is a subclass of StandardError" do
      assert Ai::AudioTourGenerator::AudioAlreadyExistsError < StandardError
    end

    # === build_script_prompt tests ===

    test "build_script_prompt includes location details" do
      prompt = @generator.send(:build_script_prompt, "en")

      assert prompt.include?(@location.name), "Prompt should include location name"
      assert prompt.include?("Sarajevo"), "Prompt should include city name"
      assert prompt.include?("place"), "Prompt should include location type"
    end

    test "build_script_prompt includes narration requirements" do
      prompt = @generator.send(:build_script_prompt, "en")

      assert prompt.include?("4-6 minutes"), "Prompt should specify duration"
      assert prompt.include?("600-900 words"), "Prompt should specify word count"
      assert prompt.include?("English"), "Prompt should include target language"
    end

    test "build_script_prompt includes Bosnian language warning for bs locale" do
      prompt = @generator.send(:build_script_prompt, "bs")

      # The warning is in Bosnian: "IJEKAVICU" not "IJEKAVICA"
      assert prompt.include?("IJEKAVICU"), "Prompt should include ijekavica warning (IJEKAVICU)"
      assert prompt.include?("lijepo"), "Prompt should include correct example"
      assert prompt.downcase.include?("ekavic"), "Prompt should mention ekavica to avoid"
    end

    # === fetch_voices_from_api class method tests ===

    test "fetch_voices_from_api raises error when API key not configured" do
      ENV.stub :[], ->(key) { key == "ELEVENLABS_API_KEY" ? nil : nil } do
        Setting.stub :get, ->(key, **opts) {
          key == "tts.elevenlabs_api_key" ? nil : opts[:default]
        } do
          error = assert_raises(Ai::AudioTourGenerator::GenerationError) do
            Ai::AudioTourGenerator.fetch_voices_from_api
          end

          assert_match(/API key not configured/, error.message)
        end
      end
    end

    # === cached_voices class method tests ===

    test "cached_voices falls back to static list on API error" do
      # Clear any existing cache
      Ai::AudioTourGenerator.clear_voice_cache!

      ENV.stub :[], ->(key) { key == "ELEVENLABS_API_KEY" ? nil : nil } do
        Setting.stub :get, ->(key, **opts) {
          key == "tts.elevenlabs_api_key" ? nil : opts[:default]
        } do
          voices = Ai::AudioTourGenerator.cached_voices

          assert voices.any?
          assert voices.first[:name].present?
        end
      end

      # Clear cache after test
      Ai::AudioTourGenerator.clear_voice_cache!
    end

    test "clear_voice_cache! clears the cached voices" do
      Ai::AudioTourGenerator.instance_variable_set(:@cached_voices, [ "test" ])
      Ai::AudioTourGenerator.clear_voice_cache!
      assert_nil Ai::AudioTourGenerator.instance_variable_get(:@cached_voices)
    end

    # === Integration-like tests ===

    test "full generation flow with mocked dependencies" do
      # Create audio tour that will get "attached" audio during generation
      audio_tour = create_mock_audio_tour_for_integration
      audio_tours_relation = create_audio_tours_relation(audio_tour)
      @location.define_singleton_method(:audio_tours) { audio_tours_relation }
      @location.define_singleton_method(:audio_tour_for) { |locale| locale == "en" ? audio_tour : nil }
      @location.define_singleton_method(:audio_tour_metadata) { {} }
      @location.define_singleton_method(:has_attribute?) { |_| true }
      @location.define_singleton_method(:update_column) { |_col, _val| true }

      script = "Welcome to this beautiful location in Sarajevo. " * 30

      stub_ai_queue_response(script) do
        stub_elevenlabs_success do
          stub_tts_settings do
            result = @generator.generate(locale: "en", force: false)

            assert_equal :generated, result[:status]
            assert_equal "Test Location", result[:location]
            assert_equal "en", result[:locale]
            assert result[:script_length] > 0
            assert result[:duration_estimate].present?
          end
        end
      end
    end

    private

    def create_mock_location(id: nil, name: "Test Location", city: "Sarajevo")
      mock_city = OpenStruct.new(name: city)

      mock = OpenStruct.new(
        id: id || rand(1000..9999),
        name: name,
        city: mock_city,
        location_type: "place",
        tags: [ "historical", "cultural" ],
        suitable_experiences: [ "culture", "history" ],
        audio_tour_metadata: {}
      )

      mock.define_singleton_method(:translate) { |field, locale| "Translated #{field}" }
      mock.define_singleton_method(:audio_tour_for) { |_locale| nil }
      mock.define_singleton_method(:audio_tours) { OpenStruct.new(with_audio: []) }

      mock
    end

    def create_mock_audio_tour(audio_ready: false)
      audio_file = Object.new
      audio_file.define_singleton_method(:attach) { |**_| true }
      audio_file.define_singleton_method(:attached?) { audio_ready }
      audio_file.define_singleton_method(:purge) { true }

      mock = OpenStruct.new(
        locale: "bs",
        script: nil,
        word_count: nil,
        duration: nil,
        tts_provider: nil,
        voice_id: nil,
        metadata: {},
        audio_file: audio_file
      )

      mock.define_singleton_method(:audio_ready?) { audio_file.attached? }
      mock.define_singleton_method(:language_name) { "Bosanski" }
      mock.define_singleton_method(:estimated_duration) { "4.0 min" }
      mock.define_singleton_method(:assign_attributes) { |attrs| attrs.each { |k, v| mock.send("#{k}=", v) if mock.respond_to?("#{k}=") } }
      mock.define_singleton_method(:save!) { true }

      mock
    end

    def create_mock_audio_tour_with_attachment
      attachment = OpenStruct.new(
        filename: OpenStruct.new(to_s: "test-tour-bs.mp3"),
        content_type: "audio/mpeg",
        byte_size: 1024000,
        created_at: Time.current
      )

      audio_file = Object.new
      audio_file.define_singleton_method(:attach) { |**_| true }
      audio_file.define_singleton_method(:attached?) { true }
      audio_file.define_singleton_method(:purge) { true }
      audio_file.define_singleton_method(:filename) { attachment.filename }
      audio_file.define_singleton_method(:content_type) { attachment.content_type }
      audio_file.define_singleton_method(:byte_size) { attachment.byte_size }
      audio_file.define_singleton_method(:created_at) { attachment.created_at }

      mock = OpenStruct.new(
        locale: "bs",
        script: "Existing script",
        word_count: 500,
        duration: "3.5 min",
        tts_provider: "elevenlabs",
        voice_id: "21m00Tcm4TlvDq8ikWAM",
        metadata: {},
        audio_file: audio_file
      )

      mock.define_singleton_method(:audio_ready?) { true }
      mock.define_singleton_method(:language_name) { "Bosanski" }
      mock.define_singleton_method(:estimated_duration) { "3.5 min" }
      mock.define_singleton_method(:assign_attributes) { |attrs| attrs.each { |k, v| mock.send("#{k}=", v) if mock.respond_to?("#{k}=") } }
      mock.define_singleton_method(:save!) { true }

      mock
    end

    # Mock for integration test - audio_file becomes "attached" after attach() is called
    def create_mock_audio_tour_for_integration
      attached = false
      attachment = OpenStruct.new(
        filename: OpenStruct.new(to_s: "test-tour-en.mp3"),
        content_type: "audio/mpeg",
        byte_size: 1024000,
        created_at: Time.current
      )

      audio_file = Object.new
      audio_file.define_singleton_method(:attach) { |**_| attached = true }
      audio_file.define_singleton_method(:attached?) { attached }
      audio_file.define_singleton_method(:purge) { attached = false }
      audio_file.define_singleton_method(:filename) { attached ? attachment.filename : nil }
      audio_file.define_singleton_method(:content_type) { attached ? attachment.content_type : nil }
      audio_file.define_singleton_method(:byte_size) { attached ? attachment.byte_size : nil }
      audio_file.define_singleton_method(:created_at) { attached ? attachment.created_at : nil }

      mock = OpenStruct.new(
        locale: "en",
        script: nil,
        word_count: nil,
        duration: nil,
        tts_provider: nil,
        voice_id: nil,
        metadata: {},
        audio_file: audio_file
      )

      mock.define_singleton_method(:audio_ready?) { audio_file.attached? }
      mock.define_singleton_method(:language_name) { "English" }
      mock.define_singleton_method(:estimated_duration) { mock.duration || "4.0 min" }
      mock.define_singleton_method(:assign_attributes) { |attrs| attrs.each { |k, v| mock.send("#{k}=", v) if mock.respond_to?("#{k}=") } }
      mock.define_singleton_method(:save!) { true }

      mock
    end

    def create_audio_tours_relation(audio_tour)
      relation = Object.new
      relation.define_singleton_method(:find_or_initialize_by) { |_| audio_tour }
      relation.define_singleton_method(:with_audio) { [] }
      relation
    end

    def stub_ai_queue_response(response)
      Ai::OpenaiQueue.stub :request, ->(**_) { response } do
        yield
      end
    end

    def stub_elevenlabs_success
      mock_response = Object.new
      mock_response.define_singleton_method(:success?) { true }
      mock_response.define_singleton_method(:body) { "fake_audio_data" }

      mock_connection = Object.new
      mock_connection.define_singleton_method(:post) { |_path, &_block| mock_response }

      Faraday.stub :new, ->(url:, &_block) { mock_connection } do
        yield
      end
    end

    def stub_tts_settings
      Setting.stub :get, ->(key, **opts) {
        case key
        when "tts.provider"
          "elevenlabs"
        when "tts.elevenlabs_voice_id"
          "21m00Tcm4TlvDq8ikWAM" # Rachel
        when "tts.elevenlabs_model_id"
          "eleven_multilingual_v2"
        else
          opts[:default]
        end
      } do
        ENV.stub :[], ->(key) {
          key == "ELEVENLABS_API_KEY" ? "test_api_key" : nil
        } do
          yield
        end
      end
    end
  end
end
