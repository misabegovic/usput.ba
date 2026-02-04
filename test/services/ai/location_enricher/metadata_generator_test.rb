# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class LocationEnricher
    class MetadataGeneratorTest < ActiveSupport::TestCase
      setup do
        @generator = Ai::LocationEnricher::MetadataGenerator.new
      end

      # === Schema tests ===

      test "SCHEMA constant is defined and frozen" do
        assert Ai::LocationEnricher::MetadataGenerator::SCHEMA
        assert Ai::LocationEnricher::MetadataGenerator::SCHEMA.frozen?
      end

      test "SCHEMA has correct structure" do
        schema = Ai::LocationEnricher::MetadataGenerator::SCHEMA

        assert_equal "object", schema[:type]
        assert_includes schema[:properties].keys, :suitable_experiences
        assert_includes schema[:properties].keys, :tags
        assert_includes schema[:properties].keys, :practical_info
        assert_equal %w[suitable_experiences tags practical_info], schema[:required]
        assert_equal false, schema[:additionalProperties]
      end

      test "SCHEMA suitable_experiences is array of strings" do
        schema = Ai::LocationEnricher::MetadataGenerator::SCHEMA

        suitable_exp = schema[:properties][:suitable_experiences]
        assert_equal "array", suitable_exp[:type]
        assert_equal({ type: "string" }, suitable_exp[:items])
      end

      test "SCHEMA tags is array of strings" do
        schema = Ai::LocationEnricher::MetadataGenerator::SCHEMA

        tags = schema[:properties][:tags]
        assert_equal "array", tags[:type]
        assert_equal({ type: "string" }, tags[:items])
      end

      test "SCHEMA practical_info has required fields" do
        schema = Ai::LocationEnricher::MetadataGenerator::SCHEMA

        practical_info = schema[:properties][:practical_info]
        assert_equal "object", practical_info[:type]
        assert_includes practical_info[:properties].keys, :best_time
        assert_includes practical_info[:properties].keys, :duration_minutes
        assert_includes practical_info[:properties].keys, :tips
        assert_equal %w[best_time duration_minutes tips], practical_info[:required]
      end

      # === generate tests ===

      test "generate returns metadata hash on success" do
        mock_location = create_mock_location
        place_data = { categories: [ "tourism.attraction" ] }

        metadata = {
          suitable_experiences: [ "culture", "history" ],
          tags: [ "historical-site", "unesco" ],
          practical_info: {
            best_time: "morning",
            duration_minutes: 60,
            tips: [ "Arrive early", "Bring water" ]
          }
        }

        Ai::OpenaiQueue.stub :request, metadata do
          result = @generator.generate(mock_location, place_data)

          assert_equal metadata, result
          assert_includes result[:suitable_experiences], "culture"
          assert_includes result[:tags], "historical-site"
          assert_equal "morning", result[:practical_info][:best_time]
        end
      end

      test "generate handles API errors gracefully" do
        mock_location = create_mock_location
        place_data = { categories: [ "tourism" ] }

        Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API error" } do
          result = @generator.generate(mock_location, place_data)

          assert_equal({}, result)
        end
      end

      test "generate passes correct context to OpenaiQueue" do
        mock_location = create_mock_location(name: "Stari Most")
        context_passed = nil

        Ai::OpenaiQueue.stub :request, ->(prompt:, schema:, context:) {
          context_passed = context
          {}
        } do
          @generator.generate(mock_location, {})
        end

        assert_equal "LocationEnricher:metadata:Stari Most", context_passed
      end

      test "generate uses SCHEMA constant" do
        mock_location = create_mock_location
        schema_passed = nil

        Ai::OpenaiQueue.stub :request, ->(prompt:, schema:, context:) {
          schema_passed = schema
          {}
        } do
          @generator.generate(mock_location, {})
        end

        assert_equal Ai::LocationEnricher::MetadataGenerator::SCHEMA, schema_passed
      end

      test "generate works without place_data" do
        mock_location = create_mock_location

        metadata = {
          suitable_experiences: [ "nature" ],
          tags: [ "scenic" ],
          practical_info: { best_time: "any", duration_minutes: 30, tips: [] }
        }

        Ai::OpenaiQueue.stub :request, metadata do
          result = @generator.generate(mock_location)

          assert_equal metadata, result
        end
      end

      # === build_prompt tests ===

      test "build_prompt includes location name" do
        mock_location = create_mock_location(name: "Baščaršija")
        place_data = { categories: [ "tourism" ] }

        prompt = @generator.send(:build_prompt, mock_location, place_data)

        assert_includes prompt, "Baščaršija"
      end

      test "build_prompt includes city" do
        mock_location = create_mock_location(city: "Mostar")
        place_data = {}

        prompt = @generator.send(:build_prompt, mock_location, place_data)

        assert_includes prompt, "Mostar"
      end

      test "build_prompt includes experience types" do
        mock_location = create_mock_location

        ExperienceType.stub :active_keys, [ "culture", "history", "food" ] do
          prompt = @generator.send(:build_prompt, mock_location, {})

          assert_includes prompt, "culture"
          assert_includes prompt, "history"
          assert_includes prompt, "food"
        end
      end

      test "build_prompt includes cultural context" do
        mock_location = create_mock_location

        prompt = @generator.send(:build_prompt, mock_location, {})

        # Cultural context should be included from BihContext
        assert prompt.length > 100 # Should have substantial content
      end

      test "build_prompt includes category from place_data" do
        mock_location = create_mock_location
        place_data = { categories: [ "tourism.attraction", "heritage.monument" ] }

        prompt = @generator.send(:build_prompt, mock_location, place_data)

        assert_includes prompt, "tourism.attraction"
      end

      test "build_prompt includes coordinates" do
        mock_location = create_mock_location(lat: 43.856, lng: 18.413)

        prompt = @generator.send(:build_prompt, mock_location, {})

        assert_includes prompt, "43.856"
        assert_includes prompt, "18.413"
      end

      # === location_vars tests ===

      test "location_vars returns correct hash structure" do
        mock_location = create_mock_location(
          name: "Test Location",
          city: "Sarajevo",
          lat: 43.856,
          lng: 18.413
        )
        place_data = {
          categories: [ "tourism.attraction" ],
          formatted: "Test Address, Sarajevo",
          address_line1: "Test Address"
        }

        vars = @generator.send(:location_vars, mock_location, place_data)

        assert_equal "Test Location", vars[:name]
        assert_equal "Sarajevo", vars[:city]
        assert_equal "tourism.attraction", vars[:category]
        assert_equal "tourism.attraction", vars[:categories]
        assert_equal "Test Address, Sarajevo", vars[:address]
        assert_equal 43.856, vars[:lat]
        assert_equal 18.413, vars[:lng]
        assert vars[:cultural_context].present?
      end

      test "location_vars handles missing place_data" do
        mock_location = create_mock_location
        mock_location.define_singleton_method(:category_name) { "museum" }

        vars = @generator.send(:location_vars, mock_location, {})

        assert_equal "museum", vars[:category]
        assert_nil vars[:categories]
        assert_nil vars[:address]
      end

      test "location_vars uses address_line1 as fallback" do
        mock_location = create_mock_location
        place_data = { address_line1: "Fallback Address" }

        vars = @generator.send(:location_vars, mock_location, place_data)

        assert_equal "Fallback Address", vars[:address]
      end

      test "location_vars joins multiple categories" do
        mock_location = create_mock_location
        place_data = { categories: [ "tourism.attraction", "heritage.monument", "cultural.museum" ] }

        vars = @generator.send(:location_vars, mock_location, place_data)

        assert_equal "tourism.attraction, heritage.monument, cultural.museum", vars[:categories]
      end

      private

      def create_mock_location(
        id: nil,
        name: "Test Location",
        city: "Sarajevo",
        lat: 43.856,
        lng: 18.413
      )
        mock = OpenStruct.new(
          id: id || rand(1000..9999),
          name: name,
          city: city,
          lat: lat,
          lng: lng,
          location_type: "place"
        )

        mock.define_singleton_method(:category_name) { "attraction" }

        mock
      end
    end
  end
end
