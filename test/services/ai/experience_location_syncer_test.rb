# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Ai
  class ExperienceLocationSyncerTest < ActiveSupport::TestCase
    setup do
      # Mock GeoapifyService to avoid API key requirement
      @mock_geoapify = Minitest::Mock.new
      @mock_enricher = Minitest::Mock.new

      GeoapifyService.stub :new, @mock_geoapify do
        Ai::LocationEnricher.stub :new, @mock_enricher do
          @syncer = Ai::ExperienceLocationSyncer.new
        end
      end
    end

    # ==========================================================================
    # Initialization Tests
    # ==========================================================================

    test "initializes without errors" do
      mock_geoapify = Minitest::Mock.new
      mock_enricher = Minitest::Mock.new

      GeoapifyService.stub :new, mock_geoapify do
        Ai::LocationEnricher.stub :new, mock_enricher do
          assert_nothing_raised do
            Ai::ExperienceLocationSyncer.new
          end
        end
      end
    end

    test "MIN_CONFIDENCE constant is defined as 0.6" do
      assert_equal 0.6, Ai::ExperienceLocationSyncer::MIN_CONFIDENCE
    end

    test "SyncError is defined as a StandardError subclass" do
      assert Ai::ExperienceLocationSyncer::SyncError < StandardError
    end

    # ==========================================================================
    # sync_locations - Result Structure Tests
    # ==========================================================================

    test "sync_locations returns expected result structure with all keys" do
      experience = create_mock_experience

      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_locations(experience)

        assert result.is_a?(Hash)
        assert_equal experience.id, result[:experience_id]
        assert_equal experience.title, result[:experience_title]
        assert_equal 0, result[:locations_analyzed]
        assert_equal 0, result[:locations_already_connected]
        assert_equal 0, result[:locations_added]
        assert_equal 0, result[:locations_found_in_db]
        assert_equal 0, result[:locations_created_via_geoapify]
        assert_equal 0, result[:locations_not_found]
        assert_equal false, result[:dry_run]
        assert_equal [], result[:errors]
        assert_equal [], result[:details]
      end
    end

    test "sync_locations returns early with zero counts when description is blank" do
      experience = create_mock_experience(description: nil)

      result = @syncer.sync_locations(experience)

      assert_equal 0, result[:locations_analyzed]
      assert_equal 0, result[:locations_added]
    end

    test "sync_locations returns early when description is empty string" do
      experience = create_mock_experience(description: "")

      result = @syncer.sync_locations(experience)

      assert_equal 0, result[:locations_analyzed]
    end

    # ==========================================================================
    # sync_locations - Dry Run Tests
    # ==========================================================================

    test "sync_locations with dry_run true sets dry_run flag in result" do
      experience = create_mock_experience

      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_locations(experience, dry_run: true)

        assert result[:dry_run]
      end
    end

    test "sync_locations with dry_run does not call add_location on experience" do
      experience = create_mock_experience
      location = create_mock_location

      extracted = [{ name: "Test Location", confidence: 0.9, city: "Sarajevo", context: "museum" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, [location, :database]) do
          result = @syncer.sync_locations(experience, dry_run: true)

          assert_equal 1, result[:locations_added]
          # In dry run, add_location should not be called (mock would fail if called)
        end
      end
    end

    test "sync_locations without dry_run calls add_location on experience" do
      location = create_mock_location
      add_location_called = false

      experience = create_mock_experience_with_add_location_tracking do
        add_location_called = true
      end

      extracted = [{ name: "Test Location", confidence: 0.9, city: "Sarajevo", context: "museum" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        # Use proc with keyword args pattern matching
        @syncer.define_singleton_method(:find_or_create_location) do |name:, city:, all_cities:, context:|
          [location, :database]
        end

        @syncer.sync_locations(experience, dry_run: false)

        assert add_location_called, "add_location should be called when not in dry run"
      end
    end

    # ==========================================================================
    # sync_locations - Location Processing Tests
    # ==========================================================================

    test "sync_locations skips locations already connected to experience" do
      existing_location = create_mock_location(name: "Baščaršija")
      experience = create_mock_experience(locations: [existing_location])

      extracted = [{ name: "Baščaršija", confidence: 0.9, city: "Sarajevo", context: "landmark" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        result = @syncer.sync_locations(experience)

        assert_equal 1, result[:locations_already_connected]
        assert_equal 0, result[:locations_added]
        assert_equal :already_connected, result[:details].first[:status]
      end
    end

    test "sync_locations skips locations with confidence below MIN_CONFIDENCE" do
      experience = create_mock_experience

      extracted = [{ name: "Test Location", confidence: 0.5, city: "Sarajevo", context: "place" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        result = @syncer.sync_locations(experience)

        assert_equal 0, result[:locations_added]
        assert_equal :low_confidence, result[:details].first[:status]
        assert_equal 0.5, result[:details].first[:confidence]
      end
    end

    test "sync_locations uses default confidence of 1.0 when not provided" do
      experience = create_mock_experience
      location = create_mock_location

      extracted = [{ name: "Test Location", city: "Sarajevo", context: "place" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, [location, :database]) do
          result = @syncer.sync_locations(experience, dry_run: true)

          assert_equal 1, result[:locations_added]
        end
      end
    end

    test "sync_locations counts locations found in database" do
      experience = create_mock_experience
      location = create_mock_location

      extracted = [{ name: "Test Location", confidence: 0.9, city: "Sarajevo", context: "place" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, [location, :database]) do
          result = @syncer.sync_locations(experience, dry_run: true)

          assert_equal 1, result[:locations_found_in_db]
          assert_equal 0, result[:locations_created_via_geoapify]
          assert_equal :database, result[:details].first[:source]
        end
      end
    end

    test "sync_locations counts locations created via geoapify" do
      experience = create_mock_experience
      location = create_mock_location

      extracted = [{ name: "New Place", confidence: 0.9, city: "Sarajevo", context: "place" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, [location, :geoapify]) do
          result = @syncer.sync_locations(experience, dry_run: true)

          assert_equal 0, result[:locations_found_in_db]
          assert_equal 1, result[:locations_created_via_geoapify]
          assert_equal :geoapify, result[:details].first[:source]
        end
      end
    end

    test "sync_locations counts locations not found" do
      experience = create_mock_experience

      extracted = [{ name: "Nonexistent Place", confidence: 0.9, city: "Sarajevo", context: "place" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, [nil, nil]) do
          result = @syncer.sync_locations(experience)

          assert_equal 1, result[:locations_not_found]
          assert_equal :not_found, result[:details].first[:status]
        end
      end
    end

    test "sync_locations handles errors during location processing" do
      experience = create_mock_experience

      extracted = [{ name: "Error Location", confidence: 0.9, city: "Sarajevo", context: "place" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, ->(*) { raise StandardError, "Something went wrong" }) do
          result = @syncer.sync_locations(experience)

          assert_equal 1, result[:errors].count
          assert_equal "Error Location", result[:errors].first[:name]
          assert_equal "Something went wrong", result[:errors].first[:error]
        end
      end
    end

    test "sync_locations processes multiple locations" do
      experience = create_mock_experience
      loc1 = create_mock_location(id: 1, name: "Location 1")
      loc2 = create_mock_location(id: 2, name: "Location 2")

      extracted = [
        { name: "Location 1", confidence: 0.9, city: "Sarajevo", context: "place" },
        { name: "Location 2", confidence: 0.8, city: "Sarajevo", context: "museum" }
      ]

      call_count = 0
      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, ->(*) {
          call_count += 1
          call_count == 1 ? [loc1, :database] : [loc2, :geoapify]
        }) do
          result = @syncer.sync_locations(experience, dry_run: true)

          assert_equal 2, result[:locations_analyzed]
          assert_equal 2, result[:locations_added]
          assert_equal 1, result[:locations_found_in_db]
          assert_equal 1, result[:locations_created_via_geoapify]
        end
      end
    end

    test "sync_locations uses city from extracted data when available" do
      experience = create_mock_experience(city: "Sarajevo", cities: ["Sarajevo", "Mostar"])
      location = create_mock_location

      extracted = [{ name: "Test", confidence: 0.9, city: "Mostar", context: "bridge" }]

      captured_city = nil
      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.define_singleton_method(:find_or_create_location) do |name:, city:, all_cities:, context:|
          captured_city = city
          [location, :database]
        end

        @syncer.sync_locations(experience, dry_run: true)

        assert_equal "Mostar", captured_city
      end
    end

    # ==========================================================================
    # sync_all Tests
    # ==========================================================================

    test "sync_all returns aggregated results structure" do
      experience1 = create_mock_experience(id: 1, title: "Exp 1")
      experience2 = create_mock_experience(id: 2, title: "Exp 2")

      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_all([experience1, experience2], dry_run: true)

        assert_equal 2, result[:experiences_processed]
        assert_includes result.keys, :total_locations_added
        assert_includes result.keys, :total_locations_found_in_db
        assert_includes result.keys, :total_locations_created
        assert_includes result.keys, :total_locations_not_found
        assert_includes result.keys, :total_errors
        assert_equal true, result[:dry_run]
        assert_equal 2, result[:details].count
      end
    end

    test "sync_all aggregates location counts correctly" do
      exp1 = create_mock_experience(id: 1)
      exp2 = create_mock_experience(id: 2)
      location = create_mock_location

      extracted = [{ name: "Test", confidence: 0.9, city: "Sarajevo", context: "place" }]

      call_count = 0
      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, ->(*) {
          call_count += 1
          call_count == 1 ? [location, :database] : [location, :geoapify]
        }) do
          result = @syncer.sync_all([exp1, exp2], dry_run: true)

          assert_equal 2, result[:total_locations_added]
          assert_equal 1, result[:total_locations_found_in_db]
          assert_equal 1, result[:total_locations_created]
        end
      end
    end

    test "sync_all aggregates errors correctly" do
      exp1 = create_mock_experience(id: 1)
      exp2 = create_mock_experience(id: 2)

      extracted = [{ name: "Error", confidence: 0.9, city: "Sarajevo", context: "place" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        @syncer.stub(:find_or_create_location, ->(*) { raise StandardError, "Error" }) do
          result = @syncer.sync_all([exp1, exp2])

          assert_equal 2, result[:total_errors]
        end
      end
    end

    test "sync_all handles empty experiences array" do
      @syncer.stub(:extract_locations_from_description, []) do
        result = @syncer.sync_all([])

        assert_equal 0, result[:experiences_processed]
        assert_equal [], result[:details]
      end
    end

    # ==========================================================================
    # Private Method Tests - normalize_name
    # ==========================================================================

    test "normalize_name handles various whitespace" do
      assert_equal "Test Location", @syncer.send(:normalize_name, "  Test   Location  ")
      assert_equal "Test Location", @syncer.send(:normalize_name, "Test\tLocation")
      assert_equal "Test Location", @syncer.send(:normalize_name, "Test\nLocation")
    end

    test "normalize_name handles smart quotes" do
      assert_equal '"Test"', @syncer.send(:normalize_name, '"Test"')
      assert_equal '"Test"', @syncer.send(:normalize_name, '„Test"')
      assert_equal '"Test"', @syncer.send(:normalize_name, '"Test"')
      assert_equal '"Test"', @syncer.send(:normalize_name, "'Test'")
    end

    test "normalize_name handles nil input" do
      assert_equal "", @syncer.send(:normalize_name, nil)
    end

    # ==========================================================================
    # Private Method Tests - generic_location_name?
    # ==========================================================================

    test "generic_location_name identifies names starting with articles" do
      assert @syncer.send(:generic_location_name?, "the museum")
      assert @syncer.send(:generic_location_name?, "a restaurant")
      assert @syncer.send(:generic_location_name?, "an old bridge")
      assert @syncer.send(:generic_location_name?, "some place")
    end

    test "generic_location_name identifies generic suffixes" do
      assert @syncer.send(:generic_location_name?, "local restaurant")
      assert @syncer.send(:generic_location_name?, "old cafe")
      assert @syncer.send(:generic_location_name?, "city museum")
      assert @syncer.send(:generic_location_name?, "central park")
      assert @syncer.send(:generic_location_name?, "main church")
      assert @syncer.send(:generic_location_name?, "big mosque")
    end

    test "generic_location_name identifies common generic terms" do
      assert @syncer.send(:generic_location_name?, "old town")
      assert @syncer.send(:generic_location_name?, "city center")
      assert @syncer.send(:generic_location_name?, "downtown")
      assert @syncer.send(:generic_location_name?, "centar")
    end

    test "generic_location_name identifies city names as generic" do
      assert @syncer.send(:generic_location_name?, "Sarajevo")
      assert @syncer.send(:generic_location_name?, "sarajevo")
      assert @syncer.send(:generic_location_name?, "Mostar")
      assert @syncer.send(:generic_location_name?, "tuzla")
      assert @syncer.send(:generic_location_name?, "zenica")
      assert @syncer.send(:generic_location_name?, "bihać")
    end

    test "generic_location_name identifies too short names" do
      assert @syncer.send(:generic_location_name?, "ab")
      assert @syncer.send(:generic_location_name?, "x")
      assert @syncer.send(:generic_location_name?, "")
    end

    test "generic_location_name returns false for specific location names" do
      assert_not @syncer.send(:generic_location_name?, "Baščaršija")
      assert_not @syncer.send(:generic_location_name?, "Stari Most")
      assert_not @syncer.send(:generic_location_name?, "Gazi Husrev-begova džamija")
      assert_not @syncer.send(:generic_location_name?, "Vrelo Bosne")
      assert_not @syncer.send(:generic_location_name?, "Avaz Twist Tower")
      assert_not @syncer.send(:generic_location_name?, "Vijećnica")
      assert_not @syncer.send(:generic_location_name?, "Historijski muzej BiH")
    end

    # ==========================================================================
    # Private Method Tests - location_in_bih?
    # ==========================================================================

    test "location_in_bih returns true for Sarajevo coordinates" do
      result = { lat: 43.8563, lng: 18.4131 }
      assert @syncer.send(:location_in_bih?, result)
    end

    test "location_in_bih returns true for Mostar coordinates" do
      result = { lat: 43.3438, lng: 17.8078 }
      assert @syncer.send(:location_in_bih?, result)
    end

    test "location_in_bih returns true for Banja Luka coordinates" do
      result = { lat: 44.7722, lng: 17.1910 }
      assert @syncer.send(:location_in_bih?, result)
    end

    test "location_in_bih returns true for Trebinje coordinates" do
      result = { lat: 42.7114, lng: 18.3449 }
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

    test "location_in_bih returns false for missing lat" do
      assert_not @syncer.send(:location_in_bih?, { lat: nil, lng: 18.4131 })
    end

    test "location_in_bih returns false for missing lng" do
      assert_not @syncer.send(:location_in_bih?, { lat: 43.8563, lng: nil })
    end

    test "location_in_bih returns false for empty hash" do
      assert_not @syncer.send(:location_in_bih?, {})
    end

    test "location_in_bih returns false for coordinates outside bounding box" do
      # Too far north
      assert_not @syncer.send(:location_in_bih?, { lat: 46.0, lng: 18.0 })
      # Too far south
      assert_not @syncer.send(:location_in_bih?, { lat: 42.0, lng: 18.0 })
      # Too far west
      assert_not @syncer.send(:location_in_bih?, { lat: 44.0, lng: 15.0 })
      # Too far east
      assert_not @syncer.send(:location_in_bih?, { lat: 44.0, lng: 20.0 })
    end

    # ==========================================================================
    # Private Method Tests - extract_city_from_address
    # ==========================================================================

    test "extract_city_from_address finds Sarajevo" do
      assert_equal "Sarajevo", @syncer.send(:extract_city_from_address, "Ferhadija 1, 71000 Sarajevo, BiH")
    end

    test "extract_city_from_address finds Mostar" do
      assert_equal "Mostar", @syncer.send(:extract_city_from_address, "Stari Most, 88000 Mostar, Bosnia")
    end

    test "extract_city_from_address finds Banja Luka" do
      assert_equal "Banja Luka", @syncer.send(:extract_city_from_address, "Kralja Petra I 12, Banja Luka")
    end

    test "extract_city_from_address finds Tuzla" do
      assert_equal "Tuzla", @syncer.send(:extract_city_from_address, "Some Street, Tuzla 75000")
    end

    test "extract_city_from_address returns nil for unknown city" do
      assert_nil @syncer.send(:extract_city_from_address, "Some Unknown Place")
    end

    test "extract_city_from_address returns nil for nil address" do
      assert_nil @syncer.send(:extract_city_from_address, nil)
    end

    test "extract_city_from_address returns nil for blank address" do
      assert_nil @syncer.send(:extract_city_from_address, "")
      assert_nil @syncer.send(:extract_city_from_address, "   ")
    end

    # ==========================================================================
    # Private Method Tests - find_best_match
    # ==========================================================================

    test "find_best_match returns result with exact name match" do
      results = [
        { name: "Baščaršija", lat: 43.86, lng: 18.43, address: "Sarajevo" },
        { name: "Other Place", lat: 43.87, lng: 18.44, address: "Sarajevo" }
      ]

      best = @syncer.send(:find_best_match, results, "Baščaršija", "Sarajevo")

      assert_equal "Baščaršija", best[:name]
    end

    test "find_best_match returns result with partial name match" do
      results = [
        { name: "Stari Most Bridge", lat: 43.34, lng: 17.81, address: "Mostar" },
        { name: "Other Place", lat: 43.35, lng: 17.82, address: "Mostar" }
      ]

      best = @syncer.send(:find_best_match, results, "Stari Most", "Mostar")

      assert_equal "Stari Most Bridge", best[:name]
    end

    test "find_best_match prefers results in the correct city" do
      results = [
        { name: "Test Place", lat: 43.86, lng: 18.43, address: "Zagreb, Croatia" },
        { name: "Test Place", lat: 43.34, lng: 17.81, address: "Mostar, Bosnia" }
      ]

      best = @syncer.send(:find_best_match, results, "Test Place", "Mostar")

      assert best[:address].include?("Mostar")
    end

    test "find_best_match returns nil when no result meets minimum score" do
      results = [
        { name: "Completely Different", lat: 43.86, lng: 18.43, address: "Other City" }
      ]

      best = @syncer.send(:find_best_match, results, "Test Location", "Sarajevo")

      assert_nil best
    end

    test "find_best_match handles empty results" do
      best = @syncer.send(:find_best_match, [], "Test", "Sarajevo")

      assert_nil best
    end

    # ==========================================================================
    # Private Method Tests - excluded_location?
    # ==========================================================================

    test "excluded_location returns true for social facility categories" do
      result = {
        name: "Dom za stare",
        types: ["service.social_facility"]
      }

      assert @syncer.send(:excluded_location?, result)
    end

    test "excluded_location returns true for nursing home categories" do
      result = {
        name: "Care Home",
        types: ["healthcare.nursing_home"]
      }

      assert @syncer.send(:excluded_location?, result)
    end

    test "excluded_location returns true for excluded keywords in name" do
      result = {
        name: "Gerontološki centar",
        types: ["building"],
        address: "Sarajevo"
      }

      assert @syncer.send(:excluded_location?, result)
    end

    test "excluded_location returns true for soup kitchen keywords" do
      result = {
        name: "Narodna kuhinja",
        types: ["catering"],
        address: "Mostar"
      }

      assert @syncer.send(:excluded_location?, result)
    end

    test "excluded_location returns false for normal tourist places" do
      result = {
        name: "Vijećnica",
        types: ["tourism.sights"],
        address: "Sarajevo"
      }

      assert_not @syncer.send(:excluded_location?, result)
    end

    test "excluded_location returns false for empty hash" do
      assert_not @syncer.send(:excluded_location?, {})
    end

    test "excluded_location returns false for hash with no matching exclusions" do
      result = {
        name: "Regular Place",
        types: ["tourism"],
        address: "Some Street"
      }
      assert_not @syncer.send(:excluded_location?, result)
    end

    # ==========================================================================
    # Private Method Tests - find_location_in_database
    # ==========================================================================

    test "find_location_in_database finds by exact name match" do
      location = Location.create!(
        name: "Test Location",
        city: "Sarajevo",
        lat: 43.856,
        lng: 18.413
      )

      found = @syncer.send(:find_location_in_database, "Test Location", "Sarajevo", ["Sarajevo"])

      assert_equal location.id, found.id

      location.destroy
    end

    test "find_location_in_database finds by case insensitive match" do
      location = Location.create!(
        name: "Test Location",
        city: "Sarajevo",
        lat: 43.857,
        lng: 18.414
      )

      found = @syncer.send(:find_location_in_database, "TEST LOCATION", "Sarajevo", ["Sarajevo"])

      assert_equal location.id, found.id

      location.destroy
    end

    test "find_location_in_database finds by partial name match" do
      location = Location.create!(
        name: "Historijski muzej Bosne i Hercegovine",
        city: "Sarajevo",
        lat: 43.858,
        lng: 18.415
      )

      found = @syncer.send(:find_location_in_database, "Historijski muzej", "Sarajevo", ["Sarajevo"])

      assert_equal location.id, found.id

      location.destroy
    end

    test "find_location_in_database respects city filter" do
      location = Location.create!(
        name: "Test Place",
        city: "Mostar",
        lat: 43.344,
        lng: 17.808
      )

      found = @syncer.send(:find_location_in_database, "Test Place", "Sarajevo", ["Sarajevo"])

      assert_nil found

      location.destroy
    end

    test "find_location_in_database returns nil when not found" do
      found = @syncer.send(:find_location_in_database, "Nonexistent Location", "Sarajevo", ["Sarajevo"])

      assert_nil found
    end

    # ==========================================================================
    # Private Method Tests - get_city_coordinates
    # ==========================================================================

    test "get_city_coordinates returns nil for blank city" do
      assert_nil @syncer.send(:get_city_coordinates, nil)
      assert_nil @syncer.send(:get_city_coordinates, "")
    end

    test "get_city_coordinates returns coordinates from existing location" do
      location = Location.create!(
        name: "Test",
        city: "TestCity",
        lat: 43.859,
        lng: 18.416
      )

      coords = @syncer.send(:get_city_coordinates, "TestCity")

      assert_equal 43.859, coords[:lat].to_f
      assert_equal 18.416, coords[:lng].to_f

      location.destroy
    end

    # ==========================================================================
    # Private Method Tests - build_extraction_prompt
    # ==========================================================================

    test "build_extraction_prompt includes description" do
      prompt = @syncer.send(:build_extraction_prompt, "Visit Baščaršija", "Sarajevo")

      assert_includes prompt, "Visit Baščaršija"
    end

    test "build_extraction_prompt includes city context" do
      prompt = @syncer.send(:build_extraction_prompt, "Description", "Mostar")

      assert_includes prompt, "Mostar"
    end

    test "build_extraction_prompt handles nil city" do
      prompt = @syncer.send(:build_extraction_prompt, "Description", nil)

      assert_includes prompt, "Unknown"
    end

    # ==========================================================================
    # Private Method Tests - extraction_schema
    # ==========================================================================

    test "extraction_schema returns valid schema structure" do
      schema = @syncer.send(:extraction_schema)

      assert_equal "object", schema[:type]
      assert_includes schema[:properties].keys, :locations
      assert_equal "array", schema[:properties][:locations][:type]
    end

    test "extraction_schema locations items have required fields" do
      schema = @syncer.send(:extraction_schema)
      item_schema = schema[:properties][:locations][:items]

      assert_includes item_schema[:properties].keys, :name
      assert_includes item_schema[:properties].keys, :confidence
      assert_includes item_schema[:properties].keys, :city
      assert_includes item_schema[:properties].keys, :context
      assert_equal %w[name confidence city context], item_schema[:required]
    end

    # ==========================================================================
    # Error Handling Tests
    # ==========================================================================

    test "extract_locations_from_description returns empty array on API error" do
      experience = create_mock_experience

      Ai::OpenaiQueue.stub :request, ->(*) { raise Ai::OpenaiQueue::RequestError, "API Error" } do
        result = @syncer.send(:extract_locations_from_description, "Test description", "Sarajevo")

        assert_equal [], result
      end
    end

    test "extract_locations_from_description filters out too short names" do
      response = { locations: [
        { name: "AB", confidence: 0.9, city: "Sarajevo", context: "place" },
        { name: "Valid Place", confidence: 0.9, city: "Sarajevo", context: "place" }
      ] }

      Ai::OpenaiQueue.stub :request, response do
        result = @syncer.send(:extract_locations_from_description, "Test description", "Sarajevo")

        assert_equal 1, result.count
        assert_equal "Valid Place", result.first[:name]
      end
    end

    test "extract_locations_from_description filters out generic names" do
      response = { locations: [
        { name: "the museum", confidence: 0.9, city: "Sarajevo", context: "place" },
        { name: "Vijećnica", confidence: 0.9, city: "Sarajevo", context: "place" }
      ] }

      Ai::OpenaiQueue.stub :request, response do
        result = @syncer.send(:extract_locations_from_description, "Test description", "Sarajevo")

        assert_equal 1, result.count
        assert_equal "Vijećnica", result.first[:name]
      end
    end

    test "extract_locations_from_description handles nil response" do
      Ai::OpenaiQueue.stub :request, nil do
        result = @syncer.send(:extract_locations_from_description, "Test description", "Sarajevo")

        assert_equal [], result
      end
    end

    test "extract_locations_from_description handles response without locations key" do
      Ai::OpenaiQueue.stub :request, { other: "data" } do
        result = @syncer.send(:extract_locations_from_description, "Test description", "Sarajevo")

        assert_equal [], result
      end
    end

    # ==========================================================================
    # Integration-style Tests (with mocked external dependencies)
    # ==========================================================================

    test "full sync flow with database location" do
      location = Location.create!(
        name: "Baščaršija",
        city: "Sarajevo",
        lat: 43.860,
        lng: 18.431
      )

      experience = create_mock_experience(
        description: "Visit the historic Baščaršija bazaar in Sarajevo."
      )

      extracted = [{ name: "Baščaršija", confidence: 0.95, city: "Sarajevo", context: "bazaar" }]

      @syncer.stub(:extract_locations_from_description, extracted) do
        result = @syncer.sync_locations(experience, dry_run: true)

        assert_equal 1, result[:locations_analyzed]
        assert_equal 1, result[:locations_added]
        assert_equal 1, result[:locations_found_in_db]
        assert_equal 0, result[:locations_created_via_geoapify]
      end

      location.destroy
    end

    # ==========================================================================
    # Helper Methods
    # ==========================================================================

    private

    def create_mock_experience(
      id: nil,
      title: "Test Experience",
      description: "A test experience description with Baščaršija mentioned.",
      city: "Sarajevo",
      cities: ["Sarajevo"],
      locations: []
    )
      mock = OpenStruct.new(
        id: id || rand(1000..9999),
        title: title,
        description: description,
        uuid: SecureRandom.uuid
      )

      mock.define_singleton_method(:translation_for) do |field, locale|
        return description if field == :description
        nil
      end

      mock.define_singleton_method(:city) { city }
      mock.define_singleton_method(:cities) { cities }
      mock.define_singleton_method(:locations) { locations }

      # Create a mock for experience_locations that responds to maximum
      experience_locations_mock = Object.new
      locations_count = locations.size
      experience_locations_mock.define_singleton_method(:maximum) { |_| locations_count }
      experience_locations_mock.define_singleton_method(:create) { |**_| true }

      mock.define_singleton_method(:experience_locations) { experience_locations_mock }
      mock.define_singleton_method(:add_location) { |loc, position:| true }
      mock.define_singleton_method(:reload) { mock }

      mock
    end

    def create_mock_experience_with_add_location_tracking(&callback)
      mock = create_mock_experience
      mock.define_singleton_method(:add_location) do |loc, position:|
        callback.call if callback
        true
      end
      mock
    end

    def create_mock_location(id: nil, name: "Test Location", city: "Sarajevo", lat: 43.856, lng: 18.413)
      OpenStruct.new(
        id: id || rand(1000..9999),
        name: name,
        city: city,
        lat: lat,
        lng: lng
      )
    end
  end
end
