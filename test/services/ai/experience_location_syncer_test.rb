# frozen_string_literal: true

require "test_helper"

module Ai
  class ExperienceLocationSyncerTest < ActiveSupport::TestCase
    setup do
      @syncer = Ai::ExperienceLocationSyncer.new
    end

    # === Basic initialization tests ===

    test "initializes without errors" do
      assert_nothing_raised do
        Ai::ExperienceLocationSyncer.new
      end
    end

    test "MIN_CONFIDENCE is defined" do
      assert_equal 0.6, Ai::ExperienceLocationSyncer::MIN_CONFIDENCE
    end

    # === sync_locations result structure tests ===

    test "sync_locations returns expected result structure" do
      experience = experiences(:one) rescue Experience.first
      skip "No experiences available for testing" unless experience

      # Mock the AI response to avoid actual API calls
      mock_result = {
        experience_id: experience.id,
        experience_title: experience.title,
        locations_analyzed: 0,
        locations_already_connected: 0,
        locations_added: 0,
        locations_found_in_db: 0,
        locations_created_via_geoapify: 0,
        locations_not_found: 0,
        dry_run: false,
        errors: [],
        details: []
      }

      # Stub the AI extraction to return empty array (no API call)
      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_locations(experience)

        assert result.is_a?(Hash)
        assert_includes result.keys, :experience_id
        assert_includes result.keys, :locations_analyzed
        assert_includes result.keys, :locations_added
        assert_includes result.keys, :locations_found_in_db
        assert_includes result.keys, :locations_created_via_geoapify
        assert_includes result.keys, :errors
      end
    end

    test "sync_locations with dry_run does not modify database" do
      experience = experiences(:one) rescue Experience.first
      skip "No experiences available for testing" unless experience

      initial_location_count = experience.locations.count

      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_locations(experience, dry_run: true)

        assert result[:dry_run]
        assert_equal initial_location_count, experience.reload.locations.count
      end
    end

    test "sync_locations handles experience without description" do
      experience = Experience.new(title: "Test Experience")
      experience.save(validate: false)

      result = @syncer.sync_locations(experience)

      assert_equal 0, result[:locations_analyzed]
      assert_equal 0, result[:locations_added]

      experience.destroy
    end

    # === Helper method tests ===

    test "generic location names are correctly identified" do
      generic_names = [
        "the museum",
        "a restaurant",
        "cafe",
        "old town",
        "city center",
        "Sarajevo", # Just a city name
        "ab" # Too short
      ]

      generic_names.each do |name|
        assert @syncer.send(:generic_location_name?, name),
               "Expected '#{name}' to be identified as generic"
      end
    end

    test "specific location names are not identified as generic" do
      specific_names = [
        "Baščaršija",
        "Stari Most",
        "Gazi Husrev-begova džamija",
        "Vrelo Bosne",
        "Avaz Twist Tower",
        "Vijećnica"
      ]

      specific_names.each do |name|
        assert_not @syncer.send(:generic_location_name?, name),
                   "Expected '#{name}' to NOT be identified as generic"
      end
    end

    test "normalize_name handles various whitespace" do
      assert_equal "Test Location", @syncer.send(:normalize_name, "  Test   Location  ")
      assert_equal "Test Location", @syncer.send(:normalize_name, "Test\tLocation")
    end

    test "normalize_name handles smart quotes" do
      assert_equal '"Test"', @syncer.send(:normalize_name, '"Test"')
      assert_equal '"Test"', @syncer.send(:normalize_name, '„Test"')
    end

    # === BiH border validation tests ===

    test "location_in_bih returns true for Sarajevo coordinates" do
      result = { lat: 43.8563, lng: 18.4131 }
      assert @syncer.send(:location_in_bih?, result)
    end

    test "location_in_bih returns true for Mostar coordinates" do
      result = { lat: 43.3438, lng: 17.8078 }
      assert @syncer.send(:location_in_bih?, result)
    end

    test "location_in_bih returns false for Zagreb coordinates" do
      result = { lat: 45.8150, lng: 15.9819 }
      assert_not @syncer.send(:location_in_bih?, result)
    end

    test "location_in_bih returns false for Belgrade coordinates" do
      result = { lat: 44.7866, lng: 20.4489 }
      assert_not @syncer.send(:location_in_bih?, result)
    end

    test "location_in_bih returns false for missing coordinates" do
      assert_not @syncer.send(:location_in_bih?, { lat: nil, lng: 18.4131 })
      assert_not @syncer.send(:location_in_bih?, { lat: 43.8563, lng: nil })
      assert_not @syncer.send(:location_in_bih?, {})
    end

    # === City extraction tests ===

    test "extract_city_from_address finds Sarajevo" do
      assert_equal "Sarajevo", @syncer.send(:extract_city_from_address, "Ferhadija 1, 71000 Sarajevo, BiH")
    end

    test "extract_city_from_address finds Mostar" do
      assert_equal "Mostar", @syncer.send(:extract_city_from_address, "Stari Most, 88000 Mostar, Bosnia")
    end

    test "extract_city_from_address returns nil for unknown city" do
      assert_nil @syncer.send(:extract_city_from_address, "Some Unknown Place")
    end

    test "extract_city_from_address returns nil for blank address" do
      assert_nil @syncer.send(:extract_city_from_address, nil)
      assert_nil @syncer.send(:extract_city_from_address, "")
    end

    # === sync_all tests ===

    test "sync_all processes multiple experiences" do
      experiences = Experience.limit(2).to_a
      skip "Not enough experiences for testing" if experiences.count < 2

      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_all(experiences, dry_run: true)

        assert_equal 2, result[:experiences_processed]
        assert result[:details].is_a?(Array)
        assert_equal 2, result[:details].count
      end
    end

    test "sync_all aggregates results correctly" do
      experiences = Experience.limit(1).to_a
      skip "No experiences for testing" if experiences.empty?

      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_all(experiences, dry_run: true)

        assert_includes result.keys, :experiences_processed
        assert_includes result.keys, :total_locations_added
        assert_includes result.keys, :total_locations_found_in_db
        assert_includes result.keys, :total_locations_created
        assert_includes result.keys, :total_locations_not_found
        assert_includes result.keys, :total_errors
      end
    end
  end
end
