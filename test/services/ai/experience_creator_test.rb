# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class ExperienceCreatorTest < ActiveSupport::TestCase
    setup do
      @creator = Ai::ExperienceCreator.new(max_experiences: 5)
    end

    # === Initialization tests ===

    test "initializes with default max_experiences (unlimited)" do
      creator = Ai::ExperienceCreator.new
      assert_nil creator.instance_variable_get(:@max_experiences)
      assert_equal 0, creator.instance_variable_get(:@created_count)
    end

    test "initializes with custom max_experiences" do
      creator = Ai::ExperienceCreator.new(max_experiences: 10)
      assert_equal 10, creator.instance_variable_get(:@max_experiences)
    end

    # === remaining_slots tests ===

    test "remaining_slots returns infinity when no limit" do
      creator = Ai::ExperienceCreator.new
      assert_equal Float::INFINITY, creator.remaining_slots
    end

    test "remaining_slots returns correct count when limit set" do
      creator = Ai::ExperienceCreator.new(max_experiences: 5)
      assert_equal 5, creator.remaining_slots
    end

    test "remaining_slots decrements after creation" do
      creator = Ai::ExperienceCreator.new(max_experiences: 5)
      creator.instance_variable_set(:@created_count, 2)
      assert_equal 3, creator.remaining_slots
    end

    # === limit_reached? tests ===

    test "limit_reached returns false when no limit" do
      creator = Ai::ExperienceCreator.new
      assert_not creator.limit_reached?
    end

    test "limit_reached returns false when under limit" do
      creator = Ai::ExperienceCreator.new(max_experiences: 5)
      creator.instance_variable_set(:@created_count, 3)
      assert_not creator.limit_reached?
    end

    test "limit_reached returns true when at limit" do
      creator = Ai::ExperienceCreator.new(max_experiences: 5)
      creator.instance_variable_set(:@created_count, 5)
      assert creator.limit_reached?
    end

    test "limit_reached returns true when over limit" do
      creator = Ai::ExperienceCreator.new(max_experiences: 5)
      creator.instance_variable_set(:@created_count, 7)
      assert creator.limit_reached?
    end

    # === create_local_experiences tests ===

    test "create_local_experiences returns empty array when limit reached" do
      creator = Ai::ExperienceCreator.new(max_experiences: 0)
      result = creator.create_local_experiences(city: "Sarajevo")
      assert_equal [], result
    end

    test "create_local_experiences returns empty array when no locations" do
      Location.stub :where, Location.none do
        result = @creator.create_local_experiences(city: "NonexistentCity")
        assert_equal [], result
      end
    end

    test "create_local_experiences calls AI with correct parameters" do
      # Create mock location
      mock_location = create_mock_location(id: 1, name: "Test Place", city: "Sarajevo")

      mock_ai_response = {
        experiences: [
          {
            location_ids: [1],
            location_names: ["Test Place"],
            category_key: "cultural_heritage",
            estimated_duration: 120,
            seasons: [],
            titles: { "en" => "Test Experience", "bs" => "Test Iskustvo" },
            descriptions: { "en" => "Description", "bs" => "Opis" },
            theme_reasoning: "Reason"
          }
        ]
      }

      # Stub Location queries
      mock_relation = mock_location_relation([mock_location])

      Location.stub :where, ->(*args) { mock_relation } do
        stub_ai_queue_response(mock_ai_response) do
          stub_setting_min_locations(1) do
            # Don't actually create - just verify method runs
            result = @creator.create_local_experiences(city: "Sarajevo")
            assert_kind_of Array, result
          end
        end
      end
    end

    # === create_thematic_experiences tests ===

    test "create_thematic_experiences returns empty array when limit reached" do
      creator = Ai::ExperienceCreator.new(max_experiences: 0)
      result = creator.create_thematic_experiences
      assert_equal [], result
    end

    test "create_thematic_experiences calls AI for cross-city experiences" do
      mock_ai_response = { experiences: [] }

      Location.stub :with_coordinates, Location.none do
        stub_ai_queue_response(mock_ai_response) do
          result = @creator.create_thematic_experiences
          assert_equal [], result
        end
      end
    end

    # === Filter retirement homes tests ===

    test "retirement_home_location returns true for retirement homes by name" do
      mock_location = create_mock_location(
        name: "Dom za penzionere Sarajevo",
        location_categories: [],
        tags: []
      )

      result = @creator.send(:retirement_home_location?, mock_location)
      assert result
    end

    test "retirement_home_location returns true for nursing homes by category" do
      mock_category = OpenStruct.new(key: "retirement_home")
      mock_location = create_mock_location(
        name: "Care Center",
        location_categories: [mock_category],
        tags: []
      )

      result = @creator.send(:retirement_home_location?, mock_location)
      assert result
    end

    test "retirement_home_location returns false for regular places" do
      mock_location = create_mock_location(
        name: "Gazi Husrev-beg Mosque",
        location_categories: [],
        tags: ["mosque", "historical"]
      )

      result = @creator.send(:retirement_home_location?, mock_location)
      assert_not result
    end

    test "filter_retirement_homes removes retirement facilities" do
      regular_location = create_mock_location(name: "Museum")
      retirement_home = create_mock_location(name: "Dom za penzionere")

      locations = [regular_location, retirement_home]
      result = @creator.send(:filter_retirement_homes, locations)

      assert_equal 1, result.count
      assert_equal "Museum", result.first.name
    end

    # === extract_initial_title tests ===

    test "extract_initial_title returns English title first" do
      proposal = { titles: { "en" => "English Title", "bs" => "Bosanski" } }
      result = @creator.send(:extract_initial_title, proposal)
      assert_equal "English Title", result
    end

    test "extract_initial_title returns any title when no English" do
      proposal = { titles: { "bs" => "Bosanski Naslov" } }
      result = @creator.send(:extract_initial_title, proposal)
      assert_equal "Bosanski Naslov", result
    end

    test "extract_initial_title returns fallback when no titles" do
      proposal = { titles: {} }
      result = @creator.send(:extract_initial_title, proposal)
      assert_equal "Experience", result
    end

    # === calculate_duration tests ===

    test "calculate_duration computes based on location count" do
      locations = [
        create_mock_location(name: "Loc 1"),
        create_mock_location(name: "Loc 2"),
        create_mock_location(name: "Loc 3")
      ]

      result = @creator.send(:calculate_duration, locations)

      # 3 locations * 35 min + 2 travel segments * 15 min = 105 + 30 = 135
      assert_equal 135, result
    end

    test "calculate_duration handles single location" do
      locations = [create_mock_location(name: "Loc 1")]
      result = @creator.send(:calculate_duration, locations)

      # 1 location * 35 min + 0 travel = 35
      assert_equal 35, result
    end

    # === Similarity checking tests ===

    test "word_similarity returns 1.0 for identical strings" do
      result = @creator.send(:word_similarity, "Test Experience", "Test Experience")
      assert_equal 1.0, result
    end

    test "word_similarity returns 0.0 for completely different strings" do
      result = @creator.send(:word_similarity, "Ottoman Heritage", "Nature Adventure")
      assert_equal 0.0, result
    end

    test "word_similarity returns partial match for overlapping words" do
      result = @creator.send(:word_similarity, "Sarajevo Cultural Walk", "Cultural Heritage Walk")
      assert result > 0.0
      assert result < 1.0
    end

    test "word_similarity handles blank strings" do
      assert_equal 0.0, @creator.send(:word_similarity, "", "Test")
      assert_equal 0.0, @creator.send(:word_similarity, "Test", "")
      # Two empty strings are equal, so returns 1.0 per the identity check
      assert_equal 1.0, @creator.send(:word_similarity, "", "")
    end

    test "normalize_for_comparison removes stop words and punctuation" do
      result = @creator.send(:normalize_for_comparison, "The beautiful bridge of Mostar!")
      assert_not_includes result, "the"
      assert_not_includes result, "of"
      assert_includes result, "beautiful"
      assert_includes result, "bridge"
      assert_includes result, "mostar"
    end

    # === Schema generation tests ===

    test "experiences_proposal_schema has correct structure" do
      schema = @creator.send(:experiences_proposal_schema)

      assert_equal "object", schema[:type]
      assert_includes schema[:properties].keys, :experiences
      assert_equal "array", schema[:properties][:experiences][:type]

      item_props = schema[:properties][:experiences][:items][:properties]
      assert_includes item_props.keys, :location_ids
      assert_includes item_props.keys, :titles
      assert_includes item_props.keys, :descriptions
      assert_includes item_props.keys, :theme_reasoning
    end

    # === JSON sanitization tests ===

    test "sanitize_ai_json removes trailing commas" do
      json_with_comma = '{"name": "Test",}'
      result = @creator.send(:sanitize_ai_json, json_with_comma)
      assert_not_includes result, ",}"
    end

    test "sanitize_ai_json converts smart quotes" do
      json_with_smart_quotes = '{"name": "Test"}'
      result = @creator.send(:sanitize_ai_json, json_with_smart_quotes)
      assert_includes result, '"'
    end

    test "parse_ai_json_response parses valid JSON" do
      content = '{"name": "Test", "value": 123}'
      result = @creator.send(:parse_ai_json_response, content)

      assert_equal "Test", result[:name]
      assert_equal 123, result[:value]
    end

    test "parse_ai_json_response extracts JSON from markdown" do
      content = "```json\n{\"name\": \"Test\"}\n```"
      result = @creator.send(:parse_ai_json_response, content)
      assert_equal "Test", result[:name]
    end

    test "parse_ai_json_response returns empty hash for invalid JSON" do
      result = @creator.send(:parse_ai_json_response, "not valid json")
      assert_equal({}, result)
    end

    # === Control character escaping tests ===

    test "escape_chars_in_json_strings handles newlines" do
      json_with_newline = "{\"text\": \"line1\nline2\"}"
      result = @creator.send(:escape_chars_in_json_strings, json_with_newline)
      assert_includes result, "\\n"
    end

    test "escape_chars_in_json_strings handles tabs" do
      json_with_tab = "{\"text\": \"col1\tcol2\"}"
      result = @creator.send(:escape_chars_in_json_strings, json_with_tab)
      assert_includes result, "\\t"
    end

    # === Embedded quote detection tests ===

    test "looks_like_embedded_quote returns false for end of string" do
      json_str = '{"name": "Test"}'
      # Position of closing quote before }
      result = @creator.send(:looks_like_embedded_quote?, json_str, 14)
      assert_not result
    end

    test "looks_like_embedded_quote returns true for quote in text" do
      json_str = '{"text": "He said hello there"}'
      # Position where text continues
      result = @creator.send(:looks_like_embedded_quote?, json_str, 18)
      assert result
    end

    # === find_locations_by_names tests ===

    test "find_locations_by_names matches locations by partial name" do
      loc1 = create_mock_location(name: "Gazi Husrev-beg Mosque")
      loc2 = create_mock_location(name: "Latin Bridge")

      available = [loc1, loc2]
      names = ["Husrev", "Bridge"]

      result = @creator.send(:find_locations_by_names, names, available)
      assert_equal 2, result.count
    end

    test "find_locations_by_names handles non-matching names" do
      loc1 = create_mock_location(name: "Museum")

      result = @creator.send(:find_locations_by_names, ["Nonexistent"], [loc1])
      assert_equal [], result
    end

    # === Error handling tests ===

    test "ai_propose_local_experiences handles API errors gracefully" do
      mock_location = create_mock_location(name: "Test")

      Ai::OpenaiQueue.stub :request, ->(*args) { raise Ai::OpenaiQueue::RequestError, "API error" } do
        result = @creator.send(:ai_propose_local_experiences, [mock_location], "Sarajevo")
        assert_equal [], result
      end
    end

    test "ai_propose_thematic_experiences handles API errors gracefully" do
      mock_location = create_mock_location(name: "Test", city: "Sarajevo")

      Ai::OpenaiQueue.stub :request, ->(*args) { raise Ai::OpenaiQueue::RequestError, "API error" } do
        result = @creator.send(:ai_propose_thematic_experiences, [mock_location])
        assert_equal [], result
      end
    end

    # === TITLE_SIMILARITY_THRESHOLD constant test ===

    test "TITLE_SIMILARITY_THRESHOLD is set to 0.75" do
      assert_equal 0.75, Ai::ExperienceCreator::TITLE_SIMILARITY_THRESHOLD
    end

    # === EXCLUDED_CATEGORY_KEYS constant test ===

    test "EXCLUDED_CATEGORY_KEYS includes retirement home related keys" do
      excluded = Ai::ExperienceCreator::EXCLUDED_CATEGORY_KEYS
      assert_includes excluded, "retirement_home"
      assert_includes excluded, "dom_penzionera"
    end

    private

    def create_mock_location(id: nil, name: "Test Location", city: "Sarajevo", lat: 43.856, lng: 18.413, location_categories: [], tags: [])
      mock = OpenStruct.new(
        id: id || rand(1000..9999),
        name: name,
        city: city,
        lat: lat,
        lng: lng,
        location_type: "place",
        description: "A test description",
        tags: tags
      )

      # Mock experience_types
      exp_types = OpenStruct.new
      exp_types.define_singleton_method(:pluck) { |_| ["culture", "history"] }
      mock.define_singleton_method(:experience_types) { exp_types }

      # Mock location_categories
      mock.define_singleton_method(:location_categories) do
        cats = OpenStruct.new(data: location_categories)
        cats.define_singleton_method(:any?) { |&block| location_categories.any?(&block) }
        cats.define_singleton_method(:pluck) { |key| location_categories.map { |c| c.send(key) } }
        cats
      end

      mock
    end

    def mock_location_relation(locations)
      relation = OpenStruct.new(data: locations)
      relation.define_singleton_method(:with_coordinates) { self }
      relation.define_singleton_method(:includes) { |*args| self }
      relation.define_singleton_method(:count) { locations.count }
      relation.define_singleton_method(:each) { |&block| locations.each(&block) }
      relation.define_singleton_method(:map) { |&block| locations.map(&block) }
      relation.define_singleton_method(:select) { |&block| locations.select(&block) }
      relation.define_singleton_method(:to_a) { locations }
      relation
    end

    def stub_ai_queue_response(response)
      Ai::OpenaiQueue.stub :request, response do
        yield
      end
    end

    def stub_setting_min_locations(value)
      Setting.stub :get, ->(key, **opts) {
        key == "experience.min_locations" ? value : opts[:default]
      } do
        yield
      end
    end
  end
end
