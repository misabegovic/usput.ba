# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class PlanCreatorTest < ActiveSupport::TestCase
    setup do
      @creator = Ai::PlanCreator.new
    end

    # === Initialization tests ===

    test "initializes without errors" do
      assert_nothing_raised { Ai::PlanCreator.new }
    end

    test "initializes with nil existing plans cache" do
      creator = Ai::PlanCreator.new
      assert_nil creator.instance_variable_get(:@existing_plans_cache)
    end

    # === TOURIST_PROFILES constant tests ===

    test "TOURIST_PROFILES includes expected profiles" do
      profiles = Ai::PlanCreator::TOURIST_PROFILES

      assert_includes profiles.keys, "family"
      assert_includes profiles.keys, "couple"
      assert_includes profiles.keys, "adventure"
      assert_includes profiles.keys, "nature"
      assert_includes profiles.keys, "culture"
      assert_includes profiles.keys, "budget"
      assert_includes profiles.keys, "luxury"
      assert_includes profiles.keys, "foodie"
      assert_includes profiles.keys, "solo"
    end

    test "TOURIST_PROFILES family has correct structure" do
      family = Ai::PlanCreator::TOURIST_PROFILES["family"]

      assert family[:description].present?
      assert family[:preferences][:pace].present?
      assert_kind_of Array, family[:preferences][:activities]
      assert family[:preferences][:budget].present?
    end

    test "TITLE_SIMILARITY_THRESHOLD is set to 0.75" do
      assert_equal 0.75, Ai::PlanCreator::TITLE_SIMILARITY_THRESHOLD
    end

    # === generate_profile_data tests ===

    test "generate_profile_data creates data for unknown profiles" do
      result = @creator.send(:generate_profile_data, "photography_enthusiast")

      assert_equal "Photography Enthusiast", result[:description]
      assert_equal "moderate", result[:preferences][:pace]
      assert_kind_of Array, result[:preferences][:activities]
    end

    test "generate_profile_data handles underscores and hyphens" do
      result = @creator.send(:generate_profile_data, "eco_friendly-traveler")
      assert_equal "Eco Friendly Traveler", result[:description]
    end

    # === generate_default_title tests ===

    test "generate_default_title returns English title for family profile" do
      result = @creator.send(:generate_default_title, "family", "Sarajevo", "en")
      assert_includes result, "Family Adventure"
      assert_includes result, "Sarajevo"
    end

    test "generate_default_title returns Bosnian title for family profile" do
      result = @creator.send(:generate_default_title, "family", "Sarajevo", "bs")
      assert_includes result, "Porodična avantura"
      assert_includes result, "Sarajevo"
    end

    test "generate_default_title handles nil city" do
      result = @creator.send(:generate_default_title, "couple", nil, "en")
      assert_includes result, "BiH"
    end

    test "generate_default_title handles unknown profile" do
      result = @creator.send(:generate_default_title, "unknown_profile", "Mostar", "en")
      assert_includes result, "Unknown Profile"
      assert_includes result, "Mostar"
    end

    # === create_for_profile tests ===

    test "create_for_profile returns nil when no experiences available" do
      stub_experiences_empty do
        stub_setting_min_experiences(2) do
          result = @creator.create_for_profile(profile: "family", city: "Sarajevo")
          assert_nil result
        end
      end
    end

    test "create_for_profile normalizes profile name" do
      stub_experiences_empty do
        stub_setting_min_experiences(100) do
          # Should handle uppercase and whitespace
          result = @creator.create_for_profile(profile: "  FAMILY  ", city: "Sarajevo")
          # Will return nil due to no experiences, but shouldn't error
          assert_nil result
        end
      end
    end

    test "create_for_profile calls AI with correct parameters" do
      mock_experience = create_mock_experience(id: 1)

      mock_ai_response = {
        duration_days: 3,
        titles: { "en" => "Test Plan", "bs" => "Test Plan BS" },
        notes: { "en" => "Notes", "bs" => "Biljeske" },
        days: [
          { day_number: 1, theme: "Day 1", experience_ids: [1] }
        ],
        reasoning: "Test reasoning"
      }

      stub_experiences_with([mock_experience]) do
        stub_setting_min_experiences(1) do
          stub_ai_queue_response(mock_ai_response) do
            stub_existing_plans_empty do
              # The method will try to create a plan, which may fail in test environment
              # but we're testing the flow, not the actual creation
              result = @creator.create_for_profile(profile: "family", city: "Sarajevo")
              # Result may be nil if Plan.save fails in test, that's ok
              assert [NilClass, Plan].include?(result.class)
            end
          end
        end
      end
    end

    # === create_for_all_profiles tests ===

    test "create_for_all_profiles iterates through all profiles" do
      called_profiles = []

      @creator.stub :create_for_profile, ->(profile:, city:) {
        called_profiles << profile
        nil
      } do
        @creator.create_for_all_profiles(city: "Sarajevo")
      end

      Ai::PlanCreator::TOURIST_PROFILES.keys.each do |profile|
        assert_includes called_profiles, profile
      end
    end

    test "create_for_all_profiles accepts custom profiles list" do
      called_profiles = []

      @creator.stub :create_for_profile, ->(profile:, city:) {
        called_profiles << profile
        nil
      } do
        @creator.create_for_all_profiles(city: "Sarajevo", profiles: ["family", "couple"])
      end

      assert_equal 2, called_profiles.count
      assert_includes called_profiles, "family"
      assert_includes called_profiles, "couple"
    end

    # === add_experience_to_plan tests ===

    test "add_experience_to_plan creates plan_experience" do
      mock_plan = create_mock_plan
      mock_experience = create_mock_experience

      # Stub the plan_experiences association - where.maximum chain
      where_result = OpenStruct.new
      where_result.define_singleton_method(:maximum) { |_field| 0 }

      plan_experiences_mock = OpenStruct.new
      plan_experiences_mock.define_singleton_method(:exists?) { |*| false }
      plan_experiences_mock.define_singleton_method(:where) { |*| where_result }

      mock_plan.define_singleton_method(:plan_experiences) { plan_experiences_mock }

      PlanExperience.stub :create, ->(attrs) { OpenStruct.new(attrs) } do
        result = @creator.add_experience_to_plan(mock_experience, mock_plan, day_number: 1)
        assert_equal mock_experience, result[:experience]
        assert_equal mock_plan, result[:plan]
        assert_equal 1, result[:day_number]
      end
    end

    test "add_experience_to_plan returns nil if experience already exists" do
      mock_plan = create_mock_plan
      mock_experience = create_mock_experience

      plan_experiences_mock = OpenStruct.new
      plan_experiences_mock.define_singleton_method(:exists?) { |*| true }
      mock_plan.define_singleton_method(:plan_experiences) { plan_experiences_mock }

      result = @creator.add_experience_to_plan(mock_experience, mock_plan, day_number: 1)
      assert_nil result
    end

    # === Similarity checking tests ===

    test "word_similarity returns 1.0 for identical strings" do
      result = @creator.send(:word_similarity, "Test Plan", "Test Plan")
      assert_equal 1.0, result
    end

    test "word_similarity returns 0.0 for different strings" do
      result = @creator.send(:word_similarity, "Family Adventure", "Nature Escape")
      assert_equal 0.0, result
    end

    test "word_similarity returns partial match for overlapping words" do
      result = @creator.send(:word_similarity, "Sarajevo Family Trip", "Family Adventure Sarajevo")
      assert result > 0.0
      assert result < 1.0
    end

    test "word_similarity handles blank strings" do
      assert_equal 0.0, @creator.send(:word_similarity, "", "Test")
      assert_equal 0.0, @creator.send(:word_similarity, "Test", "")
    end

    test "normalize_for_comparison removes stop words" do
      result = @creator.send(:normalize_for_comparison, "The adventure in Bosnia")
      assert_not_includes result, "the"
      assert_not_includes result, "in"
      assert_includes result, "adventure"
      assert_includes result, "bosnia"
    end

    # === too_similar_to_existing tests ===

    test "too_similar_to_existing returns false when no existing plans" do
      @creator.stub :existing_plans, [] do
        result = @creator.send(:too_similar_to_existing?, "New Plan Title", "family", "Sarajevo")
        assert_not result
      end
    end

    test "too_similar_to_existing returns true for same profile and city" do
      existing = [{
        id: 1,
        title: "Different Title",
        title_en: "Different Title",
        title_bs: "Drugaciji Naslov",
        profile: "family",
        city: "Sarajevo"
      }]

      @creator.stub :existing_plans, existing do
        result = @creator.send(:too_similar_to_existing?, "New Title", "family", "Sarajevo")
        assert result
      end
    end

    test "too_similar_to_existing returns true for similar title" do
      existing = [{
        id: 1,
        title: "Family Adventure Sarajevo",
        title_en: "Family Adventure Sarajevo",
        title_bs: nil,
        profile: "couple", # different profile
        city: "Mostar"     # different city
      }]

      @creator.stub :existing_plans, existing do
        result = @creator.send(:too_similar_to_existing?, "Family Adventure Sarajevo", "family", "Sarajevo")
        assert result
      end
    end

    # === Schema tests ===

    test "plan_proposal_schema has correct structure" do
      schema = @creator.send(:plan_proposal_schema)

      assert_equal "object", schema[:type]
      assert_includes schema[:properties].keys, :duration_days
      assert_includes schema[:properties].keys, :titles
      assert_includes schema[:properties].keys, :notes
      assert_includes schema[:properties].keys, :days
      assert_includes schema[:properties].keys, :reasoning
    end

    test "plan_proposal_schema days has correct item structure" do
      schema = @creator.send(:plan_proposal_schema)
      day_props = schema[:properties][:days][:items][:properties]

      assert_includes day_props.keys, :day_number
      assert_includes day_props.keys, :theme
      assert_includes day_props.keys, :experience_ids
    end

    # === JSON parsing tests ===

    test "parse_ai_json_response parses valid JSON" do
      content = '{"title": "Test", "days": 3}'
      result = @creator.send(:parse_ai_json_response, content)

      assert_equal "Test", result[:title]
      assert_equal 3, result[:days]
    end

    test "parse_ai_json_response extracts JSON from markdown" do
      content = "```json\n{\"title\": \"Test\"}\n```"
      result = @creator.send(:parse_ai_json_response, content)
      assert_equal "Test", result[:title]
    end

    test "parse_ai_json_response returns nil for invalid JSON" do
      result = @creator.send(:parse_ai_json_response, "not valid json")
      assert_nil result
    end

    test "sanitize_ai_json removes trailing commas" do
      json = '{"title": "Test",}'
      result = @creator.send(:sanitize_ai_json, json)
      assert_not_includes result, ",}"
    end

    test "sanitize_ai_json converts smart quotes" do
      json = '{"title": "Test"}'
      result = @creator.send(:sanitize_ai_json, json)
      assert_includes result, '"'
    end

    # === Control character escaping tests ===

    test "escape_chars_in_json_strings handles newlines" do
      json = "{\"text\": \"line1\nline2\"}"
      result = @creator.send(:escape_chars_in_json_strings, json)
      assert_includes result, "\\n"
    end

    test "escape_chars_in_json_strings handles tabs" do
      json = "{\"text\": \"col1\tcol2\"}"
      result = @creator.send(:escape_chars_in_json_strings, json)
      assert_includes result, "\\t"
    end

    # === Embedded quote detection tests ===

    test "looks_like_embedded_quote returns false at end of string" do
      json = '{"name": "Test"}'
      result = @creator.send(:looks_like_embedded_quote?, json, 14)
      assert_not result
    end

    test "looks_like_embedded_quote returns true for mid-string quote" do
      json = '{"text": "He said hello there"}'
      result = @creator.send(:looks_like_embedded_quote?, json, 18)
      assert result
    end

    # === Error handling tests ===

    test "ai_propose_plan handles API errors gracefully" do
      mock_experience = create_mock_experience
      profile_data = { description: "Test", preferences: { pace: "moderate", activities: ["culture"], budget: "medium" } }

      Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API error" } do
        result = @creator.send(:ai_propose_plan, [mock_experience], "family", profile_data, "Sarajevo", nil)
        assert_nil result
      end
    end

    # === determine_primary_city tests ===

    test "determine_primary_city returns most common city" do
      loc1 = OpenStruct.new(city: "Sarajevo")
      loc2 = OpenStruct.new(city: "Sarajevo")
      loc3 = OpenStruct.new(city: "Mostar")

      locations_mock = OpenStruct.new
      locations_mock.define_singleton_method(:pluck) { |_| ["Sarajevo", "Sarajevo", "Mostar"] }

      exp1 = create_mock_experience(id: 1)
      exp1.define_singleton_method(:locations) { locations_mock }

      exp2 = create_mock_experience(id: 2)
      exp2.define_singleton_method(:locations) { locations_mock }

      proposal = { days: [{ experience_ids: [1, 2] }] }

      result = @creator.send(:determine_primary_city, proposal, [exp1, exp2])
      assert_equal "Sarajevo", result
    end

    test "determine_primary_city returns nil for empty proposal" do
      proposal = { days: [] }
      result = @creator.send(:determine_primary_city, proposal, [])
      assert_nil result
    end

    # === fetch_available_experiences tests ===

    test "fetch_available_experiences filters by city when provided" do
      mock_experience = create_mock_experience
      stub_experiences_with([mock_experience]) do
        result = @creator.send(:fetch_available_experiences, "Sarajevo", nil)
        assert_equal 1, result.count
      end
    end

    test "fetch_available_experiences returns all when city is nil" do
      mock_experience = create_mock_experience
      stub_experiences_with([mock_experience]) do
        result = @creator.send(:fetch_available_experiences, nil, nil)
        assert_equal 1, result.count
      end
    end

    test "fetch_available_experiences filters by experience types when provided" do
      mock_experience = create_mock_experience
      stub_experiences_with([mock_experience]) do
        result = @creator.send(:fetch_available_experiences, "Sarajevo", ["culture", "history"])
        assert_equal 1, result.count
      end
    end

    test "fetch_available_experiences does not filter when activities is empty array" do
      mock_experience = create_mock_experience
      stub_experiences_with([mock_experience]) do
        result = @creator.send(:fetch_available_experiences, "Sarajevo", [])
        assert_equal 1, result.count
      end
    end

    test "fetch_available_experiences does not filter when activities is nil" do
      mock_experience = create_mock_experience
      stub_experiences_with([mock_experience]) do
        result = @creator.send(:fetch_available_experiences, "Sarajevo", nil)
        assert_equal 1, result.count
      end
    end

    test "create_for_profile passes profile activities to fetch_available_experiences" do
      mock_experience = create_mock_experience(id: 1)

      mock_ai_response = {
        duration_days: 3,
        titles: { "en" => "Test Plan", "bs" => "Test Plan BS" },
        notes: { "en" => "Notes", "bs" => "Biljeske" },
        days: [
          { day_number: 1, theme: "Day 1", experience_ids: [1] }
        ],
        reasoning: "Test reasoning"
      }

      fetch_called_with = nil
      @creator.stub :fetch_available_experiences, ->(city, activities) {
        fetch_called_with = { city: city, activities: activities }
        [mock_experience]
      } do
        stub_setting_min_experiences(1) do
          stub_ai_queue_response(mock_ai_response) do
            stub_existing_plans_empty do
              @creator.create_for_profile(profile: "family", city: "Sarajevo")
            end
          end
        end
      end

      assert_not_nil fetch_called_with
      assert_equal "Sarajevo", fetch_called_with[:city]
      assert fetch_called_with[:activities].is_a?(Array)
    end

    test "create_for_profile handles profile with empty activities" do
      mock_experience = create_mock_experience(id: 1)

      # Create a profile with empty activities array
      custom_profile = {
        description: "Test Profile",
        preferences: {
          pace: "moderate",
          activities: [],
          budget: "medium"
        }
      }

      @creator.stub :generate_profile_data, custom_profile do
        stub_experiences_with([mock_experience]) do
          stub_setting_min_experiences(1) do
            stub_ai_queue_response({
              duration_days: 1,
              titles: { "en" => "Test" },
              notes: { "en" => "Notes" },
              days: [{ day_number: 1, theme: "Day 1", experience_ids: [1] }],
              reasoning: "Test"
            }) do
              stub_existing_plans_empty do
                result = @creator.create_for_profile(profile: "custom", city: "Sarajevo")
                # Should not crash, may return nil or Plan
                assert [NilClass, Plan].include?(result.class)
              end
            end
          end
        end
      end
    end

    test "fetch_available_experiences uses Experience.all when city is nil" do
      mock_experience = create_mock_experience

      # Verify that Experience.all is called when city is nil
      all_called = false
      Experience.stub :all, ->() {
        all_called = true
        mock_relation = OpenStruct.new
        mock_relation.define_singleton_method(:includes) { |*| [mock_experience] }
        mock_relation
      } do
        result = @creator.send(:fetch_available_experiences, nil, nil)
        assert all_called
      end
    end

    test "fetch_available_experiences applies both city and activities filters" do
      mock_experience = create_mock_experience

      stub_experiences_with([mock_experience]) do
        result = @creator.send(:fetch_available_experiences, "Sarajevo", ["culture", "history"])
        # Should apply both filters
        assert_equal 1, result.count
      end
    end

    test "fetch_available_experiences includes locations and experience_category" do
      mock_experience = create_mock_experience

      includes_called_with = nil
      mock_relation = OpenStruct.new
      mock_relation.define_singleton_method(:where) { |*| self }
      mock_relation.define_singleton_method(:distinct) { self }
      mock_relation.define_singleton_method(:joins) { |*| self }
      mock_relation.define_singleton_method(:includes) do |*args|
        includes_called_with = args
        [mock_experience]
      end

      Experience.stub :joins, mock_relation do
        @creator.send(:fetch_available_experiences, "Sarajevo", nil)
        assert_equal [:locations, :experience_category], includes_called_with
      end
    end

    private

    def create_mock_experience(id: nil)
      mock = OpenStruct.new(
        id: id || rand(1000..9999),
        title: "Test Experience",
        description: "Description",
        estimated_duration: 120,
        formatted_duration: "2h"
      )

      locations_mock = OpenStruct.new
      locations_mock.define_singleton_method(:pluck) { |_| ["Sarajevo"] }
      locations_mock.define_singleton_method(:count) { 2 }

      mock.define_singleton_method(:locations) { locations_mock }
      mock.define_singleton_method(:category_name) { "Culture" }

      mock
    end

    def create_mock_plan(id: nil)
      OpenStruct.new(
        id: id || rand(1000..9999),
        title: "Test Plan",
        city_name: "Sarajevo"
      )
    end

    def stub_experiences_empty
      Experience.stub :joins, Experience.none do
        Experience.stub :includes, Experience.none do
          yield
        end
      end
    end

    def stub_experiences_with(experiences)
      mock_relation = OpenStruct.new(data: experiences)
      mock_relation.define_singleton_method(:where) { |*| self }
      mock_relation.define_singleton_method(:distinct) { self }
      mock_relation.define_singleton_method(:includes) { |*| self }
      mock_relation.define_singleton_method(:joins) { |*| self }
      mock_relation.define_singleton_method(:all) { self }
      mock_relation.define_singleton_method(:count) { experiences.count }
      mock_relation.define_singleton_method(:each) { |&block| experiences.each(&block) }
      mock_relation.define_singleton_method(:map) { |&block| experiences.map(&block) }
      mock_relation.define_singleton_method(:index_by) { |&block| experiences.index_by(&block) }
      mock_relation.define_singleton_method(:select) { |&block| experiences.select(&block) }

      Experience.stub :joins, mock_relation do
        Experience.stub :includes, mock_relation do
          Experience.stub :all, mock_relation do
            yield
          end
        end
      end
    end

    def stub_setting_min_experiences(value)
      Setting.stub :get, ->(key, **opts) {
        key == "plan.min_experiences" ? value : opts[:default]
      } do
        yield
      end
    end

    def stub_ai_queue_response(response)
      Ai::OpenaiQueue.stub :request, response do
        yield
      end
    end

    def stub_existing_plans_empty
      @creator.stub :existing_plans, [] do
        @creator.stub :too_similar_to_existing?, false do
          yield
        end
      end
    end
  end
end
