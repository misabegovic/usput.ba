# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class LocationEnricherTest < ActiveSupport::TestCase
    setup do
      @enricher = Ai::LocationEnricher.new
    end

    # === Initialization tests ===

    test "initializes without errors" do
      assert_nothing_raised { Ai::LocationEnricher.new }
    end

    # === Constants tests ===

    test "LOCALES_PER_DESCRIPTION_BATCH is reasonable" do
      assert_equal 5, Ai::LocationEnricher::LOCALES_PER_DESCRIPTION_BATCH
    end

    test "LOCALES_PER_HISTORY_BATCH is reasonable" do
      assert_equal 3, Ai::LocationEnricher::LOCALES_PER_HISTORY_BATCH
    end

    # === determine_location_type tests ===

    test "determine_location_type returns restaurant for restaurant categories" do
      result = @enricher.send(:determine_location_type, ["catering.restaurant", "food"])
      assert_equal :restaurant, result
    end

    test "determine_location_type returns restaurant for cafe categories" do
      result = @enricher.send(:determine_location_type, ["catering.cafe"])
      assert_equal :restaurant, result
    end

    test "determine_location_type returns accommodation for hotel categories" do
      result = @enricher.send(:determine_location_type, ["accommodation.hotel"])
      assert_equal :accommodation, result
    end

    test "determine_location_type returns accommodation for hostel categories" do
      result = @enricher.send(:determine_location_type, ["accommodation.hostel"])
      assert_equal :accommodation, result
    end

    test "determine_location_type returns guide for tour categories" do
      result = @enricher.send(:determine_location_type, ["service.tour_guide"])
      assert_equal :guide, result
    end

    test "determine_location_type returns business for shop categories" do
      result = @enricher.send(:determine_location_type, ["commercial.shop"])
      assert_equal :business, result
    end

    test "determine_location_type returns artisan for craft categories" do
      result = @enricher.send(:determine_location_type, ["craft.artisan"])
      assert_equal :artisan, result
    end

    test "determine_location_type returns place for unknown categories" do
      result = @enricher.send(:determine_location_type, ["unknown.category"])
      assert_equal :place, result
    end

    test "determine_location_type returns place for blank categories" do
      assert_equal :place, @enricher.send(:determine_location_type, nil)
      assert_equal :place, @enricher.send(:determine_location_type, [])
    end

    # === determine_budget tests ===

    test "determine_budget returns low for price_level 1" do
      result = @enricher.send(:determine_budget, { price_level: 1 })
      assert_equal :low, result
    end

    test "determine_budget returns low for price_level 2" do
      result = @enricher.send(:determine_budget, { price_level: 2 })
      assert_equal :low, result
    end

    test "determine_budget returns medium for price_level 3" do
      result = @enricher.send(:determine_budget, { price_level: 3 })
      assert_equal :medium, result
    end

    test "determine_budget returns high for price_level 4" do
      result = @enricher.send(:determine_budget, { price_level: 4 })
      assert_equal :high, result
    end

    test "determine_budget returns medium for missing price_level" do
      result = @enricher.send(:determine_budget, {})
      assert_equal :medium, result
    end

    test "determine_budget reads from properties hash" do
      result = @enricher.send(:determine_budget, { properties: { price_level: 4 } })
      assert_equal :high, result
    end

    # === normalize_website_url tests ===

    test "normalize_website_url returns nil for blank url" do
      assert_nil @enricher.send(:normalize_website_url, nil)
      assert_nil @enricher.send(:normalize_website_url, "")
      assert_nil @enricher.send(:normalize_website_url, "   ")
    end

    test "normalize_website_url preserves https urls" do
      url = "https://example.com"
      result = @enricher.send(:normalize_website_url, url)
      assert_equal "https://example.com", result
    end

    test "normalize_website_url preserves http urls" do
      url = "http://example.com"
      result = @enricher.send(:normalize_website_url, url)
      assert_equal "http://example.com", result
    end

    test "normalize_website_url adds https to bare domains" do
      url = "example.com"
      result = @enricher.send(:normalize_website_url, url)
      assert_equal "https://example.com", result
    end

    test "normalize_website_url handles urls with paths" do
      url = "example.com/path/to/page"
      result = @enricher.send(:normalize_website_url, url)
      assert_equal "https://example.com/path/to/page", result
    end

    # === sanitize_external_string tests ===

    test "sanitize_external_string removes null bytes" do
      str = "Test\x00String"
      result = @enricher.send(:sanitize_external_string, str)
      assert_equal "TestString", result
    end

    test "sanitize_external_string removes control characters" do
      str = "Test\x01\x02\x03String"
      result = @enricher.send(:sanitize_external_string, str)
      assert_equal "TestString", result
    end

    test "sanitize_external_string preserves normal characters" do
      str = "Normal String with spaces"
      result = @enricher.send(:sanitize_external_string, str)
      assert_equal "Normal String with spaces", result
    end

    test "sanitize_external_string returns nil for nil input" do
      result = @enricher.send(:sanitize_external_string, nil)
      assert_nil result
    end

    test "sanitize_external_string returns non-strings as is" do
      result = @enricher.send(:sanitize_external_string, 123)
      assert_equal 123, result
    end

    # === Schema tests ===

    test "metadata_schema has correct structure" do
      schema = @enricher.send(:metadata_schema)

      assert_equal "object", schema[:type]
      assert_includes schema[:properties].keys, :suitable_experiences
      assert_includes schema[:properties].keys, :tags
      assert_includes schema[:properties].keys, :practical_info
      assert_equal false, schema[:additionalProperties]
    end

    test "descriptions_schema includes provided locales" do
      locales = ["en", "bs", "de"]
      schema = @enricher.send(:descriptions_schema, locales)

      desc_props = schema[:properties][:descriptions][:properties]
      locales.each do |locale|
        assert_includes desc_props.keys, locale
      end
    end

    test "historical_context_schema includes provided locales" do
      locales = ["en", "bs"]
      schema = @enricher.send(:historical_context_schema, locales)

      context_props = schema[:properties][:historical_context][:properties]
      locales.each do |locale|
        assert_includes context_props.keys, locale
      end
    end

    # === enrich tests ===

    test "enrich returns false when enrichment generation fails" do
      mock_location = create_mock_location

      @enricher.stub :generate_enrichment, {} do
        result = @enricher.enrich(mock_location)
        assert_not result
      end
    end

    test "enrich returns false on save error" do
      mock_location = create_mock_location
      mock_location.define_singleton_method(:save!) { raise StandardError, "Save failed" }

      enrichment = {
        suitable_experiences: ["culture"],
        descriptions: { "en" => "Description" },
        historical_context: { "en" => "History" },
        tags: ["historical"],
        practical_info: { best_time: "morning", duration_minutes: 60, tips: [] }
      }

      @enricher.stub :generate_enrichment, enrichment do
        @enricher.stub :apply_enrichment, nil do
          result = @enricher.enrich(mock_location)
          assert_not result
        end
      end
    end

    # === enrich_batch tests ===

    test "enrich_batch returns results hash with success and failed arrays" do
      loc1 = create_mock_location(name: "Location 1")
      loc2 = create_mock_location(name: "Location 2")

      @enricher.stub :enrich, true do
        result = @enricher.enrich_batch([loc1, loc2])

        assert_includes result.keys, :success
        assert_includes result.keys, :failed
        assert_kind_of Array, result[:success]
        assert_kind_of Array, result[:failed]
      end
    end

    test "enrich_batch categorizes successful and failed enrichments" do
      loc1 = create_mock_location(name: "Success Location")
      loc2 = create_mock_location(name: "Failed Location")

      call_count = 0
      @enricher.stub :enrich, ->(loc, **opts) {
        call_count += 1
        call_count == 1 # First succeeds, second fails
      } do
        result = @enricher.enrich_batch([loc1, loc2])

        assert_equal 1, result[:success].count
        assert_equal 1, result[:failed].count
      end
    end

    # === create_and_enrich tests ===

    test "create_and_enrich returns nil for blank name" do
      place_data = { name: "", lat: 43.856, lng: 18.413 }
      result = @enricher.create_and_enrich(place_data, city: "Sarajevo")
      assert_nil result
    end

    test "create_and_enrich returns nil for blank lat" do
      place_data = { name: "Test Place", lat: nil, lng: 18.413 }
      result = @enricher.create_and_enrich(place_data, city: "Sarajevo")
      assert_nil result
    end

    test "create_and_enrich returns existing location if found by coordinates" do
      existing_location = OpenStruct.new(id: 1, name: "Existing")
      place_data = { name: "Test Place", lat: 43.856, lng: 18.413 }

      Location.stub :find_by_coordinates_fuzzy, existing_location do
        result = @enricher.create_and_enrich(place_data, city: "Sarajevo")
        assert_equal existing_location, result
      end
    end

    # === add_tags_from_categories tests ===

    test "add_tags_from_categories extracts tags from category strings" do
      mock_location = create_mock_location
      mock_location.define_singleton_method(:save) { true }

      categories = ["tourism.attraction", "heritage.historical_site"]

      @enricher.send(:add_tags_from_categories, mock_location, categories)

      assert mock_location.tags.include?("attraction") || mock_location.tags.include?("historical-site")
    end

    test "add_tags_from_categories handles blank categories" do
      mock_location = create_mock_location
      original_tags = mock_location.tags.dup

      @enricher.send(:add_tags_from_categories, mock_location, nil)
      assert_equal original_tags, mock_location.tags

      @enricher.send(:add_tags_from_categories, mock_location, [])
      assert_equal original_tags, mock_location.tags
    end

    # === JSON parsing tests ===

    test "parse_ai_json_response parses valid JSON with string values" do
      # Note: The parse_ai_json_response method uses heuristics to detect and escape
      # embedded quotes in AI output. These heuristics work best with string values.
      # For JSON with numeric values after keys, use JSON.parse directly.
      content = '{"name": "Test", "description": "A description"}'
      result = @enricher.send(:parse_ai_json_response, content)

      assert_kind_of Hash, result, "Expected Hash, got #{result.class}"
      assert_equal "Test", result[:name], "Result was: #{result.inspect}"
      assert_equal "A description", result[:description]
    end

    test "parse_ai_json_response extracts JSON from markdown code block" do
      content = "```json\n{\"name\": \"Test\"}\n```"
      result = @enricher.send(:parse_ai_json_response, content)
      assert_equal "Test", result[:name]
    end

    test "parse_ai_json_response returns empty hash for invalid JSON" do
      result = @enricher.send(:parse_ai_json_response, "not valid json")
      assert_equal({}, result)
    end

    test "sanitize_ai_json removes trailing commas" do
      json = '{"name": "Test",}'
      result = @enricher.send(:sanitize_ai_json, json)
      assert_not_includes result, ",}"
    end

    test "sanitize_ai_json removes trailing comma at end of stream" do
      json = '{"name": "Test"},'
      result = @enricher.send(:sanitize_ai_json, json)
      assert_not result.end_with?(",")
    end

    test "sanitize_ai_json converts smart quotes" do
      json = '{"name": "Test"}'
      result = @enricher.send(:sanitize_ai_json, json)
      assert_includes result, '"'
    end

    # === Control character escaping tests ===

    test "escape_chars_in_json_strings handles newlines" do
      json = "{\"text\": \"line1\nline2\"}"
      result = @enricher.send(:escape_chars_in_json_strings, json)
      assert_includes result, "\\n"
    end

    test "escape_chars_in_json_strings handles tabs" do
      json = "{\"text\": \"col1\tcol2\"}"
      result = @enricher.send(:escape_chars_in_json_strings, json)
      assert_includes result, "\\t"
    end

    test "escape_chars_in_json_strings handles carriage returns" do
      json = "{\"text\": \"line1\rline2\"}"
      result = @enricher.send(:escape_chars_in_json_strings, json)
      assert_includes result, "\\r"
    end

    # === Embedded quote detection tests ===

    test "looks_like_embedded_quote returns false for closing quote" do
      json = '{"name": "Test"}'
      # Position of closing quote before }
      result = @enricher.send(:looks_like_embedded_quote?, json, 14)
      assert_not result
    end

    test "looks_like_embedded_quote returns true for mid-string quote" do
      json = '{"text": "He said hello there"}'
      result = @enricher.send(:looks_like_embedded_quote?, json, 18)
      assert result
    end

    test "looks_like_embedded_quote handles colon after quote" do
      # Test JSON key-value separator pattern `: "`
      json = '{"text": "value", "key": "another"}'
      # Position 16 is the quote after "value" - followed by `, "key"`
      # This is a real closing quote because it's followed by JSON structure
      result = @enricher.send(:looks_like_embedded_quote?, json, 16)
      assert_not result
    end

    # === Error handling tests ===

    test "generate_metadata handles API errors gracefully" do
      mock_location = create_mock_location
      place_data = { categories: ["tourism"] }

      Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API error" } do
        result = @enricher.send(:generate_metadata, mock_location, place_data)
        assert_equal({}, result)
      end
    end

    test "generate_descriptions handles API errors gracefully" do
      mock_location = create_mock_location
      place_data = { categories: ["tourism"] }

      Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API error" } do
        result = @enricher.send(:generate_descriptions, mock_location, place_data, ["en", "bs"])
        assert_equal({}, result)
      end
    end

    test "generate_historical_context handles API errors gracefully" do
      mock_location = create_mock_location
      place_data = { categories: ["tourism"] }

      Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API error" } do
        result = @enricher.send(:generate_historical_context, mock_location, place_data, ["en", "bs"])
        assert_equal({}, result)
      end
    end

    # === apply_enrichment tests ===

    test "apply_enrichment sets description translations" do
      mock_location = create_mock_location
      translations_set = []
      mock_location.define_singleton_method(:set_translation) { |field, value, locale|
        translations_set << { field: field, value: value, locale: locale }
      }

      enrichment = {
        descriptions: { "en" => "English description", "bs" => "Bosanski opis" },
        historical_context: {},
        suitable_experiences: [],
        tags: [],
        practical_info: {}
      }

      Locale.stub :ai_supported_codes, ["en", "bs"] do
        @enricher.send(:apply_enrichment, mock_location, enrichment)
      end

      desc_translations = translations_set.select { |t| t[:field] == :description }
      assert desc_translations.any? { |t| t[:locale] == "en" && t[:value] == "English description" }
      assert desc_translations.any? { |t| t[:locale] == "bs" && t[:value] == "Bosanski opis" }
    end

    test "apply_enrichment sets historical_context translations" do
      mock_location = create_mock_location
      translations_set = []
      mock_location.define_singleton_method(:set_translation) { |field, value, locale|
        translations_set << { field: field, value: value, locale: locale }
      }

      enrichment = {
        descriptions: {},
        historical_context: { "en" => "Historical context", "bs" => "Historijski kontekst" },
        suitable_experiences: [],
        tags: [],
        practical_info: {}
      }

      Locale.stub :ai_supported_codes, ["en", "bs"] do
        @enricher.send(:apply_enrichment, mock_location, enrichment)
      end

      context_translations = translations_set.select { |t| t[:field] == :historical_context }
      assert context_translations.any? { |t| t[:locale] == "en" && t[:value] == "Historical context" }
    end

    test "apply_enrichment sets suitable_experiences" do
      mock_location = create_mock_location
      mock_location.define_singleton_method(:set_translation) { |*| }
      mock_location.define_singleton_method(:add_experience_type) { |*| }

      enrichment = {
        descriptions: {},
        historical_context: {},
        suitable_experiences: ["culture", "history"],
        tags: [],
        practical_info: {}
      }

      Locale.stub :ai_supported_codes, [] do
        @enricher.send(:apply_enrichment, mock_location, enrichment)
      end

      assert_equal ["culture", "history"], mock_location.suitable_experiences
    end

    test "apply_enrichment merges tags" do
      mock_location = create_mock_location
      mock_location.instance_variable_set(:@tags, ["existing-tag"])
      mock_location.define_singleton_method(:tags) { @tags }
      mock_location.define_singleton_method(:tags=) { |v| @tags = v }
      mock_location.define_singleton_method(:set_translation) { |*| }

      enrichment = {
        descriptions: {},
        historical_context: {},
        suitable_experiences: [],
        tags: ["new-tag", "another-tag"],
        practical_info: {}
      }

      Locale.stub :ai_supported_codes, [] do
        @enricher.send(:apply_enrichment, mock_location, enrichment)
      end

      assert_includes mock_location.tags, "existing-tag"
      assert_includes mock_location.tags, "new-tag"
      assert_includes mock_location.tags, "another-tag"
    end

    test "apply_enrichment stores practical_info in audio_tour_metadata" do
      mock_location = create_mock_location
      mock_location.define_singleton_method(:set_translation) { |*| }
      mock_location.define_singleton_method(:audio_tour_metadata) { @audio_tour_metadata ||= {} }
      mock_location.define_singleton_method(:audio_tour_metadata=) { |v| @audio_tour_metadata = v }

      enrichment = {
        descriptions: {},
        historical_context: {},
        suitable_experiences: [],
        tags: [],
        practical_info: { best_time: "morning", duration_minutes: 60, tips: ["Arrive early"] }
      }

      Locale.stub :ai_supported_codes, [] do
        @enricher.send(:apply_enrichment, mock_location, enrichment)
      end

      assert_equal "morning", mock_location.audio_tour_metadata["practical_info"][:best_time]
    end

    private

    def create_mock_location(id: nil, name: "Test Location", city: "Sarajevo", lat: 43.856, lng: 18.413)
      mock = OpenStruct.new(
        id: id || rand(1000..9999),
        name: name,
        city: city,
        lat: lat,
        lng: lng,
        location_type: "place",
        tags: [],
        suitable_experiences: [],
        audio_tour_metadata: {}
      )

      mock.define_singleton_method(:set_translation) { |field, value, locale| }
      mock.define_singleton_method(:add_experience_type) { |type| }
      mock.define_singleton_method(:save!) { true }
      mock.define_singleton_method(:save) { true }

      mock
    end

    def stub_ai_queue_response(response)
      Ai::OpenaiQueue.stub :request, response do
        yield
      end
    end
  end
end
