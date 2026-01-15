# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class ContentOrchestratorTest < ActiveSupport::TestCase
    setup do
      # Clear any prior state
      Ai::ContentOrchestrator.force_reset!
    end

    teardown do
      # Reset state after each test
      Ai::ContentOrchestrator.force_reset!
    end

    # ═══════════════════════════════════════════════════════════
    # CONSTANTS TESTS
    # ═══════════════════════════════════════════════════════════

    test "DEFAULT_MAX_LOCATIONS is defined as 100" do
      assert_equal 100, Ai::ContentOrchestrator::DEFAULT_MAX_LOCATIONS
    end

    test "DEFAULT_MAX_EXPERIENCES is defined as 200" do
      assert_equal 200, Ai::ContentOrchestrator::DEFAULT_MAX_EXPERIENCES
    end

    test "DEFAULT_MAX_PLANS is defined as 50" do
      assert_equal 50, Ai::ContentOrchestrator::DEFAULT_MAX_PLANS
    end

    # ═══════════════════════════════════════════════════════════
    # ERROR CLASSES TESTS
    # ═══════════════════════════════════════════════════════════

    test "GenerationError is a subclass of StandardError" do
      assert Ai::ContentOrchestrator::GenerationError < StandardError
    end

    test "CancellationError is a subclass of StandardError" do
      assert Ai::ContentOrchestrator::CancellationError < StandardError
    end

    test "GenerationError can be instantiated with message" do
      error = Ai::ContentOrchestrator::GenerationError.new("Test error")
      assert_equal "Test error", error.message
    end

    test "CancellationError can be instantiated with message" do
      error = Ai::ContentOrchestrator::CancellationError.new("Cancelled")
      assert_equal "Cancelled", error.message
    end

    # ═══════════════════════════════════════════════════════════
    # INITIALIZATION TESTS
    # ═══════════════════════════════════════════════════════════

    test "initializes with default limits" do
      orchestrator = create_orchestrator
      assert_equal 100, orchestrator.instance_variable_get(:@max_locations)
      assert_equal 200, orchestrator.instance_variable_get(:@max_experiences)
      assert_equal 50, orchestrator.instance_variable_get(:@max_plans)
    end

    test "initializes with custom limits" do
      orchestrator = create_orchestrator(
        max_locations: 10,
        max_experiences: 20,
        max_plans: 5
      )
      assert_equal 10, orchestrator.instance_variable_get(:@max_locations)
      assert_equal 20, orchestrator.instance_variable_get(:@max_experiences)
      assert_equal 5, orchestrator.instance_variable_get(:@max_plans)
    end

    test "initializes with zero limit means unlimited" do
      orchestrator = create_orchestrator(
        max_locations: 0,
        max_experiences: 0,
        max_plans: 0
      )
      assert_nil orchestrator.instance_variable_get(:@max_locations)
      assert_nil orchestrator.instance_variable_get(:@max_experiences)
      assert_nil orchestrator.instance_variable_get(:@max_plans)
    end

    test "initializes with skip flags" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )
      assert orchestrator.instance_variable_get(:@skip_locations)
      assert orchestrator.instance_variable_get(:@skip_experiences)
      assert orchestrator.instance_variable_get(:@skip_plans)
    end

    test "initializes results hash with correct keys" do
      orchestrator = create_orchestrator
      results = orchestrator.instance_variable_get(:@results)

      assert results.key?(:started_at)
      assert_equal 0, results[:locations_created]
      assert_equal 0, results[:locations_enriched]
      assert_equal 0, results[:experiences_created]
      assert_equal 0, results[:plans_created]
      assert_equal [], results[:errors]
      assert_equal [], results[:cities_processed]
    end

    test "initializes results with skipped tracking" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: false,
        skip_plans: true
      )
      results = orchestrator.instance_variable_get(:@results)

      assert results[:skipped][:locations]
      assert_not results[:skipped][:experiences]
      assert results[:skipped][:plans]
    end

    # ═══════════════════════════════════════════════════════════
    # CLASS METHOD: current_status TESTS
    # ═══════════════════════════════════════════════════════════

    test "current_status returns hash with expected keys" do
      status = Ai::ContentOrchestrator.current_status

      assert status.is_a?(Hash)
      assert_includes status.keys, :status
      assert_includes status.keys, :message
      assert_includes status.keys, :started_at
      assert_includes status.keys, :plan
      assert_includes status.keys, :results
    end

    test "current_status returns idle by default" do
      Ai::ContentOrchestrator.force_reset!
      status = Ai::ContentOrchestrator.current_status

      assert_equal "idle", status[:status]
    end

    test "current_status returns saved status" do
      Setting.set("ai.generation.status", "in_progress")
      Setting.set("ai.generation.message", "Processing city")

      status = Ai::ContentOrchestrator.current_status

      assert_equal "in_progress", status[:status]
      assert_equal "Processing city", status[:message]
    end

    test "current_status parses plan JSON" do
      plan = { analysis: "Test", target_cities: [] }
      Setting.set("ai.generation.plan", plan.to_json)

      status = Ai::ContentOrchestrator.current_status

      assert_equal "Test", status[:plan]["analysis"]
    end

    test "current_status parses results JSON" do
      results = { locations_created: 5, experiences_created: 2 }
      Setting.set("ai.generation.results", results.to_json)

      status = Ai::ContentOrchestrator.current_status

      assert_equal 5, status[:results]["locations_created"]
    end

    test "current_status handles invalid JSON gracefully" do
      Setting.set("ai.generation.plan", "not valid json")

      status = Ai::ContentOrchestrator.current_status

      assert_equal "idle", status[:status]
      assert_equal({}, status[:plan])
    end

    # ═══════════════════════════════════════════════════════════
    # CLASS METHOD: cancel_generation! TESTS
    # ═══════════════════════════════════════════════════════════

    test "cancel_generation! sets cancelled flag" do
      Ai::ContentOrchestrator.clear_cancellation!
      assert_equal false, Ai::ContentOrchestrator.cancelled?

      Ai::ContentOrchestrator.cancel_generation!

      assert_equal true, Ai::ContentOrchestrator.cancelled?
    end

    test "cancel_generation! sets message" do
      Ai::ContentOrchestrator.cancel_generation!

      message = Setting.get("ai.generation.message")
      assert_equal "Generation was stopped by user", message
    end

    # ═══════════════════════════════════════════════════════════
    # CLASS METHOD: cancelled? TESTS
    # ═══════════════════════════════════════════════════════════

    test "cancelled? returns false by default" do
      Ai::ContentOrchestrator.clear_cancellation!
      assert_equal false, Ai::ContentOrchestrator.cancelled?
    end

    test "cancelled? returns true after cancel_generation!" do
      Ai::ContentOrchestrator.cancel_generation!
      assert_equal true, Ai::ContentOrchestrator.cancelled?
    end

    # ═══════════════════════════════════════════════════════════
    # CLASS METHOD: clear_cancellation! TESTS
    # ═══════════════════════════════════════════════════════════

    test "clear_cancellation! clears cancelled flag" do
      Ai::ContentOrchestrator.cancel_generation!
      assert_equal true, Ai::ContentOrchestrator.cancelled?

      Ai::ContentOrchestrator.clear_cancellation!

      assert_equal false, Ai::ContentOrchestrator.cancelled?
    end

    # ═══════════════════════════════════════════════════════════
    # CLASS METHOD: force_reset! TESTS
    # ═══════════════════════════════════════════════════════════

    test "force_reset! resets all status" do
      Setting.set("ai.generation.status", "in_progress")
      Setting.set("ai.generation.cancelled", "true")
      Setting.set("ai.generation.message", "Processing")

      Ai::ContentOrchestrator.force_reset!

      assert_equal "idle", Setting.get("ai.generation.status")
      assert_equal "false", Setting.get("ai.generation.cancelled")
      # force_reset! sets message to nil, but Setting.get with nil returns empty string
      msg = Setting.get("ai.generation.message")
      assert(msg.nil? || msg.empty?, "Expected message to be nil or empty, got: #{msg.inspect}")
    end

    # ═══════════════════════════════════════════════════════════
    # CLASS METHOD: content_stats TESTS
    # ═══════════════════════════════════════════════════════════

    test "content_stats returns hash with cities and totals" do
      stats = Ai::ContentOrchestrator.content_stats

      assert stats.is_a?(Hash)
      assert_includes stats.keys, :cities
      assert_includes stats.keys, :totals
      assert stats[:cities].is_a?(Array)
      assert stats[:totals].is_a?(Hash)
    end

    test "content_stats totals include expected keys" do
      stats = Ai::ContentOrchestrator.content_stats

      assert_includes stats[:totals].keys, :locations
      assert_includes stats[:totals].keys, :experiences
      assert_includes stats[:totals].keys, :plans
      assert_includes stats[:totals].keys, :ai_plans
      assert_includes stats[:totals].keys, :audio
    end

    test "content_stats cities sorted by locations descending" do
      # Create test locations in different cities
      city1_locations = Location.where(city: "Sarajevo").count
      city2_locations = Location.where(city: "Mostar").count

      stats = Ai::ContentOrchestrator.content_stats

      # Verify cities are sorted by location count (descending)
      if stats[:cities].length > 1
        first_city = stats[:cities].first
        second_city = stats[:cities].second
        assert first_city[:locations] >= second_city[:locations]
      end
    end

    test "content_stats calculates audio coverage percentage" do
      stats = Ai::ContentOrchestrator.content_stats

      stats[:cities].each do |city_stat|
        if city_stat[:locations] > 0
          expected_coverage = (city_stat[:audio].to_f / city_stat[:locations] * 100).round(1)
          assert_equal expected_coverage, city_stat[:audio_coverage]
        else
          assert_equal 0, city_stat[:audio_coverage]
        end
      end
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: orchestration_plan_schema TESTS
    # ═══════════════════════════════════════════════════════════

    test "orchestration_plan_schema has correct structure" do
      orchestrator = create_orchestrator
      schema = orchestrator.send(:orchestration_plan_schema)

      assert_equal "object", schema[:type]
      assert schema[:additionalProperties] == false

      props = schema[:properties]
      assert_includes props.keys, :analysis
      assert_includes props.keys, :target_cities
      assert_includes props.keys, :tourist_profiles_to_generate
      assert_includes props.keys, :estimated_new_content
    end

    test "orchestration_plan_schema target_cities has correct item structure" do
      orchestrator = create_orchestrator
      schema = orchestrator.send(:orchestration_plan_schema)

      city_props = schema[:properties][:target_cities][:items][:properties]

      assert_includes city_props.keys, :city
      assert_includes city_props.keys, :country
      assert_includes city_props.keys, :coordinates
      assert_includes city_props.keys, :locations_to_fetch
      assert_includes city_props.keys, :categories
      assert_includes city_props.keys, :reasoning
    end

    test "orchestration_plan_schema coordinates has lat/lng" do
      orchestrator = create_orchestrator
      schema = orchestrator.send(:orchestration_plan_schema)

      coord_props = schema[:properties][:target_cities][:items][:properties][:coordinates][:properties]
      assert_includes coord_props.keys, :lat
      assert_includes coord_props.keys, :lng
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: gather_current_state TESTS
    # ═══════════════════════════════════════════════════════════

    test "gather_current_state returns expected keys" do
      orchestrator = create_orchestrator
      state = orchestrator.send(:gather_current_state)

      assert_includes state.keys, :existing_cities
      assert_includes state.keys, :locations_per_city
      assert_includes state.keys, :experiences_per_city
      assert_includes state.keys, :plans_per_city
      assert_includes state.keys, :target_country
      assert_includes state.keys, :target_country_code
      assert_includes state.keys, :max_experiences
    end

    test "gather_current_state includes max_experiences limit" do
      orchestrator = create_orchestrator(max_experiences: 50)
      state = orchestrator.send(:gather_current_state)

      assert_equal 50, state[:max_experiences]
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: default_categories TESTS
    # ═══════════════════════════════════════════════════════════

    test "default_categories returns array of tourism categories" do
      orchestrator = create_orchestrator
      categories = orchestrator.send(:default_categories)

      assert categories.is_a?(Array)
      assert_includes categories, "tourism.attraction"
      assert_includes categories, "catering.restaurant"
      assert_includes categories, "entertainment.museum"
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: default_target_cities TESTS
    # ═══════════════════════════════════════════════════════════

    test "default_target_cities returns array with Sarajevo, Mostar, Jajce" do
      orchestrator = create_orchestrator
      cities = orchestrator.send(:default_target_cities)

      city_names = cities.map { |c| c[:city] }
      assert_includes city_names, "Sarajevo"
      assert_includes city_names, "Mostar"
      assert_includes city_names, "Jajce"
    end

    test "default_target_cities include coordinates" do
      orchestrator = create_orchestrator
      cities = orchestrator.send(:default_target_cities)

      cities.each do |city|
        assert city[:coordinates].present?
        assert city[:coordinates][:lat].present?
        assert city[:coordinates][:lng].present?
      end
    end

    test "default_target_cities include categories and reasoning" do
      orchestrator = create_orchestrator
      cities = orchestrator.send(:default_target_cities)

      cities.each do |city|
        assert city[:categories].is_a?(Array)
        assert city[:reasoning].present?
      end
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: create_fallback_plan TESTS
    # ═══════════════════════════════════════════════════════════

    test "create_fallback_plan returns plan with expected keys" do
      orchestrator = create_orchestrator
      state = { existing_cities: [], locations_per_city: {} }

      plan = orchestrator.send(:create_fallback_plan, state)

      assert_includes plan.keys, :analysis
      assert_includes plan.keys, :target_cities
      assert_includes plan.keys, :tourist_profiles_to_generate
      assert_includes plan.keys, :estimated_new_content
    end

    test "create_fallback_plan uses default cities when no existing" do
      orchestrator = create_orchestrator
      state = { existing_cities: [], locations_per_city: {} }

      plan = orchestrator.send(:create_fallback_plan, state)

      assert plan[:target_cities].length > 0
    end

    test "create_fallback_plan adds cities with insufficient content" do
      orchestrator = create_orchestrator
      state = {
        existing_cities: ["TestCity"],
        locations_per_city: { "TestCity" => 5 }
      }

      plan = orchestrator.send(:create_fallback_plan, state)

      city_names = plan[:target_cities].map { |c| c[:city] }
      assert_includes city_names, "TestCity"
    end

    test "create_fallback_plan skips cities with sufficient content" do
      orchestrator = create_orchestrator
      state = {
        existing_cities: ["WellCoveredCity"],
        locations_per_city: { "WellCoveredCity" => 50 }
      }

      plan = orchestrator.send(:create_fallback_plan, state)

      city_names = plan[:target_cities].map { |c| c[:city] }
      assert_not_includes city_names, "WellCoveredCity"
    end

    test "create_fallback_plan limits to 3 cities" do
      orchestrator = create_orchestrator
      state = { existing_cities: [], locations_per_city: {} }

      plan = orchestrator.send(:create_fallback_plan, state)

      assert plan[:target_cities].length <= 3
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: valid_location_for_country? TESTS
    # ═══════════════════════════════════════════════════════════

    test "valid_location_for_country? returns true for matching city" do
      orchestrator = create_orchestrator
      place = { address: "Main Street, Sarajevo" }

      result = orchestrator.send(:valid_location_for_country?, place, "ba", "Sarajevo")
      assert result
    end

    test "valid_location_for_country? returns true for country code match" do
      orchestrator = create_orchestrator
      place = { address: "Some Street, ba" }

      result = orchestrator.send(:valid_location_for_country?, place, "ba", "OtherCity")
      assert result
    end

    test "valid_location_for_country? returns true for bosnia in address" do
      orchestrator = create_orchestrator
      place = { address: "Street, Bosnia and Herzegovina" }

      result = orchestrator.send(:valid_location_for_country?, place, "ba", "OtherCity")
      assert result
    end

    test "valid_location_for_country? returns true for herzegovina in address" do
      orchestrator = create_orchestrator
      place = { address: "Street, Herzegovina" }

      result = orchestrator.send(:valid_location_for_country?, place, "ba", "OtherCity")
      assert result
    end

    test "valid_location_for_country? returns true for bih in address" do
      orchestrator = create_orchestrator
      place = { address: "Street, BiH" }

      result = orchestrator.send(:valid_location_for_country?, place, "ba", "OtherCity")
      assert result
    end

    test "valid_location_for_country? returns false for non-matching location" do
      orchestrator = create_orchestrator
      place = { address: "Some Street, Zagreb, Croatia" }

      result = orchestrator.send(:valid_location_for_country?, place, "ba", "Sarajevo")
      assert_not result
    end

    test "valid_location_for_country? is case insensitive" do
      orchestrator = create_orchestrator
      place = { address: "Street, SARAJEVO" }

      result = orchestrator.send(:valid_location_for_country?, place, "ba", "sarajevo")
      assert result
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: locations_limit_reached? TESTS
    # ═══════════════════════════════════════════════════════════

    test "locations_limit_reached? returns false when no limit" do
      orchestrator = create_orchestrator(max_locations: 0)
      assert_not orchestrator.send(:locations_limit_reached?)
    end

    test "locations_limit_reached? returns false when under limit" do
      orchestrator = create_orchestrator(max_locations: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:locations_created] = 5

      assert_not orchestrator.send(:locations_limit_reached?)
    end

    test "locations_limit_reached? returns true when at limit" do
      orchestrator = create_orchestrator(max_locations: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:locations_created] = 10

      assert orchestrator.send(:locations_limit_reached?)
    end

    test "locations_limit_reached? returns true when over limit" do
      orchestrator = create_orchestrator(max_locations: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:locations_created] = 15

      assert orchestrator.send(:locations_limit_reached?)
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: remaining_location_slots TESTS
    # ═══════════════════════════════════════════════════════════

    test "remaining_location_slots returns nil when no limit" do
      orchestrator = create_orchestrator(max_locations: 0)
      assert_nil orchestrator.send(:remaining_location_slots)
    end

    test "remaining_location_slots returns correct count" do
      orchestrator = create_orchestrator(max_locations: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:locations_created] = 3

      assert_equal 7, orchestrator.send(:remaining_location_slots)
    end

    test "remaining_location_slots returns 0 when at or over limit" do
      orchestrator = create_orchestrator(max_locations: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:locations_created] = 15

      assert_equal 0, orchestrator.send(:remaining_location_slots)
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: experiences_limit_reached? TESTS
    # ═══════════════════════════════════════════════════════════

    test "experiences_limit_reached? returns false when no limit" do
      orchestrator = create_orchestrator(max_experiences: 0)
      assert_not orchestrator.send(:experiences_limit_reached?)
    end

    test "experiences_limit_reached? returns false when under limit" do
      orchestrator = create_orchestrator(max_experiences: 20)
      results = orchestrator.instance_variable_get(:@results)
      results[:experiences_created] = 10

      assert_not orchestrator.send(:experiences_limit_reached?)
    end

    test "experiences_limit_reached? returns true when at limit" do
      orchestrator = create_orchestrator(max_experiences: 20)
      results = orchestrator.instance_variable_get(:@results)
      results[:experiences_created] = 20

      assert orchestrator.send(:experiences_limit_reached?)
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: remaining_experience_slots TESTS
    # ═══════════════════════════════════════════════════════════

    test "remaining_experience_slots returns nil when no limit" do
      orchestrator = create_orchestrator(max_experiences: 0)
      assert_nil orchestrator.send(:remaining_experience_slots)
    end

    test "remaining_experience_slots returns correct count" do
      orchestrator = create_orchestrator(max_experiences: 20)
      results = orchestrator.instance_variable_get(:@results)
      results[:experiences_created] = 8

      assert_equal 12, orchestrator.send(:remaining_experience_slots)
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: plans_limit_reached? TESTS
    # ═══════════════════════════════════════════════════════════

    test "plans_limit_reached? returns false when no limit" do
      orchestrator = create_orchestrator(max_plans: 0)
      assert_not orchestrator.send(:plans_limit_reached?)
    end

    test "plans_limit_reached? returns false when under limit" do
      orchestrator = create_orchestrator(max_plans: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:plans_created] = 5

      assert_not orchestrator.send(:plans_limit_reached?)
    end

    test "plans_limit_reached? returns true when at limit" do
      orchestrator = create_orchestrator(max_plans: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:plans_created] = 10

      assert orchestrator.send(:plans_limit_reached?)
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: remaining_plan_slots TESTS
    # ═══════════════════════════════════════════════════════════

    test "remaining_plan_slots returns nil when no limit" do
      orchestrator = create_orchestrator(max_plans: 0)
      assert_nil orchestrator.send(:remaining_plan_slots)
    end

    test "remaining_plan_slots returns correct count" do
      orchestrator = create_orchestrator(max_plans: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:plans_created] = 4

      assert_equal 6, orchestrator.send(:remaining_plan_slots)
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: check_cancellation! TESTS
    # ═══════════════════════════════════════════════════════════

    test "check_cancellation! raises CancellationError when cancelled" do
      Ai::ContentOrchestrator.cancel_generation!
      orchestrator = create_orchestrator

      assert_raises(Ai::ContentOrchestrator::CancellationError) do
        orchestrator.send(:check_cancellation!)
      end
    end

    test "check_cancellation! does not raise when not cancelled" do
      Ai::ContentOrchestrator.clear_cancellation!
      orchestrator = create_orchestrator

      assert_nothing_raised do
        orchestrator.send(:check_cancellation!)
      end
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: save_generation_status TESTS
    # ═══════════════════════════════════════════════════════════

    test "save_generation_status saves status and message" do
      orchestrator = create_orchestrator
      orchestrator.send(:save_generation_status, "in_progress", "Processing")

      assert_equal "in_progress", Setting.get("ai.generation.status")
      assert_equal "Processing", Setting.get("ai.generation.message")
    end

    test "save_generation_status saves plan when provided" do
      orchestrator = create_orchestrator
      plan = { analysis: "Test plan" }
      orchestrator.send(:save_generation_status, "in_progress", "Processing", plan: plan)

      saved_plan = JSON.parse(Setting.get("ai.generation.plan"))
      assert_equal "Test plan", saved_plan["analysis"]
    end

    test "save_generation_status saves results when provided" do
      orchestrator = create_orchestrator
      results = { locations_created: 5 }
      orchestrator.send(:save_generation_status, "completed", "Done", results: results)

      saved_results = JSON.parse(Setting.get("ai.generation.results"))
      assert_equal 5, saved_results["locations_created"]
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: parse_ai_json_response TESTS
    # ═══════════════════════════════════════════════════════════

    test "parse_ai_json_response parses valid JSON" do
      orchestrator = create_orchestrator
      content = '{"name": "Test", "value": "123"}'

      result = orchestrator.send(:parse_ai_json_response, content)

      assert_equal "Test", result[:name]
      assert_equal "123", result[:value]
    end

    test "parse_ai_json_response extracts JSON from markdown code block" do
      orchestrator = create_orchestrator
      content = "```json\n{\"name\": \"Test\"}\n```"

      result = orchestrator.send(:parse_ai_json_response, content)

      assert_equal "Test", result[:name]
    end

    test "parse_ai_json_response extracts JSON without json label" do
      orchestrator = create_orchestrator
      content = "```\n{\"name\": \"Test\"}\n```"

      result = orchestrator.send(:parse_ai_json_response, content)

      assert_equal "Test", result[:name]
    end

    test "parse_ai_json_response returns empty hash for invalid JSON" do
      orchestrator = create_orchestrator
      content = "not valid json at all"

      result = orchestrator.send(:parse_ai_json_response, content)

      assert_equal({}, result)
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: sanitize_ai_json TESTS
    # ═══════════════════════════════════════════════════════════

    test "sanitize_ai_json removes trailing commas before closing brace" do
      orchestrator = create_orchestrator
      json = '{"name": "Test",}'

      result = orchestrator.send(:sanitize_ai_json, json)

      assert_not_includes result, ",}"
    end

    test "sanitize_ai_json removes trailing commas before closing bracket" do
      orchestrator = create_orchestrator
      json = '["a", "b",]'

      result = orchestrator.send(:sanitize_ai_json, json)

      assert_not_includes result, ",]"
    end

    test "sanitize_ai_json converts smart double quotes" do
      orchestrator = create_orchestrator
      json = '{"name": "Test"}'

      result = orchestrator.send(:sanitize_ai_json, json)

      assert_includes result, '"name"'
    end

    test "sanitize_ai_json converts smart single quotes" do
      orchestrator = create_orchestrator
      json = "{'name': 'Test'}"

      result = orchestrator.send(:sanitize_ai_json, json)

      assert_includes result, "'name'"
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: escape_chars_in_json_strings TESTS
    # ═══════════════════════════════════════════════════════════

    test "escape_chars_in_json_strings handles newlines" do
      orchestrator = create_orchestrator
      json = "{\"text\": \"line1\nline2\"}"

      result = orchestrator.send(:escape_chars_in_json_strings, json)

      assert_includes result, "\\n"
    end

    test "escape_chars_in_json_strings handles tabs" do
      orchestrator = create_orchestrator
      json = "{\"text\": \"col1\tcol2\"}"

      result = orchestrator.send(:escape_chars_in_json_strings, json)

      assert_includes result, "\\t"
    end

    test "escape_chars_in_json_strings handles carriage returns" do
      orchestrator = create_orchestrator
      json = "{\"text\": \"line1\rline2\"}"

      result = orchestrator.send(:escape_chars_in_json_strings, json)

      assert_includes result, "\\r"
    end

    test "escape_chars_in_json_strings preserves valid escape sequences" do
      orchestrator = create_orchestrator
      json = '{"text": "already\\nescaped"}'

      result = orchestrator.send(:escape_chars_in_json_strings, json)

      # Should not double-escape
      assert_includes result, "\\n"
      assert_not_includes result, "\\\\n"
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: looks_like_embedded_quote? TESTS
    # ═══════════════════════════════════════════════════════════

    test "looks_like_embedded_quote? returns false for end of string" do
      orchestrator = create_orchestrator
      json = '{"name": "Test"}'
      # Position 14 is the closing quote before }
      result = orchestrator.send(:looks_like_embedded_quote?, json, 14)
      assert_not result
    end

    test "looks_like_embedded_quote? returns true for mid-string quote" do
      orchestrator = create_orchestrator
      json = '{"text": "He said hello there"}'
      # Position 18 is within the string value
      result = orchestrator.send(:looks_like_embedded_quote?, json, 18)
      assert result
    end

    test "looks_like_embedded_quote? returns false for quote before key" do
      orchestrator = create_orchestrator
      json = '{"text": "value", "key": "another"}'
      # Position 16 is the closing quote of "value"
      result = orchestrator.send(:looks_like_embedded_quote?, json, 16)
      assert_not result
    end

    # ═══════════════════════════════════════════════════════════
    # generate METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "generate clears cancellation flag at start" do
      Ai::ContentOrchestrator.cancel_generation!

      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      # Stub AI request to return empty plan
      mock_plan = {
        analysis: "Test",
        target_cities: [],
        tourist_profiles_to_generate: [],
        estimated_new_content: { locations: 0, experiences: 0, plans: 0 }
      }

      Ai::OpenaiQueue.stub :request, mock_plan do
        orchestrator.generate
      end

      # Cancellation should have been cleared at start
      assert_equal "false", Setting.get("ai.generation.cancelled")
    end

    test "generate returns results hash on completion" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      mock_plan = {
        analysis: "Test",
        target_cities: [],
        tourist_profiles_to_generate: [],
        estimated_new_content: { locations: 0, experiences: 0, plans: 0 }
      }

      Ai::OpenaiQueue.stub :request, mock_plan do
        results = orchestrator.generate

        assert_equal "completed", results[:status]
        assert results[:finished_at].present?
      end
    end

    test "generate handles cancellation during execution" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      mock_plan = {
        analysis: "Test",
        target_cities: [{ city: "TestCity", categories: [] }],
        tourist_profiles_to_generate: ["family"],
        estimated_new_content: { locations: 0, experiences: 0, plans: 0 }
      }

      Ai::OpenaiQueue.stub :request, mock_plan do
        # Cancel during execution
        orchestrator.stub :execute_plan, ->(_plan) { Ai::ContentOrchestrator.cancel_generation!; raise Ai::ContentOrchestrator::CancellationError } do
          results = orchestrator.generate

          assert_equal "cancelled", results[:status]
        end
      end
    end

    test "generate raises GenerationError on failure" do
      orchestrator = create_orchestrator

      Ai::OpenaiQueue.stub :request, ->(*) { raise StandardError, "API failure" } do
        # Should raise GenerationError when AI reasoning fails and fallback also fails
        orchestrator.stub :create_fallback_plan, ->(_state) { raise StandardError, "Fallback failed" } do
          assert_raises(Ai::ContentOrchestrator::GenerationError) do
            orchestrator.generate
          end
        end
      end
    end

    test "generate uses fallback plan when AI reasoning fails" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API error" } do
        results = orchestrator.generate

        # Should complete using fallback plan
        assert_equal "completed", results[:status]
      end
    end

    test "generate sets completed status on success" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      mock_plan = {
        analysis: "Test",
        target_cities: [],
        tourist_profiles_to_generate: [],
        estimated_new_content: { locations: 0, experiences: 0, plans: 0 }
      }

      Ai::OpenaiQueue.stub :request, mock_plan do
        orchestrator.generate

        assert_equal "completed", Setting.get("ai.generation.status")
      end
    end

    # ═══════════════════════════════════════════════════════════
    # analyze_and_plan METHOD TESTS (via AI mocking)
    # ═══════════════════════════════════════════════════════════

    test "analyze_and_plan returns AI response when successful" do
      orchestrator = create_orchestrator

      mock_response = {
        analysis: "AI generated analysis",
        target_cities: [{ city: "Sarajevo", country: "BiH", coordinates: { lat: 43.8, lng: 18.4 }, locations_to_fetch: 10, categories: [], reasoning: "Test" }],
        tourist_profiles_to_generate: ["family"],
        estimated_new_content: { locations: 10, experiences: 5, plans: 3 }
      }

      Ai::OpenaiQueue.stub :request, mock_response do
        result = orchestrator.send(:analyze_and_plan)

        assert_equal "AI generated analysis", result[:analysis]
        assert_equal 1, result[:target_cities].length
      end
    end

    test "analyze_and_plan uses fallback when AI returns nil" do
      orchestrator = create_orchestrator

      Ai::OpenaiQueue.stub :request, nil do
        result = orchestrator.send(:analyze_and_plan)

        assert_equal "Fallback plan - using default configuration", result[:analysis]
      end
    end

    test "analyze_and_plan uses fallback on API error" do
      orchestrator = create_orchestrator

      Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "Error" } do
        result = orchestrator.send(:analyze_and_plan)

        assert_equal "Fallback plan - using default configuration", result[:analysis]
      end
    end

    # ═══════════════════════════════════════════════════════════
    # fetch_locations METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "fetch_locations returns empty array for empty categories" do
      orchestrator = create_orchestrator
      city_plan = { city: "Test", categories: [], coordinates: nil, locations_to_fetch: 10 }

      result = orchestrator.send(:fetch_locations, city_plan)

      assert_equal [], result
    end

    test "fetch_locations uses default categories when not provided" do
      orchestrator = create_orchestrator
      city_plan = { city: "Sarajevo", categories: nil, coordinates: { lat: 43.8, lng: 18.4 }, locations_to_fetch: 5 }

      mock_geoapify = OpenStruct.new
      mock_geoapify.define_singleton_method(:search_nearby) { |**_args| [] }

      Ai::RateLimiter.stub :with_geoapify_limit, ->(items, &block) { block.call(items) } do
        orchestrator.instance_variable_set(:@geoapify, mock_geoapify)
        result = orchestrator.send(:fetch_locations, city_plan)
        # Will be empty because mock returns empty, but we're testing categories handling
        assert_kind_of Array, result
      end
    end

    test "fetch_locations filters by country" do
      orchestrator = create_orchestrator
      city_plan = {
        city: "Sarajevo",
        categories: ["tourism.attraction"],
        coordinates: { lat: 43.8, lng: 18.4 },
        locations_to_fetch: 10
      }

      places = [
        { place_id: "1", name: "Place in BiH", address: "Sarajevo, Bosnia", lat: 43.8, lng: 18.4 },
        { place_id: "2", name: "Place in Croatia", address: "Zagreb, Croatia", lat: 45.8, lng: 15.9 }
      ]

      mock_geoapify = OpenStruct.new
      mock_geoapify.define_singleton_method(:search_nearby) { |**_args| places }

      RateLimiter.stub :with_geoapify_limit, ->(items, &block) { block.call(items) } do
        orchestrator.instance_variable_set(:@geoapify, mock_geoapify)
        result = orchestrator.send(:fetch_locations, city_plan)

        # Only the BiH place should be included
        assert_equal 1, result.length
        assert_equal "Place in BiH", result.first[:name]
      end
    end

    test "fetch_locations handles Geoapify API errors gracefully" do
      orchestrator = create_orchestrator
      city_plan = {
        city: "Sarajevo",
        categories: ["tourism.attraction"],
        coordinates: { lat: 43.8, lng: 18.4 },
        locations_to_fetch: 10
      }

      mock_geoapify = OpenStruct.new
      mock_geoapify.define_singleton_method(:search_nearby) { |**_args| raise GeoapifyService::ApiError, "API Error" }

      RateLimiter.stub :with_geoapify_limit, ->(items, &block) { block.call(items) } do
        orchestrator.instance_variable_set(:@geoapify, mock_geoapify)
        result = orchestrator.send(:fetch_locations, city_plan)

        # Should return empty array, not raise error
        assert_equal [], result
      end
    end

    test "fetch_locations deduplicates by place_id" do
      orchestrator = create_orchestrator
      city_plan = {
        city: "Sarajevo",
        categories: ["tourism.attraction", "heritage"],
        coordinates: { lat: 43.8, lng: 18.4 },
        locations_to_fetch: 10
      }

      # Same place returned by multiple category searches
      places = [
        { place_id: "same_id", name: "Duplicate Place", address: "Sarajevo, BiH", lat: 43.8, lng: 18.4 }
      ]

      mock_geoapify = OpenStruct.new
      mock_geoapify.define_singleton_method(:search_nearby) { |**_args| places }

      RateLimiter.stub :with_geoapify_limit, ->(items, &block) { items.each { |i| block.call([i]) } } do
        orchestrator.instance_variable_set(:@geoapify, mock_geoapify)
        result = orchestrator.send(:fetch_locations, city_plan)

        # Should only have one entry despite appearing in multiple categories
        assert_equal 1, result.length
      end
    end

    # ═══════════════════════════════════════════════════════════
    # enrich_and_save_locations METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "enrich_and_save_locations returns empty array when limit reached" do
      orchestrator = create_orchestrator(max_locations: 5)
      results = orchestrator.instance_variable_get(:@results)
      results[:locations_created] = 5

      result = orchestrator.send(:enrich_and_save_locations, [], "Sarajevo")

      assert_equal [], result
    end

    test "enrich_and_save_locations skips places without name" do
      orchestrator = create_orchestrator
      places = [{ name: "", lat: 43.8, lng: 18.4 }]

      mock_enricher = OpenStruct.new
      mock_enricher.define_singleton_method(:create_and_enrich) { |_place, **_opts| nil }

      Ai::LocationEnricher.stub :new, mock_enricher do
        result = orchestrator.send(:enrich_and_save_locations, places, "Sarajevo")
        assert_equal [], result
      end
    end

    test "enrich_and_save_locations skips places without lat" do
      orchestrator = create_orchestrator
      places = [{ name: "Test", lat: nil, lng: 18.4 }]

      mock_enricher = OpenStruct.new
      mock_enricher.define_singleton_method(:create_and_enrich) { |_place, **_opts| nil }

      Ai::LocationEnricher.stub :new, mock_enricher do
        result = orchestrator.send(:enrich_and_save_locations, places, "Sarajevo")
        assert_equal [], result
      end
    end

    test "enrich_and_save_locations increments locations_created counter" do
      orchestrator = create_orchestrator
      places = [{ name: "Test Place", lat: 43.8, lng: 18.4 }]

      mock_location = OpenStruct.new(id: 1, name: "Test Place")
      mock_enricher = OpenStruct.new
      mock_enricher.define_singleton_method(:create_and_enrich) { |_place, **_opts| mock_location }

      Ai::LocationEnricher.stub :new, mock_enricher do
        orchestrator.send(:enrich_and_save_locations, places, "Sarajevo")

        results = orchestrator.instance_variable_get(:@results)
        assert_equal 1, results[:locations_created]
      end
    end

    test "enrich_and_save_locations stops when limit reached during processing" do
      orchestrator = create_orchestrator(max_locations: 2)
      places = [
        { name: "Place 1", lat: 43.8, lng: 18.4 },
        { name: "Place 2", lat: 43.9, lng: 18.5 },
        { name: "Place 3", lat: 44.0, lng: 18.6 }
      ]

      call_count = 0
      mock_enricher = OpenStruct.new
      mock_enricher.define_singleton_method(:create_and_enrich) do |_place, **_opts|
        call_count += 1
        OpenStruct.new(id: call_count, name: "Location #{call_count}")
      end

      Ai::LocationEnricher.stub :new, mock_enricher do
        result = orchestrator.send(:enrich_and_save_locations, places, "Sarajevo")

        # Should stop after 2 locations (the limit)
        assert_equal 2, result.length
      end
    end

    # ═══════════════════════════════════════════════════════════
    # create_local_experiences METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "create_local_experiences returns empty array when limit reached" do
      orchestrator = create_orchestrator(max_experiences: 5)
      results = orchestrator.instance_variable_get(:@results)
      results[:experiences_created] = 5

      result = orchestrator.send(:create_local_experiences, "Sarajevo")

      assert_equal [], result
    end

    test "create_local_experiences passes remaining slots to ExperienceCreator" do
      orchestrator = create_orchestrator(max_experiences: 10)
      results = orchestrator.instance_variable_get(:@results)
      results[:experiences_created] = 3

      received_max = nil
      mock_creator_class = Class.new do
        define_method(:initialize) { |max_experiences: nil| received_max = max_experiences }
        define_method(:create_local_experiences) { |city:| [] }
      end

      Ai::ExperienceCreator.stub :new, ->(max_experiences: nil) { mock_creator_class.new(max_experiences: max_experiences) } do
        orchestrator.send(:create_local_experiences, "Sarajevo")
        assert_equal 7, received_max
      end
    end

    # ═══════════════════════════════════════════════════════════
    # create_city_plans METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "create_city_plans returns empty array when limit reached" do
      orchestrator = create_orchestrator(max_plans: 3)
      results = orchestrator.instance_variable_get(:@results)
      results[:plans_created] = 3

      result = orchestrator.send(:create_city_plans, "Sarajevo", ["family"])

      assert_equal [], result
    end

    test "create_city_plans creates plans for each profile" do
      orchestrator = create_orchestrator
      profiles = ["family", "couple"]

      created_profiles = []
      mock_creator = OpenStruct.new
      mock_creator.define_singleton_method(:create_for_profile) do |profile:, city:|
        created_profiles << profile
        OpenStruct.new(id: created_profiles.length)
      end

      Ai::PlanCreator.stub :new, mock_creator do
        orchestrator.send(:create_city_plans, "Sarajevo", profiles)
        assert_equal profiles, created_profiles
      end
    end

    test "create_city_plans creates plan for each profile" do
      # Note: create_city_plans doesn't increment plan counter internally -
      # that's done by process_city. This test verifies all profiles get processed.
      orchestrator = create_orchestrator
      profiles = ["family", "couple", "adventure"]

      created_count = 0
      mock_creator = OpenStruct.new
      mock_creator.define_singleton_method(:create_for_profile) do |profile:, city:|
        created_count += 1
        OpenStruct.new(id: created_count)
      end

      Ai::PlanCreator.stub :new, mock_creator do
        result = orchestrator.send(:create_city_plans, "Sarajevo", profiles)
        # All profiles should be processed
        assert_equal 3, result.length
      end
    end

    # ═══════════════════════════════════════════════════════════
    # create_cross_city_experiences METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "create_cross_city_experiences skips when skip_experiences is true" do
      orchestrator = create_orchestrator(skip_experiences: true)

      # Should not call ExperienceCreator at all
      Ai::ExperienceCreator.stub :new, ->(*) { raise "Should not be called" } do
        orchestrator.send(:create_cross_city_experiences)
      end
    end

    test "create_cross_city_experiences skips when limit reached" do
      orchestrator = create_orchestrator(max_experiences: 5)
      results = orchestrator.instance_variable_get(:@results)
      results[:experiences_created] = 5

      # Should not call ExperienceCreator when limit reached
      Ai::ExperienceCreator.stub :new, ->(*) { raise "Should not be called" } do
        orchestrator.send(:create_cross_city_experiences)
      end
    end

    test "create_cross_city_experiences increments experiences_created counter" do
      orchestrator = create_orchestrator

      mock_experiences = [OpenStruct.new(id: 1), OpenStruct.new(id: 2)]
      mock_creator = OpenStruct.new
      mock_creator.define_singleton_method(:create_thematic_experiences) { mock_experiences }

      Ai::ExperienceCreator.stub :new, ->(**_args) { mock_creator } do
        orchestrator.send(:create_cross_city_experiences)

        results = orchestrator.instance_variable_get(:@results)
        assert_equal 2, results[:experiences_created]
      end
    end

    # ═══════════════════════════════════════════════════════════
    # create_multi_city_plans METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "create_multi_city_plans returns empty when skip_plans is true" do
      orchestrator = create_orchestrator(skip_plans: true)

      result = orchestrator.send(:create_multi_city_plans, ["family"])

      assert_equal [], result
    end

    test "create_multi_city_plans returns empty when limit reached" do
      orchestrator = create_orchestrator(max_plans: 3)
      results = orchestrator.instance_variable_get(:@results)
      results[:plans_created] = 3

      result = orchestrator.send(:create_multi_city_plans, ["family"])

      assert_equal [], result
    end

    test "create_multi_city_plans only uses first 3 profiles" do
      orchestrator = create_orchestrator
      profiles = ["family", "couple", "adventure", "nature", "culture"]

      created_profiles = []
      mock_creator = OpenStruct.new
      mock_creator.define_singleton_method(:create_for_profile) do |profile:, city:|
        created_profiles << profile
        OpenStruct.new(id: created_profiles.length)
      end

      Ai::PlanCreator.stub :new, mock_creator do
        orchestrator.send(:create_multi_city_plans, profiles)
        assert_equal 3, created_profiles.length
      end
    end

    test "create_multi_city_plans passes nil city for multi-city plans" do
      orchestrator = create_orchestrator

      received_city = "not_nil"
      mock_creator = OpenStruct.new
      mock_creator.define_singleton_method(:create_for_profile) do |profile:, city:|
        received_city = city
        OpenStruct.new(id: 1)
      end

      Ai::PlanCreator.stub :new, mock_creator do
        orchestrator.send(:create_multi_city_plans, ["family"])
        assert_nil received_city
      end
    end

    # ═══════════════════════════════════════════════════════════
    # process_city METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "process_city handles errors gracefully" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      city_plan = { city: "ErrorCity", categories: [] }
      profiles = []

      # Simulate an error in one of the processing steps
      orchestrator.stub :create_local_experiences, ->(_city) { raise StandardError, "Test error" } do
        # Set skip_experiences to false to trigger the error
        orchestrator.instance_variable_set(:@skip_experiences, false)

        # Should not raise, should log error
        orchestrator.send(:process_city, city_plan, profiles)

        results = orchestrator.instance_variable_get(:@results)
        assert results[:errors].any? { |e| e[:city] == "ErrorCity" }
      end
    end

    test "process_city tracks city results" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      city_plan = { city: "TestCity", categories: [] }

      orchestrator.send(:process_city, city_plan, [])

      results = orchestrator.instance_variable_get(:@results)
      assert results[:cities_processed].any? { |c| c[:city] == "TestCity" }
    end

    # ═══════════════════════════════════════════════════════════
    # execute_plan METHOD TESTS
    # ═══════════════════════════════════════════════════════════

    test "execute_plan processes each target city" do
      orchestrator = create_orchestrator(
        skip_locations: true,
        skip_experiences: true,
        skip_plans: true
      )

      plan = {
        target_cities: [
          { city: "City1", categories: [] },
          { city: "City2", categories: [] }
        ],
        tourist_profiles_to_generate: []
      }

      processed_cities = []
      orchestrator.stub :process_city, ->(city_plan, profiles) { processed_cities << city_plan[:city] } do
        orchestrator.stub :create_cross_city_experiences, nil do
          orchestrator.stub :create_multi_city_plans, ->(_profiles) { [] } do
            orchestrator.send(:execute_plan, plan)
          end
        end
      end

      assert_equal ["City1", "City2"], processed_cities
    end

    test "execute_plan checks cancellation between cities" do
      orchestrator = create_orchestrator

      plan = {
        target_cities: [
          { city: "City1", categories: [] },
          { city: "City2", categories: [] }
        ],
        tourist_profiles_to_generate: []
      }

      call_count = 0
      orchestrator.stub :process_city, ->(city_plan, profiles) {
        call_count += 1
        Ai::ContentOrchestrator.cancel_generation! if call_count == 1
      } do
        assert_raises(Ai::ContentOrchestrator::CancellationError) do
          orchestrator.send(:execute_plan, plan)
        end
      end

      # Should have processed first city before cancellation was detected
      assert_equal 1, call_count
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: cultural_context TESTS
    # ═══════════════════════════════════════════════════════════

    test "cultural_context returns ExperienceGenerator constant" do
      orchestrator = create_orchestrator
      context = orchestrator.send(:cultural_context)

      assert_equal Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT, context
    end

    # ═══════════════════════════════════════════════════════════
    # PRIVATE METHOD: build_reasoning_prompt TESTS
    # ═══════════════════════════════════════════════════════════

    test "build_reasoning_prompt includes target country" do
      orchestrator = create_orchestrator
      state = {
        target_country: "Bosnia and Herzegovina",
        target_country_code: "ba",
        existing_cities: [],
        locations_per_city: {},
        experiences_per_city: {},
        plans_per_city: {},
        max_experiences: nil
      }

      prompt = orchestrator.send(:build_reasoning_prompt, state)

      assert_includes prompt, "Bosnia and Herzegovina"
      assert_includes prompt, "ba"
    end

    test "build_reasoning_prompt includes existing cities" do
      orchestrator = create_orchestrator
      state = {
        target_country: "BiH",
        target_country_code: "ba",
        existing_cities: ["Sarajevo", "Mostar"],
        locations_per_city: { "Sarajevo" => 10, "Mostar" => 5 },
        experiences_per_city: {},
        plans_per_city: {},
        max_experiences: nil
      }

      prompt = orchestrator.send(:build_reasoning_prompt, state)

      assert_includes prompt, "Sarajevo"
      assert_includes prompt, "Mostar"
    end

    test "build_reasoning_prompt includes max_experiences when set" do
      orchestrator = create_orchestrator(max_experiences: 50)
      state = {
        target_country: "BiH",
        target_country_code: "ba",
        existing_cities: [],
        locations_per_city: {},
        experiences_per_city: {},
        plans_per_city: {},
        max_experiences: 50
      }

      prompt = orchestrator.send(:build_reasoning_prompt, state)

      assert_includes prompt, "Maximum experiences to create: 50"
    end

    test "build_reasoning_prompt includes Geoapify categories" do
      orchestrator = create_orchestrator
      state = {
        target_country: "BiH",
        target_country_code: "ba",
        existing_cities: [],
        locations_per_city: {},
        experiences_per_city: {},
        plans_per_city: {},
        max_experiences: nil
      }

      prompt = orchestrator.send(:build_reasoning_prompt, state)

      assert_includes prompt, "tourism.attraction"
      assert_includes prompt, "catering.restaurant"
      assert_includes prompt, "heritage.unesco"
    end

    private

    # Helper to create an orchestrator with GeoapifyService stubbed
    def create_orchestrator(**options)
      mock_geoapify = OpenStruct.new
      mock_geoapify.define_singleton_method(:search_nearby) { |**_args| [] }
      mock_geoapify.define_singleton_method(:text_search) { |**_args| [] }

      orchestrator = nil
      GeoapifyService.stub :new, mock_geoapify do
        orchestrator = Ai::ContentOrchestrator.new(**options)
      end
      # Replace the @geoapify instance variable with the mock
      orchestrator.instance_variable_set(:@geoapify, mock_geoapify)
      orchestrator
    end

    # Helper to create a mock geoapify for manual injection
    def mock_geoapify
      mock = OpenStruct.new
      mock.define_singleton_method(:search_nearby) { |**_args| [] }
      mock.define_singleton_method(:text_search) { |**_args| [] }
      mock
    end
  end
end
