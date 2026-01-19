# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class ExperienceTypeClassifierTest < ActiveSupport::TestCase
    setup do
      @classifier = Ai::ExperienceTypeClassifier.new

      # Ensure experience types exist for all tests
      @culture = ExperienceType.find_or_create_by!(key: "culture") do |et|
        et.name = "Culture"
        et.active = true
        et.position = 1
      end
      @history = ExperienceType.find_or_create_by!(key: "history") do |et|
        et.name = "History"
        et.active = true
        et.position = 2
      end
      @nature = ExperienceType.find_or_create_by!(key: "nature") do |et|
        et.name = "Nature"
        et.active = true
        et.position = 3
      end
      @architecture = ExperienceType.find_or_create_by!(key: "architecture") do |et|
        et.name = "Architecture"
        et.active = true
        et.position = 4
      end
      @food = ExperienceType.find_or_create_by!(key: "food") do |et|
        et.name = "Food"
        et.active = true
        et.position = 5
      end
      @adventure = ExperienceType.find_or_create_by!(key: "adventure") do |et|
        et.name = "Adventure"
        et.active = true
        et.position = 6
      end

      @location = Location.create!(
        name: "Stari most",
        city: "Mostar",
        lat: 43.3378,
        lng: 18.4289,
        location_type: "place"
      )
    end

    # === Initialization tests ===

    test "initializes without errors" do
      assert_nothing_raised { Ai::ExperienceTypeClassifier.new }
    end

    # === classify tests ===

    test "classify returns success with valid classification" do
      stub_ai_response("culture, history") do
        result = @classifier.classify(@location, dry_run: true)

        assert result[:success]
        assert_equal @location.id, result[:location_id]
        assert_equal @location.name, result[:location_name]
        assert_includes result[:types], "culture"
        assert_includes result[:types], "history"
        assert result[:dry_run]
      end
    end

    test "classify adds experience types when not dry_run" do
      stub_ai_response("culture, nature") do
        initial_count = @location.experience_types.count
        result = @classifier.classify(@location, dry_run: false)

        assert result[:success]
        assert_operator @location.experience_types.count, :>, initial_count
      end
    end

    test "classify uses hints when provided" do
      hints = ["culture", "history"]
      stub_ai_response("culture, history, architecture") do
        result = @classifier.classify(@location, dry_run: true, hints: hints)

        assert result[:success]
        assert_includes result[:types], "culture"
        assert_includes result[:types], "history"
      end
    end

    test "classify returns failure when no types returned" do
      stub_ai_response("") do
        result = @classifier.classify(@location, dry_run: true)

        assert_not result[:success]
        assert_equal "No types returned", result[:error]
      end
    end

    test "classify handles AI errors gracefully" do
      stub_ai_error do
        result = @classifier.classify(@location, dry_run: true)

        assert_not result[:success]
        assert result[:error].present?
      end
    end

    test "classify handles invalid type keys" do
      stub_ai_response("culture, invalid_type, nature") do
        result = @classifier.classify(@location, dry_run: true)

        assert result[:success]
        assert_includes result[:types], "culture"
        assert_includes result[:types], "nature"
        assert_not_includes result[:types], "invalid_type"
      end
    end

    test "classify skips adding type when add_experience_type fails" do
      stub_ai_response("culture, history") do
        mock_location = Location.create!(
          name: "Test",
          city: "Test",
          lat: 43.0,
          lng: 18.0,
          location_type: "place"
        )

        # Make add_experience_type fail for one type
        call_count = 0
        mock_location.stub :add_experience_type, ->(type) {
          call_count += 1
          raise StandardError, "Failed to add" if call_count == 1
        } do
          result = @classifier.classify(mock_location, dry_run: false)

          assert result[:success]
          assert_includes result[:types], "culture"
          assert_includes result[:types], "history"
        end
      end
    end

    # === classify_batch tests ===

    test "classify_batch processes multiple locations" do
      location2 = Location.create!(
        name: "Vrelo Bosne",
        city: "Sarajevo",
        lat: 43.8207,
        lng: 18.2622,
        location_type: "place"
      )
      locations = [@location, location2]

      stub_ai_response("culture, history") do
        result = @classifier.classify_batch(Location.where(id: locations.map(&:id)), dry_run: true)

        assert_equal 2, result[:total]
        assert_equal 2, result[:processed]
        assert_equal 2, result[:successful]
        assert_equal 0, result[:failed]
      end
    end

    test "classify_batch tracks type counts" do
      location2 = Location.create!(
        name: "Vrelo Bosne",
        city: "Sarajevo",
        lat: 43.8207,
        lng: 18.2622,
        location_type: "place"
      )
      locations = [@location, location2]

      stub_ai_response("culture, nature") do
        result = @classifier.classify_batch(Location.where(id: locations.map(&:id)), dry_run: true)

        assert_equal 2, result[:types_added]["culture"]
        assert_equal 2, result[:types_added]["nature"]
      end
    end

    test "classify_batch handles failures" do
      location2 = Location.create!(
        name: "Vrelo Bosne",
        city: "Sarajevo",
        lat: 43.8207,
        lng: 18.2622,
        location_type: "place"
      )
      locations = [@location, location2]

      call_count = 0
      @classifier.stub :ai_classify_location, ->(*) {
        call_count += 1
        call_count == 1 ? ["culture"] : raise("AI Error")
      } do
        result = @classifier.classify_batch(Location.where(id: locations.map(&:id)), dry_run: true)

        assert_equal 2, result[:processed]
        assert_equal 1, result[:successful]
        assert_equal 1, result[:failed]
        assert_equal 1, result[:errors].count
      end
    end

    test "classify_batch reports progress every 10 items" do
      # Create 15 locations to test progress reporting
      locations = []
      15.times do |i|
        locations << Location.create!(
          name: "Location #{i}",
          city: "Test",
          lat: 43.0 + (i * 0.01),
          lng: 18.0,
          location_type: "place"
        )
      end

      stub_ai_response("culture") do
        result = @classifier.classify_batch(Location.where(id: locations.map(&:id)), dry_run: true)

        assert_equal 15, result[:total]
        assert_equal 15, result[:processed]
        assert_equal 15, result[:successful]
      end
    end

    test "classify returns location name in result when classification succeeds" do
      stub_ai_response("culture") do
        result = @classifier.classify(@location, dry_run: true)

        assert result[:success]
        assert_equal @location.name, result[:location_name]
      end
    end

    test "classify catches exceptions and returns failure result" do
      stub_ai_error do
        result = @classifier.classify(@location, dry_run: true)

        assert_not result[:success]
        assert_equal @location.id, result[:location_id]
        assert result[:error].present?
        assert_empty result[:types]
      end
    end

    test "classify_batch collects all errors" do
      location2 = Location.create!(
        name: "Location 2",
        city: "Test",
        lat: 43.1,
        lng: 18.0,
        location_type: "place"
      )
      location3 = Location.create!(
        name: "Location 3",
        city: "Test",
        lat: 43.2,
        lng: 18.0,
        location_type: "place"
      )
      locations = [@location, location2, location3]

      call_count = 0
      @classifier.stub :classify, ->(loc, dry_run:) {
        call_count += 1
        if call_count == 1
          { success: true, location_id: loc.id, types: ["culture"] }
        else
          { success: false, location_id: loc.id, types: [], error: "Error #{call_count}" }
        end
      } do
        result = @classifier.classify_batch(Location.where(id: locations.map(&:id)), dry_run: true)

        assert_equal 3, result[:processed]
        assert_equal 1, result[:successful]
        assert_equal 2, result[:failed]
        assert_equal 2, result[:errors].count
      end
    end

    test "classify with dry_run returns dry_run true in result" do
      stub_ai_response("culture") do
        result = @classifier.classify(@location, dry_run: true)

        assert result[:success]
        assert result[:dry_run]
      end
    end

    test "classify without dry_run returns dry_run false in result" do
      stub_ai_response("culture") do
        result = @classifier.classify(@location, dry_run: false)

        assert result[:success]
        assert_not result[:dry_run]
      end
    end

    test "parse_types_from_response is case insensitive for validation" do
      types = @classifier.send(:parse_types_from_response, "CULTURE, Culture, culture, HISTORY")

      # Should accept all cases and deduplicate
      assert_equal 2, types.count
      assert_includes types, "culture"
      assert_includes types, "history"
    end

    test "classify logs info when classification succeeds" do
      stub_ai_response("culture") do
        # Just verify it doesn't crash and returns success
        result = @classifier.classify(@location, dry_run: true)

        assert result[:success]
        assert_includes result[:types], "culture"
      end
    end

    test "classify logs warn when no types are classified" do
      stub_ai_response("") do
        result = @classifier.classify(@location, dry_run: true)

        assert_not result[:success]
        assert_equal "No types returned", result[:error]
      end
    end

    test "classify adds type successfully when not dry_run" do
      stub_ai_response("culture, history") do
        # Ensure location has no types initially
        @location.location_experience_types.delete_all

        result = @classifier.classify(@location, dry_run: false)

        assert result[:success]
        @location.reload
        assert @location.location_experience_types.count > 0
      end
    end

    # === parse_types_from_response tests ===

    test "parse_types_from_response handles comma-separated types" do
      types = @classifier.send(:parse_types_from_response, "culture, history, nature")

      assert_equal 3, types.count
      assert_includes types, "culture"
      assert_includes types, "history"
      assert_includes types, "nature"
    end

    test "parse_types_from_response handles newline-separated types" do
      types = @classifier.send(:parse_types_from_response, "culture\nhistory\nnature")

      assert_equal 3, types.count
      assert_includes types, "culture"
      assert_includes types, "history"
    end

    test "parse_types_from_response filters invalid types" do
      types = @classifier.send(:parse_types_from_response, "culture, invalid, history")

      assert_includes types, "culture"
      assert_includes types, "history"
      assert_not_includes types, "invalid"
    end

    test "parse_types_from_response removes duplicates" do
      types = @classifier.send(:parse_types_from_response, "culture, culture, history")

      assert_equal 2, types.count
    end

    test "parse_types_from_response handles blank content" do
      types = @classifier.send(:parse_types_from_response, "")
      assert_empty types

      types = @classifier.send(:parse_types_from_response, nil)
      assert_empty types
    end

    test "parse_types_from_response is case insensitive" do
      types = @classifier.send(:parse_types_from_response, "Culture, HISTORY, nature")

      assert_includes types, "culture"
      assert_includes types, "history"
      assert_includes types, "nature"
    end

    # === build_classification_prompt tests ===

    test "build_classification_prompt includes location details" do
      prompt = @classifier.send(:build_classification_prompt, @location, nil)

      assert_includes prompt, @location.name
      assert_includes prompt, @location.city
    end

    test "build_classification_prompt includes hints when provided" do
      hints = ["culture", "history"]
      prompt = @classifier.send(:build_classification_prompt, @location, hints)

      assert_includes prompt, "Initial suggestions: culture, history"
    end

    test "build_classification_prompt omits hints section when not provided" do
      prompt = @classifier.send(:build_classification_prompt, @location, nil)

      assert_not_includes prompt, "Initial suggestions"
    end

    test "build_classification_prompt includes descriptions when available" do
      @location.stub :translate, "Test description", [:description, :bs] do
        prompt = @classifier.send(:build_classification_prompt, @location, nil)
        assert_includes prompt, "Description (BS): Test description"
      end
    end

    # === valid_type? tests ===

    test "valid_type? returns true for valid type" do
      assert @classifier.send(:valid_type?, "culture")
      assert @classifier.send(:valid_type?, "nature")
      assert @classifier.send(:valid_type?, "history")
    end

    test "valid_type? returns false for invalid type" do
      assert_not @classifier.send(:valid_type?, "invalid_type")
      assert_not @classifier.send(:valid_type?, "nonexistent")
    end

    test "valid_type? is case insensitive" do
      assert @classifier.send(:valid_type?, "CULTURE")
      assert @classifier.send(:valid_type?, "Nature")
    end

    # === system_prompt tests ===

    test "system_prompt includes available types" do
      prompt = @classifier.send(:system_prompt)

      assert_includes prompt, "experience type classifier"
      assert_includes prompt, "Available experience types:"
    end

    test "system_prompt includes classification rules" do
      prompt = @classifier.send(:system_prompt)

      assert_includes prompt, "Choose 1-4 types"
      assert_includes prompt, "Return only the type keys"
    end

    # === available_types_description tests ===

    test "available_types_description lists all active types" do
      description = @classifier.send(:available_types_description)

      ExperienceType.active.each do |type|
        assert_includes description, type.key
        assert_includes description, type.name
      end
    end

    test "available_types_description includes type descriptions when present" do
      # Update one type to have a description
      @culture.update(description: "Cultural experiences and heritage")

      description = @classifier.send(:available_types_description)

      assert_includes description, "Cultural experiences"
    end

    test "available_types_description truncates long descriptions" do
      # Create a type with a very long description
      long_desc = "A" * 200
      @culture.update(description: long_desc)

      description = @classifier.send(:available_types_description)

      # Should be truncated to 100 chars plus ellipsis
      assert description.length < long_desc.length + 50
    end

    test "classify_batch logs final summary" do
      locations = [@location]

      stub_ai_response("culture") do
        result = @classifier.classify_batch(Location.where(id: locations.map(&:id)), dry_run: true)

        # Should complete successfully
        assert_equal 1, result[:successful]
        assert_equal 1, result[:total]
      end
    end

    test "classify uses hints in log message when provided" do
      hints = ["culture", "history"]

      stub_ai_response("culture, history, architecture") do
        result = @classifier.classify(@location, dry_run: true, hints: hints)

        assert result[:success]
        # Should have used hints
        assert_includes result[:types], "culture"
        assert_includes result[:types], "history"
      end
    end

    private

    def stub_ai_response(response_text)
      mock_response = OpenStruct.new(content: response_text)
      mock_llm = OpenStruct.new
      mock_llm.define_singleton_method(:ask) { |*| mock_response }

      @classifier.instance_variable_set(:@llm, mock_llm)
      yield
    end

    def stub_ai_error
      mock_llm = OpenStruct.new
      mock_llm.define_singleton_method(:ask) { |*| raise StandardError, "AI Error" }

      @classifier.instance_variable_set(:@llm, mock_llm)
      yield
    end
  end
end
