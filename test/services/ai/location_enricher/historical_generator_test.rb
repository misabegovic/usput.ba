# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class LocationEnricher
    class HistoricalGeneratorTest < ActiveSupport::TestCase
      setup do
        @generator = Ai::LocationEnricher::HistoricalGenerator.new
        @location = create_mock_location
        @place_data = {
          categories: [ "tourism.attraction", "heritage.historical" ],
          formatted: "Stari Most, Mostar",
          address_line1: "Stari Most"
        }
      end

      # === Constants ===

      test "LOCALES_PER_BATCH is set to 3" do
        assert_equal 3, Ai::LocationEnricher::HistoricalGenerator::LOCALES_PER_BATCH
      end

      # === generate tests ===

      test "generate returns historical_context hash keyed by locale" do
        stub_openai_queue(historical_context: { "en" => "English historical context" }) do
          result = @generator.generate(@location, @place_data, locales: [ "en" ])

          assert_kind_of Hash, result
          assert_equal "English historical context", result["en"]
        end
      end

      test "generate uses all supported locales when locales not specified" do
        supported = [ "en", "bs" ]
        Locale.stub :ai_supported_codes, supported do
          stub_openai_queue(historical_context: { "en" => "English history", "bs" => "Bosanska historija" }) do
            result = @generator.generate(@location, @place_data)

            assert_equal 2, result.keys.count
            assert result.key?("en")
            assert result.key?("bs")
          end
        end
      end

      test "generate processes locales in batches" do
        locales = %w[en bs hr de es]  # 5 locales, needs 2 batches (3 + 2)
        request_count = 0

        Ai::OpenaiQueue.stub :request, ->(*args) {
          request_count += 1
          { historical_context: locales.to_h { |l| [ l, "History in #{l}" ] } }
        } do
          @generator.generate(@location, @place_data, locales: locales)

          # Should be 2 batches: first 3, then 2
          assert_equal 2, request_count
        end
      end

      test "generate merges results from multiple batches" do
        locales = %w[en bs hr de]  # 4 locales, needs 2 batches (3 + 1)

        call_count = 0
        Ai::OpenaiQueue.stub :request, ->(*args) {
          call_count += 1
          if call_count == 1
            { historical_context: { "en" => "English", "bs" => "Bosanski", "hr" => "Hrvatski" } }
          else
            { historical_context: { "de" => "German" } }
          end
        } do
          result = @generator.generate(@location, @place_data, locales: locales)

          assert_equal 4, result.keys.count
          assert_equal "English", result["en"]
          assert_equal "German", result["de"]
        end
      end

      test "generate handles empty response from API" do
        Ai::OpenaiQueue.stub :request, {} do
          result = @generator.generate(@location, @place_data, locales: [ "en" ])

          assert_equal({}, result)
        end
      end

      test "generate handles API error gracefully" do
        Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API Error" } do
          result = @generator.generate(@location, @place_data, locales: [ "en" ])

          assert_equal({}, result)
        end
      end

      test "generate skips empty batch results" do
        locales = %w[en bs]
        call_count = 0

        Ai::OpenaiQueue.stub :request, ->(*args) {
          call_count += 1
          if call_count == 1
            { historical_context: { "en" => "English", "bs" => "Bosanski" } }
          else
            {}  # Empty result
          end
        } do
          result = @generator.generate(@location, @place_data, locales: locales)

          assert_equal 2, result.keys.count
        end
      end

      # === build_prompt tests ===

      test "build_prompt includes location vars" do
        prompt = @generator.send(:build_prompt, @location, @place_data, [ "en" ])

        assert_includes prompt, @location.name
        assert_includes prompt, @location.city
      end

      test "build_prompt includes locales list" do
        locales = [ "en", "bs", "hr" ]
        prompt = @generator.send(:build_prompt, @location, @place_data, locales)

        assert_includes prompt, "en, bs, hr"
      end

      # === schema_for tests ===

      test "schema_for generates correct structure" do
        locales = [ "en", "bs" ]
        schema = @generator.send(:schema_for, locales)

        assert_equal "object", schema[:type]
        assert_includes schema[:properties].keys, :historical_context
        assert_equal false, schema[:additionalProperties]
      end

      test "schema_for includes all provided locales" do
        locales = [ "en", "bs", "hr" ]
        schema = @generator.send(:schema_for, locales)

        context_props = schema[:properties][:historical_context][:properties]
        assert_includes context_props.keys, "en"
        assert_includes context_props.keys, "bs"
        assert_includes context_props.keys, "hr"
      end

      test "schema_for requires all locales" do
        locales = [ "en", "bs" ]
        schema = @generator.send(:schema_for, locales)

        required = schema[:properties][:historical_context][:required]
        assert_includes required, "en"
        assert_includes required, "bs"
      end

      # === location_vars tests ===

      test "location_vars returns correct hash" do
        vars = @generator.send(:location_vars, @location, @place_data)

        assert_equal @location.name, vars[:name]
        assert_equal @location.city, vars[:city]
        assert_equal "Stari Most, Mostar", vars[:address]
      end

      test "location_vars extracts category from categories array" do
        vars = @generator.send(:location_vars, @location, @place_data)

        assert_equal "tourism.attraction", vars[:category]
      end

      test "location_vars joins categories with comma" do
        place_data = @place_data.merge(categories: [ "tourism", "heritage", "historical" ])
        vars = @generator.send(:location_vars, @location, place_data)

        assert_equal "tourism, heritage, historical", vars[:categories]
      end

      test "location_vars falls back to location category_name when no categories" do
        @location.define_singleton_method(:category_name) { "Bridge" }
        vars = @generator.send(:location_vars, @location, {})

        assert_equal "Bridge", vars[:category]
      end

      test "location_vars includes cultural_context" do
        vars = @generator.send(:location_vars, @location, @place_data)

        assert_not_nil vars[:cultural_context]
      end

      # === Integration tests ===

      test "generate creates proper API request context" do
        context_used = nil

        Ai::OpenaiQueue.stub :request, ->(prompt:, schema:, context:) {
          context_used = context
          { historical_context: { "en" => "Test" } }
        } do
          @generator.generate(@location, @place_data, locales: [ "en" ])
        end

        assert_includes context_used, "LocationEnricher:history"
        assert_includes context_used, @location.name
      end

      test "generate uses correct prompt template" do
        prompt_used = nil

        Ai::OpenaiQueue.stub :request, ->(prompt:, schema:, context:) {
          prompt_used = prompt
          { historical_context: { "en" => "Test" } }
        } do
          @generator.generate(@location, @place_data, locales: [ "en" ])
        end

        # Prompt should be loaded from historical_context.md.erb template
        assert_not_nil prompt_used
        assert_includes prompt_used, @location.name
      end

      private

      def create_mock_location(name: "Stari Most", city: "Mostar", lat: 43.337, lng: 17.815)
        mock = OpenStruct.new(
          id: rand(1000..9999),
          name: name,
          city: city,
          lat: lat,
          lng: lng,
          location_type: "place"
        )

        mock.define_singleton_method(:category_name) { "Bridge" }
        mock
      end

      def stub_openai_queue(response)
        Ai::OpenaiQueue.stub :request, response do
          yield
        end
      end
    end
  end
end
