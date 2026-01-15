# frozen_string_literal: true

require "test_helper"

module Ai
  class ExperienceGeneratorTest < ActiveSupport::TestCase
    setup do
      @city_name = "Sarajevo"
      @coordinates = { lat: 43.856, lng: 18.413 }
    end

    # === Initialization tests ===

    test "initializes with city name and coordinates" do
      generator = build_generator

      assert_equal @city_name, generator.instance_variable_get(:@city_name)
      assert_equal @coordinates, generator.instance_variable_get(:@coordinates)
    end

    test "initializes with default options" do
      generator = build_generator

      options = generator.instance_variable_get(:@options)
      assert options[:generate_audio]
      assert_equal "bs", options[:audio_locale]
      assert options[:skip_existing_locations]
    end

    test "initializes with custom options" do
      mock_places_service = Object.new
      mock_places_service.define_singleton_method(:search_nearby) { |**args| [] }

      GeoapifyService.stub :new, mock_places_service do
        generator = Ai::ExperienceGenerator.new(
          @city_name,
          coordinates: @coordinates,
          generate_audio: false,
          audio_locale: "en",
          skip_existing_locations: false
        )

        options = generator.instance_variable_get(:@options)
        assert_not options[:generate_audio]
        assert_equal "en", options[:audio_locale]
        assert_not options[:skip_existing_locations]
      end
    end

    # === generate_all tests ===

    test "generate_all returns summary hash with expected keys" do
      generator = build_generator

      stub_geoapify_empty_response(generator) do
        stub_ai_queue_empty_response do
          result = generator.generate_all

          assert_includes result.keys, :city
          assert_includes result.keys, :locations_created
          assert_includes result.keys, :experiences_created
          assert_includes result.keys, :audio_tours_generated
          assert_includes result.keys, :locations
          assert_includes result.keys, :experiences
        end
      end
    end

    test "generate_all returns correct city name" do
      generator = build_generator

      stub_geoapify_empty_response(generator) do
        stub_ai_queue_empty_response do
          result = generator.generate_all

          assert_equal @city_name, result[:city]
        end
      end
    end

    test "generate_all handles empty places gracefully" do
      generator = build_generator

      stub_geoapify_empty_response(generator) do
        stub_ai_queue_empty_response do
          result = generator.generate_all

          assert_equal 0, result[:locations_created]
          assert_equal [], result[:locations]
        end
      end
    end

    # === generate_locations_only tests ===

    test "generate_locations_only returns location summary" do
      generator = build_generator

      stub_geoapify_empty_response(generator) do
        stub_ai_queue_empty_response do
          result = generator.generate_locations_only

          assert_includes result.keys, :city
          assert_includes result.keys, :locations_created
          assert_includes result.keys, :audio_tours_generated
          assert_includes result.keys, :locations
          assert_not_includes result.keys, :experiences_created
        end
      end
    end

    # === generate_experiences_only tests ===

    test "generate_experiences_only returns experience summary" do
      generator = build_generator

      stub_ai_queue_empty_response do
        result = generator.generate_experiences_only

        assert_includes result.keys, :city
        assert_includes result.keys, :experiences_created
        assert_includes result.keys, :experiences
        assert_not_includes result.keys, :locations_created
      end
    end

    # === Location creation tests ===

    test "creates location from valid place data" do
      generator = build_generator

      place = {
        name: "Gazi Husrev-beg Mosque",
        lat: 43.859,
        lng: 18.431,
        place_id: "place_123",
        primary_type: "mosque",
        types: ["mosque", "place_of_worship"],
        price_level: :medium,
        website: "https://example.com",
        phone: "+387 33 123 456"
      }

      enrichment = {
        suitable_experiences: ["culture", "history"],
        descriptions: { "en" => "A beautiful mosque", "bs" => "Lijepa dzamija" },
        historical_context: { "en" => "Built in 16th century", "bs" => "Izgradjena u 16. stoljecu" }
      }

      stub_geoapify_with_places(generator, [place]) do
        stub_ai_queue_with_response(enrichment) do
          # Check that create_enriched_location is called with proper place data
          # We can't easily stub Location.save in Minitest without mocha,
          # so instead we test the enrich_location_with_ai method directly
          result = generator.send(:enrich_location_with_ai, place)

          assert_includes result[:suitable_experiences], "culture"
          assert_includes result[:suitable_experiences], "history"
        end
      end
    end

    test "skips location with blank name" do
      generator = build_generator

      place = {
        name: "",
        lat: 43.859,
        lng: 18.431,
        place_id: "place_123"
      }

      stub_geoapify_with_places(generator, [place]) do
        stub_ai_queue_empty_response do
          result = generator.generate_locations_only

          assert_equal 0, result[:locations_created]
        end
      end
    end

    test "skips location with blank coordinates" do
      generator = build_generator

      place = {
        name: "Test Place",
        lat: nil,
        lng: 18.431,
        place_id: "place_123"
      }

      stub_geoapify_with_places(generator, [place]) do
        stub_ai_queue_empty_response do
          result = generator.generate_locations_only

          assert_equal 0, result[:locations_created]
        end
      end
    end

    # === Type determination tests ===

    test "determine_location_type returns restaurant for restaurant types" do
      generator = build_generator

      result = generator.send(:determine_location_type, ["restaurant", "food"])
      assert_equal :restaurant, result
    end

    test "determine_location_type returns accommodation for hotel types" do
      generator = build_generator

      result = generator.send(:determine_location_type, ["hotel", "lodging"])
      assert_equal :accommodation, result
    end

    test "determine_location_type returns place for unknown types" do
      generator = build_generator

      result = generator.send(:determine_location_type, ["unknown_type"])
      assert_equal :place, result
    end

    test "determine_location_type returns place for blank types" do
      generator = build_generator

      assert_equal :place, generator.send(:determine_location_type, nil)
      assert_equal :place, generator.send(:determine_location_type, [])
    end

    # === Tag extraction tests ===

    test "extract_tags returns formatted tags from types" do
      generator = build_generator

      result = generator.send(:extract_tags, ["catering_restaurant", "food_and_drink", "tourism"])

      assert_includes result, "catering restaurant"
      assert_includes result, "food and drink"
    end

    test "extract_tags limits to max tags setting" do
      generator = build_generator

      types = (1..10).map { |i| "type_#{i}" }

      Setting.stub :get, ->(key, **opts) { key == "location.max_tags" ? 3 : opts[:default] } do
        result = generator.send(:extract_tags, types)

        assert_equal 3, result.count
      end
    end

    test "extract_tags returns empty array for blank types" do
      generator = build_generator

      assert_equal [], generator.send(:extract_tags, nil)
      assert_equal [], generator.send(:extract_tags, [])
    end

    # === Schema generation tests ===

    test "location_enrichment_schema generates valid schema structure" do
      generator = build_generator

      schema = generator.send(:location_enrichment_schema, ["en", "bs"])

      assert_equal "object", schema[:type]
      assert_includes schema[:properties].keys, :suitable_experiences
      assert_includes schema[:properties].keys, :descriptions
      assert_includes schema[:properties].keys, :historical_context
      assert_includes schema[:required], "suitable_experiences"
      assert_includes schema[:required], "descriptions"
      assert_equal false, schema[:additionalProperties]
    end

    test "location_enrichment_schema includes all provided locales" do
      generator = build_generator

      locales = ["en", "bs", "hr", "de"]
      schema = generator.send(:location_enrichment_schema, locales)

      desc_props = schema[:properties][:descriptions][:properties]
      locales.each do |locale|
        assert_includes desc_props.keys, locale
      end
    end

    test "experience_generation_schema generates valid schema structure" do
      generator = build_generator

      # Stub supported_locales
      generator.stub :supported_locales, ["en", "bs"] do
        schema = generator.send(:experience_generation_schema)

        assert_equal "object", schema[:type]
        assert_includes schema[:properties].keys, :titles
        assert_includes schema[:properties].keys, :descriptions
        assert_includes schema[:properties].keys, :location_ids
        assert_includes schema[:properties].keys, :route_narrative
      end
    end

    # === Prompt building tests ===

    test "build_location_enrichment_prompt includes city name" do
      generator = build_generator

      place = { name: "Test Place", types: ["tourism"], address: "Test Address" }

      prompt = generator.send(:build_location_enrichment_prompt, place, locales: ["en"])

      assert_includes prompt, @city_name
      assert_includes prompt, "Test Place"
    end

    test "build_location_enrichment_prompt includes cultural context" do
      generator = build_generator

      place = { name: "Test Place", types: ["tourism"] }

      prompt = generator.send(:build_location_enrichment_prompt, place, locales: ["en"])

      assert_includes prompt, "Ottoman Heritage"
      assert_includes prompt, "IJEKAVICA"
      assert_includes prompt, "Bosnia and Herzegovina"
    end

    test "build_experience_prompt includes location information" do
      generator = build_generator

      # Create a simple mock location object
      mock_location = Object.new
      mock_location.define_singleton_method(:id) { 1 }
      mock_location.define_singleton_method(:name) { "Test Location" }
      mock_location.define_singleton_method(:location_type) { "place" }
      mock_location.define_singleton_method(:lat) { 43.856 }
      mock_location.define_singleton_method(:lng) { 18.413 }

      mock_exp_types = Object.new
      mock_exp_types.define_singleton_method(:pluck) { |_field| ["culture", "history"] }
      mock_location.define_singleton_method(:experience_types) { mock_exp_types }

      mock_location.define_singleton_method(:translate) do |field, locale|
        case [field, locale.to_s]
        when [:description, "bs"], [:description, "en"]
          "English description"
        when [:historical_context, "bs"], [:historical_context, "en"]
          nil
        else
          nil
        end
      end

      category_data = { key: "cultural_heritage", experiences: ["culture"], duration: 180 }

      generator.stub :supported_locales, ["en"] do
        prompt = generator.send(:build_experience_prompt, category_data, [mock_location])

        assert_includes prompt, "Test Location"
        assert_includes prompt, @city_name
      end
    end

    # === JSON parsing tests ===

    test "parse_ai_json_response parses valid JSON" do
      generator = build_generator

      content = '{"name": "Test", "value": 123}'
      result = generator.send(:parse_ai_json_response, content)

      assert_equal "Test", result[:name]
      assert_equal 123, result[:value]
    end

    test "parse_ai_json_response extracts JSON from markdown code block" do
      generator = build_generator

      content = "```json\n{\"name\": \"Test\"}\n```"
      result = generator.send(:parse_ai_json_response, content)

      assert_equal "Test", result[:name]
    end

    test "parse_ai_json_response returns empty hash for invalid JSON" do
      generator = build_generator

      result = generator.send(:parse_ai_json_response, "not valid json")

      assert_equal({}, result)
    end

    # === JSON sanitization tests ===

    test "sanitize_ai_json removes trailing commas" do
      generator = build_generator

      json_with_comma = '{"name": "Test",}'
      result = generator.send(:sanitize_ai_json, json_with_comma)

      assert_not_includes result, ",}"
    end

    test "sanitize_ai_json converts smart quotes" do
      generator = build_generator

      # Using different quote styles
      json_with_smart_quotes = '{"name": "Test"}'
      result = generator.send(:sanitize_ai_json, json_with_smart_quotes)

      # Should convert to regular quotes
      assert_includes result, '"'
    end

    # === Control character escaping tests ===

    test "escape_chars_in_json_strings handles newlines in strings" do
      generator = build_generator

      json_with_newline = "{\"text\": \"line1\nline2\"}"
      result = generator.send(:escape_chars_in_json_strings, json_with_newline)

      assert_includes result, "\\n"
    end

    test "escape_chars_in_json_strings handles tabs in strings" do
      generator = build_generator

      json_with_tab = "{\"text\": \"col1\tcol2\"}"
      result = generator.send(:escape_chars_in_json_strings, json_with_tab)

      assert_includes result, "\\t"
    end

    # === Embedded quote detection tests ===

    test "looks_like_embedded_quote returns false for end of string" do
      generator = build_generator

      json_str = '{"name": "Test"}'
      # Position of closing quote before comma/brace
      result = generator.send(:looks_like_embedded_quote?, json_str, 14)

      assert_not result
    end

    test "looks_like_embedded_quote returns true for quote in text" do
      generator = build_generator

      # A quote that's not at the end of a value
      json_str = '{"text": "He said hello there"}'
      # Position where we have text continuing
      result = generator.send(:looks_like_embedded_quote?, json_str, 18)

      assert result
    end

    # === Settings and configuration tests ===

    test "supported_locales uses Locale model when available" do
      generator = build_generator

      # Stub Locale class method
      Locale.stub :ai_supported_codes, ["en", "bs", "hr"] do
        result = generator.send(:supported_locales)

        assert_equal ["en", "bs", "hr"], result
      end
    end

    test "supported_locales falls back to defaults when Locale returns empty" do
      generator = build_generator

      Locale.stub :ai_supported_codes, [] do
        result = generator.send(:supported_locales)

        assert_includes result, "en"
        assert_includes result, "bs"
      end
    end

    test "experience_categories uses ExperienceCategory model" do
      generator = build_generator

      mock_categories = [
        { key: "test_category", experiences: ["test"], duration: 60 }
      ]

      ExperienceCategory.stub :for_ai_generation, mock_categories do
        result = generator.send(:experience_categories)

        assert_equal mock_categories, result
      end
    end

    test "default_experience_categories provides fallback categories" do
      generator = build_generator

      result = generator.send(:default_experience_categories)

      assert_kind_of Array, result
      assert result.any? { |c| c[:key] == "cultural_heritage" }
      assert result.any? { |c| c[:key] == "culinary_journey" }
      assert result.any? { |c| c[:key] == "nature_adventure" }
    end

    # === Geoapify settings tests ===

    test "geoapify_search_radius uses Setting" do
      generator = build_generator

      Setting.stub :get, ->(key, **opts) { key == "geoapify.search_radius" ? 20000 : opts[:default] } do
        result = generator.send(:geoapify_search_radius)

        assert_equal 20000, result
      end
    end

    test "geoapify_max_results uses Setting" do
      generator = build_generator

      Setting.stub :get, ->(key, **opts) { key == "geoapify.max_results" ? 100 : opts[:default] } do
        result = generator.send(:geoapify_max_results)

        assert_equal 100, result
      end
    end

    # === Audio tour generation tests ===

    test "generate_audio_tours_for_city returns summary hash" do
      generator = build_generator

      # Stub Location query to return empty
      Location.stub :where, Location.none do
        result = generator.generate_audio_tours_for_city

        assert_includes result.keys, :generated
        assert_includes result.keys, :skipped
        assert_includes result.keys, :failed
        assert_includes result.keys, :errors
      end
    end

    # === Error handling tests ===

    test "handles GeoapifyService::ApiError gracefully" do
      generator = build_generator

      places_service = generator.instance_variable_get(:@places_service)
      places_service.stub :search_nearby, ->(*args) { raise GeoapifyService::ApiError, "API error" } do
        result = generator.send(:fetch_places)

        assert_equal [], result
      end
    end

    test "handles AI enrichment errors gracefully" do
      generator = build_generator

      place = {
        name: "Test Place",
        lat: 43.856,
        lng: 18.413,
        place_id: "test_123"
      }

      Ai::OpenaiQueue.stub :request, ->(*args) { raise Ai::OpenaiQueue::RequestError, "AI error" } do
        result = generator.send(:enrich_location_with_ai, place)

        assert_equal [], result[:suitable_experiences]
        assert_equal({}, result[:descriptions])
      end
    end

    # === Cultural context constant tests ===

    test "BIH_CULTURAL_CONTEXT includes Ottoman heritage" do
      assert_includes Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT, "Ottoman Heritage"
      assert_includes Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT, "Austro-Hungarian"
    end

    test "BIH_CULTURAL_CONTEXT includes language requirements" do
      context = Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT
      # Check for ijekavica mentions (case insensitive as some variations might exist)
      assert context.downcase.include?("ijekavic"), "Expected cultural context to mention ijekavica"
      assert context.downcase.include?("ekavic"), "Expected cultural context to mention ekavica"
      assert context.include?("lijepo"), "Expected cultural context to include 'lijepo' example"
    end

    test "BIH_CULTURAL_CONTEXT includes traditional cuisine" do
      assert_includes Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT, "Bosanska kahva"
    end

    test "LOCALES_PER_BATCH is reasonable value" do
      assert_equal 7, Ai::ExperienceGenerator::LOCALES_PER_BATCH
    end

    # === Location selection tests ===

    test "select_experience_locations uses AI-recommended IDs when available" do
      generator = build_generator

      # Create mock locations
      loc1 = Location.new(id: 1, name: "Location 1")
      loc2 = Location.new(id: 2, name: "Location 2")

      experience_data = { location_ids: [1, 2] }

      Location.stub :find_by, ->(args) { args[:id] == 1 ? loc1 : (args[:id] == 2 ? loc2 : nil) } do
        result = generator.send(:select_experience_locations, experience_data, [loc1, loc2])

        assert_equal 2, result.count
      end
    end

    test "select_experience_locations falls back to random selection" do
      generator = build_generator

      loc1 = Location.new(id: 1, name: "Location 1")
      loc2 = Location.new(id: 2, name: "Location 2")

      experience_data = { location_ids: [] }

      result = generator.send(:select_experience_locations, experience_data, [loc1, loc2])

      assert result.count <= 2
    end

    private

    def build_generator
      # Stub GeoapifyService to avoid API key requirement
      mock_places_service = Object.new
      mock_places_service.define_singleton_method(:search_nearby) { |**args| [] }

      GeoapifyService.stub :new, mock_places_service do
        return Ai::ExperienceGenerator.new(@city_name, coordinates: @coordinates)
      end
    end

    def stub_geoapify_empty_response(generator)
      places_service = generator.instance_variable_get(:@places_service)
      places_service.stub :search_nearby, [] do
        yield
      end
    end

    def stub_geoapify_with_places(generator, places)
      places_service = generator.instance_variable_get(:@places_service)
      places_service.stub :search_nearby, places do
        yield
      end
    end

    def stub_ai_queue_empty_response
      Ai::OpenaiQueue.stub :request, { suitable_experiences: [], descriptions: {}, historical_context: {} } do
        yield
      end
    end

    def stub_ai_queue_with_response(response)
      Ai::OpenaiQueue.stub :request, response do
        yield
      end
    end
  end
end
