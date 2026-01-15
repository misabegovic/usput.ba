# frozen_string_literal: true

require "test_helper"
require "ostruct"

class LocationCityFixJobTest < ActiveJob::TestCase
  # === Setup and teardown ===

  setup do
    LocationCityFixJob.clear_status!
  end

  teardown do
    LocationCityFixJob.clear_status!
  end

  # === Queue configuration tests ===

  test "job is queued in default queue" do
    assert_equal "default", LocationCityFixJob.new.queue_name
  end

  test "job is enqueued with parameters" do
    assert_enqueued_with(
      job: LocationCityFixJob,
      args: [{ regenerate_content: true, dry_run: false }]
    ) do
      LocationCityFixJob.perform_later(regenerate_content: true, dry_run: false)
    end
  end

  test "job is enqueued with all parameters" do
    assert_enqueued_with(
      job: LocationCityFixJob,
      args: [{
        regenerate_content: true,
        analyze_descriptions: true,
        remove_soup_kitchens: false,
        remove_medical_facilities: false,
        remove_city_mismatches: false,
        remove_outside_bih: false,
        dry_run: true,
        clear_cache: true
      }]
    ) do
      LocationCityFixJob.perform_later(
        regenerate_content: true,
        analyze_descriptions: true,
        remove_soup_kitchens: false,
        remove_medical_facilities: false,
        remove_city_mismatches: false,
        remove_outside_bih: false,
        dry_run: true,
        clear_cache: true
      )
    end
  end

  # === Rate limit constants tests ===

  test "GEOAPIFY_SLEEP is defined as 0.2 seconds" do
    assert_equal 0.2, LocationCityFixJob::GEOAPIFY_SLEEP
  end

  test "NOMINATIM_SLEEP is defined as 1.1 seconds" do
    assert_equal 1.1, LocationCityFixJob::NOMINATIM_SLEEP
  end

  test "GEOAPIFY_SLEEP is faster than NOMINATIM_SLEEP" do
    assert LocationCityFixJob::GEOAPIFY_SLEEP < LocationCityFixJob::NOMINATIM_SLEEP
  end

  # === BiH bounds constants tests ===

  test "BIH_BOUNDS is defined with correct keys" do
    bounds = LocationCityFixJob::BIH_BOUNDS

    assert bounds.is_a?(Hash)
    assert_includes bounds.keys, :min_lat
    assert_includes bounds.keys, :max_lat
    assert_includes bounds.keys, :min_lng
    assert_includes bounds.keys, :max_lng
  end

  test "BIH_BOUNDS has reasonable coordinate values" do
    bounds = LocationCityFixJob::BIH_BOUNDS

    assert bounds[:min_lat] < bounds[:max_lat], "min_lat should be less than max_lat"
    assert bounds[:min_lng] < bounds[:max_lng], "min_lng should be less than max_lng"
    assert bounds[:min_lat] > 40, "BiH is north of 40 degrees latitude"
    assert bounds[:max_lat] < 50, "BiH is south of 50 degrees latitude"
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = LocationCityFixJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = LocationCityFixJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "current_status returns idle status by default" do
    status = LocationCityFixJob.current_status

    assert_equal "idle", status[:status]
  end

  test "current_status handles JSON parse errors gracefully" do
    Setting.set("location_fix.results", "invalid json {{{")

    status = LocationCityFixJob.current_status

    assert status.is_a?(Hash)
    assert_equal "idle", status[:status]
  end

  test "clear_status! resets status to idle" do
    Setting.set("location_fix.status", "in_progress")
    Setting.set("location_fix.message", "Working...")

    LocationCityFixJob.clear_status!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
    assert_includes [nil, ""], status[:message]
  end

  test "force_reset_city_fix! resets stuck job" do
    Setting.set("location_fix.status", "in_progress")

    LocationCityFixJob.force_reset_city_fix!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
    assert_equal "Force reset by admin", status[:message]
  end

  # === Soup kitchen keywords tests ===

  test "SOUP_KITCHEN_KEYWORDS is defined and contains expected keywords" do
    keywords = LocationCityFixJob::SOUP_KITCHEN_KEYWORDS

    assert keywords.is_a?(Array)
    assert_includes keywords, "soup kitchen"
    assert_includes keywords, "narodna kuhinja"
    assert_includes keywords, "pučka kuhinja"
    assert_includes keywords, "food bank"
    assert_includes keywords, "banka hrane"
  end

  test "SOUP_KITCHEN_KEYWORDS contains Bosnian/Croatian variants" do
    keywords = LocationCityFixJob::SOUP_KITCHEN_KEYWORDS

    assert_includes keywords, "javna kuhinja"
    assert_includes keywords, "socijalna kuhinja"
    assert_includes keywords, "besplatna hrana"
    assert_includes keywords, "socijalni centar"
  end

  test "SOUP_KITCHEN_KEYWORDS is frozen" do
    assert LocationCityFixJob::SOUP_KITCHEN_KEYWORDS.frozen?
  end

  # === Medical facility keywords tests ===

  test "MEDICAL_FACILITY_KEYWORDS is defined and contains expected keywords" do
    keywords = LocationCityFixJob::MEDICAL_FACILITY_KEYWORDS

    assert keywords.is_a?(Array)
    assert_includes keywords, "red cross"
    assert_includes keywords, "crveni krst"
    assert_includes keywords, "crveni križ"
    assert_includes keywords, "hospital"
    assert_includes keywords, "bolnica"
  end

  test "MEDICAL_FACILITY_KEYWORDS contains Bosnian/Croatian variants" do
    keywords = LocationCityFixJob::MEDICAL_FACILITY_KEYWORDS

    assert_includes keywords, "klinika"
    assert_includes keywords, "dom zdravlja"
    assert_includes keywords, "zdravstveni centar"
    assert_includes keywords, "hitna pomoć"
    assert_includes keywords, "ambulanta"
  end

  test "MEDICAL_FACILITY_KEYWORDS is frozen" do
    assert LocationCityFixJob::MEDICAL_FACILITY_KEYWORDS.frozen?
  end

  # === Coordinate overrides tests ===

  test "COORDINATE_OVERRIDES is defined and contains Zvornik area" do
    overrides = LocationCityFixJob::COORDINATE_OVERRIDES

    assert overrides.is_a?(Array)
    assert_not_empty overrides

    zvornik_override = overrides.find { |o| o[:city] == "Zvornik" }
    assert_not_nil zvornik_override
    assert zvornik_override[:lat_range].is_a?(Range)
    assert zvornik_override[:lng_range].is_a?(Range)
  end

  test "COORDINATE_OVERRIDES is frozen" do
    assert LocationCityFixJob::COORDINATE_OVERRIDES.frozen?
  end

  # === Soup kitchen detection tests ===

  test "soup_kitchen? returns true for location with soup kitchen in name" do
    job = LocationCityFixJob.new
    location = build_mock_location(name: "Community Soup Kitchen", city: "Sarajevo")

    assert job.send(:soup_kitchen?, location)
    location.verify
  end

  test "soup_kitchen? returns true for location with narodna kuhinja in name" do
    job = LocationCityFixJob.new
    location = build_mock_location(name: "Narodna Kuhinja Centar", city: "Mostar")

    assert job.send(:soup_kitchen?, location)
    location.verify
  end

  test "soup_kitchen? returns true for location with food bank in description" do
    job = LocationCityFixJob.new
    location = build_mock_location(
      name: "Charity Center",
      city: "Sarajevo",
      description_en: "This is a food bank for the community"
    )

    assert job.send(:soup_kitchen?, location)
    location.verify
  end

  test "soup_kitchen? returns false for regular restaurant" do
    job = LocationCityFixJob.new
    location = build_mock_location(
      name: "Restaurant Sarajevo",
      city: "Sarajevo",
      description_en: "A nice restaurant"
    )

    refute job.send(:soup_kitchen?, location)
    location.verify
  end

  test "soup_kitchen? is case insensitive" do
    job = LocationCityFixJob.new
    location = build_mock_location(name: "SOUP KITCHEN CENTER", city: "Tuzla")

    assert job.send(:soup_kitchen?, location)
    location.verify
  end

  # === Medical facility detection tests ===

  test "medical_facility? returns true for location with red cross in name" do
    job = LocationCityFixJob.new
    location = build_mock_location(name: "Red Cross Center", city: "Sarajevo")

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns true for location with crveni krst in name" do
    job = LocationCityFixJob.new
    location = build_mock_location(name: "Crveni Krst Sarajevo", city: "Sarajevo")

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns true for location with hospital in name" do
    job = LocationCityFixJob.new
    location = build_mock_location(name: "General Hospital Mostar", city: "Mostar")

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns true for location with bolnica in name" do
    job = LocationCityFixJob.new
    location = build_mock_location(name: "Opca Bolnica Sarajevo", city: "Sarajevo")

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns true for location with clinic in description" do
    job = LocationCityFixJob.new
    location = build_mock_location(
      name: "Health Center",
      city: "Banja Luka",
      description_en: "This is a medical clinic providing healthcare services"
    )

    assert job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns false for regular restaurant" do
    job = LocationCityFixJob.new
    location = build_mock_location(
      name: "Restaurant Sarajevo",
      city: "Sarajevo",
      description_en: "A nice restaurant"
    )

    refute job.send(:medical_facility?, location)
    location.verify
  end

  test "medical_facility? returns false for historical bridge" do
    job = LocationCityFixJob.new
    location = build_mock_location(
      name: "Stari Most",
      city: "Mostar",
      description_en: "Historic Ottoman bridge"
    )

    refute job.send(:medical_facility?, location)
    location.verify
  end

  # === City mismatch detection tests ===

  test "check_name_city_mismatch returns mismatch when name mentions different city" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(name: "Beautiful View in Blagaj", city: "Mostar")

    result = job.send(:check_name_city_mismatch, location)

    assert result[:mismatch]
    assert_equal "Blagaj", result[:mentioned_city]
  end

  test "check_name_city_mismatch returns no mismatch when name matches city" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(name: "Mostar Old Bridge", city: "Mostar")

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
  end

  test "check_name_city_mismatch returns no mismatch for generic name" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(name: "Beautiful Historic Monument", city: "Sarajevo")

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
  end

  test "check_name_city_mismatch handles nil name" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(name: nil, city: "Sarajevo")

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
  end

  test "check_name_city_mismatch handles nil city" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(name: "Test Location", city: nil)

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
  end

  test "check_name_city_mismatch handles blank values" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(name: "", city: "")

    result = job.send(:check_name_city_mismatch, location)

    refute result[:mismatch]
  end

  test "check_name_city_mismatch detects Sarajevo mismatch" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(name: "Best Restaurant in Sarajevo", city: "Mostar")

    result = job.send(:check_name_city_mismatch, location)

    assert result[:mismatch]
    assert_equal "Sarajevo", result[:mentioned_city]
  end

  # === Cities match/different tests ===

  test "cities_different? returns false for same city names" do
    job = LocationCityFixJob.new
    refute job.send(:cities_different?, "Sarajevo", "Sarajevo")
  end

  test "cities_different? returns true for different city names" do
    job = LocationCityFixJob.new
    assert job.send(:cities_different?, "Sarajevo", "Mostar")
  end

  test "cities_different? handles case differences" do
    job = LocationCityFixJob.new
    refute job.send(:cities_different?, "sarajevo", "SARAJEVO")
  end

  test "cities_different? returns true for blank vs present" do
    job = LocationCityFixJob.new
    assert job.send(:cities_different?, "", "Sarajevo")
    assert job.send(:cities_different?, nil, "Sarajevo")
  end

  test "cities_different? returns false for both blank" do
    job = LocationCityFixJob.new
    refute job.send(:cities_different?, "", "")
    refute job.send(:cities_different?, nil, nil)
  end

  test "cities_different? handles special characters" do
    job = LocationCityFixJob.new
    refute job.send(:cities_different?, "Banja Luka", "Banja Luka")
    refute job.send(:cities_different?, "Bihac", "bihac")
  end

  test "cities_match? returns true for same cities" do
    job = LocationCityFixJob.new
    assert job.send(:cities_match?, "Sarajevo", "sarajevo")
  end

  test "cities_match? returns false for different cities" do
    job = LocationCityFixJob.new
    refute job.send(:cities_match?, "Sarajevo", "Mostar")
  end

  # === Clean city name tests ===

  test "clean_city_name removes Grad prefix" do
    job = LocationCityFixJob.new
    assert_equal "Zvornik", job.send(:clean_city_name, "Grad Zvornik")
    assert_equal "Sarajevo", job.send(:clean_city_name, "Grad Sarajevo")
  end

  test "clean_city_name removes Opcina prefix (Croatian)" do
    job = LocationCityFixJob.new
    assert_equal "Mostar", job.send(:clean_city_name, "Općina Mostar")
  end

  test "clean_city_name removes Opstina prefix (Serbian)" do
    job = LocationCityFixJob.new
    assert_equal "Banja Luka", job.send(:clean_city_name, "Opština Banja Luka")
  end

  test "clean_city_name removes Municipality of prefix" do
    job = LocationCityFixJob.new
    assert_equal "Sarajevo", job.send(:clean_city_name, "Municipality of Sarajevo")
  end

  test "clean_city_name removes City of prefix" do
    job = LocationCityFixJob.new
    assert_equal "Mostar", job.send(:clean_city_name, "City of Mostar")
  end

  test "clean_city_name removes Miasto prefix (Polish)" do
    job = LocationCityFixJob.new
    assert_equal "Test", job.send(:clean_city_name, "Miasto Test")
  end

  test "clean_city_name handles nil" do
    job = LocationCityFixJob.new
    assert_equal "", job.send(:clean_city_name, nil)
  end

  test "clean_city_name strips whitespace" do
    job = LocationCityFixJob.new
    assert_equal "Sarajevo", job.send(:clean_city_name, "  Sarajevo  ")
  end

  # === Outside BiH detection tests ===

  test "outside_bih? returns false for Sarajevo coordinates" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(lat: 43.8563, lng: 18.4131)

    refute job.send(:outside_bih?, location)
  end

  test "outside_bih? returns true for coordinates outside BiH" do
    job = LocationCityFixJob.new
    # Belgrade coordinates
    location = OpenStruct.new(lat: 44.82, lng: 20.45)

    assert job.send(:outside_bih?, location)
  end

  test "outside_bih? returns false for blank coordinates" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(lat: nil, lng: nil)

    refute job.send(:outside_bih?, location)
  end

  test "outside_bih? returns false for blank lat" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(lat: nil, lng: 18.4131)

    refute job.send(:outside_bih?, location)
  end

  test "outside_bih? returns false for blank lng" do
    job = LocationCityFixJob.new
    location = OpenStruct.new(lat: 43.8563, lng: nil)

    refute job.send(:outside_bih?, location)
  end

  # === Coordinate override tests ===

  test "check_coordinate_overrides returns Zvornik for matching coordinates" do
    job = LocationCityFixJob.new

    result = job.send(:check_coordinate_overrides, 44.40, 19.10)
    assert_equal "Zvornik", result
  end

  test "check_coordinate_overrides returns nil for non-matching coordinates" do
    job = LocationCityFixJob.new

    result = job.send(:check_coordinate_overrides, 43.85, 18.41)
    assert_nil result
  end

  test "check_coordinate_overrides handles edge of range" do
    job = LocationCityFixJob.new

    # Test edge of Zvornik override range
    result = job.send(:check_coordinate_overrides, 44.38, 19.08)
    assert_equal "Zvornik", result
  end

  # === get_city_from_coordinates tests ===

  test "get_city_from_coordinates returns override source for Zvornik coordinates" do
    job = LocationCityFixJob.new

    result = job.send(:get_city_from_coordinates, 44.40, 19.10)

    assert_equal "Zvornik", result[:city]
    assert_equal :override, result[:source]
  end

  test "get_city_from_coordinates returns nil for blank coordinates" do
    job = LocationCityFixJob.new

    result = job.send(:get_city_from_coordinates, nil, nil)

    assert_nil result[:city]
    assert_nil result[:source]
  end

  test "get_city_from_coordinates returns nil for empty lat" do
    job = LocationCityFixJob.new

    result = job.send(:get_city_from_coordinates, "", 18.4131)

    assert_nil result[:city]
    assert_nil result[:source]
  end

  test "get_city_from_coordinates returns geoapify source when geoapify succeeds" do
    job = LocationCityFixJob.new

    # Mock GeoapifyService
    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, "Sarajevo", [43.8563, 18.4131]

    GeoapifyService.stub :new, geoapify_mock do
      result = job.send(:get_city_from_coordinates, 43.8563, 18.4131)

      assert_equal "Sarajevo", result[:city]
      assert_equal :geoapify, result[:source]
    end

    geoapify_mock.verify
  end

  test "get_city_from_coordinates falls back to nominatim when geoapify returns nil" do
    job = LocationCityFixJob.new

    # Mock GeoapifyService returning nil
    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, nil, [43.8563, 18.4131]

    # Mock Geocoder (Nominatim)
    geocoder_result = OpenStruct.new(
      city: "Sarajevo",
      data: { "address" => { "city" => "Sarajevo" } }
    )

    GeoapifyService.stub :new, geoapify_mock do
      Geocoder.stub :search, [geocoder_result] do
        job.stub :extract_city_from_result, "Sarajevo" do
          result = job.send(:get_city_from_coordinates, 43.8563, 18.4131)

          assert_equal "Sarajevo", result[:city]
          assert_equal :nominatim, result[:source]
        end
      end
    end

    geoapify_mock.verify
  end

  test "get_city_from_coordinates handles geoapify configuration error" do
    job = LocationCityFixJob.new

    GeoapifyService.stub :new, ->{ raise GeoapifyService::ConfigurationError, "API key not set" } do
      Geocoder.stub :search, [] do
        result = job.send(:get_city_from_coordinates, 43.8563, 18.4131)

        assert_nil result[:city]
        assert_nil result[:source]
      end
    end
  end

  test "get_city_from_coordinates handles geoapify standard error" do
    job = LocationCityFixJob.new

    geoapify_mock = Minitest::Mock.new
    def geoapify_mock.get_city_from_coordinates(lat, lng)
      raise StandardError, "API error"
    end

    GeoapifyService.stub :new, geoapify_mock do
      Geocoder.stub :search, [] do
        result = job.send(:get_city_from_coordinates, 43.8563, 18.4131)

        assert_nil result[:city]
        assert_nil result[:source]
      end
    end
  end

  # === get_city_from_nominatim tests ===

  test "get_city_from_nominatim returns nil for empty results" do
    job = LocationCityFixJob.new

    Geocoder.stub :search, [] do
      result = job.send(:get_city_from_nominatim, 43.8563, 18.4131)
      assert_nil result
    end
  end

  test "get_city_from_nominatim handles geocoder errors gracefully" do
    job = LocationCityFixJob.new

    Geocoder.stub :search, ->(*args) { raise StandardError, "Network error" } do
      result = job.send(:get_city_from_nominatim, 43.8563, 18.4131)
      assert_nil result
    end
  end

  # === extract_city_from_display_name tests ===

  test "extract_city_from_display_name extracts city from typical format" do
    job = LocationCityFixJob.new

    display_name = "Stari Most, Mostar, Herzegovina-Neretva Canton, Bosnia and Herzegovina"
    result = job.send(:extract_city_from_display_name, display_name)

    assert_equal "Mostar", result
  end

  test "extract_city_from_display_name skips postal codes" do
    job = LocationCityFixJob.new

    display_name = "Some Place, 71000, Sarajevo, Bosnia and Herzegovina"
    result = job.send(:extract_city_from_display_name, display_name)

    assert_equal "Sarajevo", result
  end

  test "extract_city_from_display_name skips country names" do
    job = LocationCityFixJob.new

    display_name = "Place, Bosnia and Herzegovina"
    result = job.send(:extract_city_from_display_name, display_name)

    assert_nil result
  end

  test "extract_city_from_display_name skips administrative regions" do
    job = LocationCityFixJob.new

    display_name = "Place, Federacija Bosne i Hercegovine"
    result = job.send(:extract_city_from_display_name, display_name)

    assert_nil result
  end

  test "extract_city_from_display_name returns nil for blank input" do
    job = LocationCityFixJob.new

    result = job.send(:extract_city_from_display_name, nil)
    assert_nil result

    result = job.send(:extract_city_from_display_name, "")
    assert_nil result
  end

  test "extract_city_from_display_name returns nil for single part" do
    job = LocationCityFixJob.new

    result = job.send(:extract_city_from_display_name, "Just One Part")
    assert_nil result
  end

  # === build_completion_summary tests ===

  test "build_completion_summary returns no changes message when nothing changed" do
    job = LocationCityFixJob.new
    results = {
      cities_corrected: 0,
      content_regenerated: 0,
      descriptions_analyzed: 0,
      descriptions_regenerated: 0,
      outside_bih_removed: 0,
      soup_kitchens_removed: 0,
      medical_facilities_removed: 0,
      city_mismatches_removed: 0
    }

    summary = job.send(:build_completion_summary, results)

    assert_equal "Finished: No changes needed", summary
  end

  test "build_completion_summary includes cities corrected" do
    job = LocationCityFixJob.new
    results = {
      cities_corrected: 5,
      content_regenerated: 0,
      descriptions_analyzed: 0,
      descriptions_regenerated: 0,
      outside_bih_removed: 0,
      soup_kitchens_removed: 0,
      medical_facilities_removed: 0,
      city_mismatches_removed: 0
    }

    summary = job.send(:build_completion_summary, results)

    assert_includes summary, "5 cities corrected"
  end

  test "build_completion_summary includes multiple changes" do
    job = LocationCityFixJob.new
    results = {
      cities_corrected: 3,
      content_regenerated: 2,
      descriptions_analyzed: 10,
      descriptions_regenerated: 1,
      outside_bih_removed: 4,
      soup_kitchens_removed: 2,
      medical_facilities_removed: 1,
      city_mismatches_removed: 3
    }

    summary = job.send(:build_completion_summary, results)

    assert_includes summary, "3 cities corrected"
    assert_includes summary, "2 descriptions regenerated (city change)"
    assert_includes summary, "10 analyzed"
    assert_includes summary, "1 descriptions regenerated (quality)"
    assert_includes summary, "4 locations outside BiH removed"
    assert_includes summary, "2 soup kitchens removed"
    assert_includes summary, "1 medical facilities removed"
    assert_includes summary, "3 city mismatches removed"
  end

  # === save_status tests ===

  test "save_status sets status and message" do
    job = LocationCityFixJob.new

    job.send(:save_status, "in_progress", "Processing...")

    assert_equal "in_progress", Setting.get("location_fix.status")
    assert_equal "Processing...", Setting.get("location_fix.message")
  end

  test "save_status saves results when provided" do
    job = LocationCityFixJob.new
    results = { total_checked: 10, cities_corrected: 2 }

    job.send(:save_status, "completed", "Done", results: results)

    saved_results = JSON.parse(Setting.get("location_fix.results"))
    assert_equal 10, saved_results["total_checked"]
    assert_equal 2, saved_results["cities_corrected"]
  end

  # === clear_geocoder_cache! tests ===

  test "clear_geocoder_cache! calls delete_matched when supported" do
    job = LocationCityFixJob.new

    delete_matched_called = false
    cache_mock = Object.new
    cache_mock.define_singleton_method(:respond_to?) do |method, *|
      method == :delete_matched
    end
    cache_mock.define_singleton_method(:delete_matched) do |pattern|
      delete_matched_called = true
      assert_equal "geocoder:*", pattern
      true
    end

    Rails.stub :cache, cache_mock do
      job.send(:clear_geocoder_cache!)
    end

    assert delete_matched_called, "delete_matched should have been called"
  end

  test "clear_geocoder_cache! calls cache.clear when delete_matched not supported" do
    job = LocationCityFixJob.new

    clear_called = false
    cache_mock = Object.new
    cache_mock.define_singleton_method(:respond_to?) do |method, *|
      false
    end
    cache_mock.define_singleton_method(:clear) do
      clear_called = true
      true
    end

    Rails.stub :cache, cache_mock do
      job.send(:clear_geocoder_cache!)
    end

    assert clear_called, "clear should have been called"
  end

  test "clear_geocoder_cache! handles errors gracefully" do
    job = LocationCityFixJob.new

    cache_mock = Object.new
    cache_mock.define_singleton_method(:respond_to?) do |method, *|
      raise StandardError, "Cache error"
    end

    Rails.stub :cache, cache_mock do
      # Should not raise
      job.send(:clear_geocoder_cache!)
    end
  end

  # === perform method tests with mocked services ===

  test "perform returns results hash with expected structure" do
    location = create_test_location(name: "Test Place", city: "Sarajevo", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new

    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, "Sarajevo", [43.8563, 18.4131]

    # Stub sleep to avoid delays
    job.stub :sleep, nil do
      GeoapifyService.stub :new, geoapify_mock do
        results = job.perform(
          remove_outside_bih: false,
          remove_soup_kitchens: false,
          remove_medical_facilities: false,
          remove_city_mismatches: false
        )

        assert results.is_a?(Hash)
        assert_includes results.keys, :started_at
        assert_includes results.keys, :finished_at
        assert_includes results.keys, :total_checked
        assert_includes results.keys, :cities_corrected
        assert_includes results.keys, :errors
        assert_includes results.keys, :corrections
        assert_equal "completed", results[:status]
        assert results[:total_checked] >= 1
      end
    end

    location.destroy
  end

  test "perform with dry_run does not modify locations" do
    location = create_test_location(name: "Test Place", city: "WrongCity", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new

    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, "Sarajevo", [43.8563, 18.4131]

    job.stub :sleep, nil do
      GeoapifyService.stub :new, geoapify_mock do
        results = job.perform(
          dry_run: true,
          remove_outside_bih: false,
          remove_soup_kitchens: false,
          remove_medical_facilities: false,
          remove_city_mismatches: false
        )

        # Location should not be modified
        location.reload
        assert_equal "WrongCity", location.city

        # But correction should be tracked
        assert_not_empty results[:corrections]
      end
    end

    location.destroy
  end

  test "perform corrects city when geocoding returns different city" do
    location = create_test_location(name: "Test Place", city: "WrongCity", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new

    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, "Sarajevo", [43.8563, 18.4131]

    job.stub :sleep, nil do
      GeoapifyService.stub :new, geoapify_mock do
        results = job.perform(
          remove_outside_bih: false,
          remove_soup_kitchens: false,
          remove_medical_facilities: false,
          remove_city_mismatches: false
        )

        location.reload
        assert_equal "Sarajevo", location.city
        assert_equal 1, results[:cities_corrected]
      end
    end

    location.destroy
  end

  test "perform removes soup kitchen locations" do
    location = create_test_location(name: "Narodna Kuhinja Sarajevo", city: "Sarajevo", lat: 43.8563, lng: 18.4131)
    location_id = location.id

    job = LocationCityFixJob.new

    job.stub :sleep, nil do
      results = job.perform(
        remove_soup_kitchens: true,
        remove_medical_facilities: false,
        remove_city_mismatches: false,
        remove_outside_bih: false
      )

      assert_nil Location.find_by(id: location_id)
      assert_equal 1, results[:soup_kitchens_removed]
      assert_not_empty results[:removed_soup_kitchens]
    end
  end

  test "perform removes medical facility locations" do
    location = create_test_location(name: "Crveni Krst Mostar", city: "Mostar", lat: 43.3438, lng: 17.8078)
    location_id = location.id

    job = LocationCityFixJob.new

    job.stub :sleep, nil do
      results = job.perform(
        remove_soup_kitchens: false,
        remove_medical_facilities: true,
        remove_city_mismatches: false,
        remove_outside_bih: false
      )

      assert_nil Location.find_by(id: location_id)
      assert_equal 1, results[:medical_facilities_removed]
      assert_not_empty results[:removed_medical_facilities]
    end
  end

  test "perform removes locations outside BiH" do
    # Belgrade coordinates (outside BiH)
    location = create_test_location(name: "Test Place", city: "Belgrade", lat: 44.82, lng: 20.45)
    location_id = location.id

    job = LocationCityFixJob.new

    job.stub :sleep, nil do
      results = job.perform(
        remove_soup_kitchens: false,
        remove_medical_facilities: false,
        remove_city_mismatches: false,
        remove_outside_bih: true
      )

      assert_nil Location.find_by(id: location_id)
      assert_equal 1, results[:outside_bih_removed]
      assert_not_empty results[:removed_outside_bih]
    end
  end

  test "perform clears cache when clear_cache is true" do
    location = create_test_location(name: "Test Place", city: "Sarajevo", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new
    cache_cleared = false

    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, "Sarajevo", [43.8563, 18.4131]

    job.stub :sleep, nil do
      job.stub :clear_geocoder_cache!, -> { cache_cleared = true } do
        GeoapifyService.stub :new, geoapify_mock do
          job.perform(
            clear_cache: true,
            remove_outside_bih: false,
            remove_soup_kitchens: false,
            remove_medical_facilities: false,
            remove_city_mismatches: false
          )

          assert cache_cleared, "Cache should have been cleared"
        end
      end
    end

    location.destroy
  end

  test "perform handles errors for individual locations gracefully" do
    location = create_test_location(name: "Test Place", city: "Sarajevo", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new

    # Make geocoding fail
    geoapify_mock = Object.new
    def geoapify_mock.get_city_from_coordinates(lat, lng)
      raise StandardError, "API error for location"
    end

    job.stub :sleep, nil do
      GeoapifyService.stub :new, geoapify_mock do
        Geocoder.stub :search, [] do
          results = job.perform(
            remove_outside_bih: false,
            remove_soup_kitchens: false,
            remove_medical_facilities: false,
            remove_city_mismatches: false
          )

          assert_equal "completed", results[:status]
          # Error should be recorded but job should complete
          # (Note: errors are recorded when process_location fails)
        end
      end
    end

    location.destroy
  end

  test "perform with analyze_descriptions analyzes and tracks description issues" do
    location = create_test_location(name: "Test Place", city: "Sarajevo", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new

    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, "Sarajevo", [43.8563, 18.4131]

    # Mock analyzer
    analyzer_mock = Minitest::Mock.new
    analyzer_mock.expect :analyze, {
      score: 50,
      needs_regeneration: true,
      issues: [{ type: :short_description, message: "Too short", locale: "en" }]
    }, [location]

    job.stub :sleep, nil do
      GeoapifyService.stub :new, geoapify_mock do
        Ai::LocationAnalyzer.stub :new, analyzer_mock do
          job.stub :regenerate_location_content, nil do
            results = job.perform(
              analyze_descriptions: true,
              dry_run: true,
              remove_outside_bih: false,
              remove_soup_kitchens: false,
              remove_medical_facilities: false,
              remove_city_mismatches: false
            )

            assert results[:descriptions_analyzed] >= 1
          end
        end
      end
    end

    analyzer_mock.verify
    location.destroy
  end

  test "perform updates status periodically" do
    # Create multiple locations
    locations = 15.times.map do |i|
      create_test_location(name: "Location #{i}", city: "Sarajevo", lat: 43.8563 + (i * 0.001), lng: 18.4131)
    end

    job = LocationCityFixJob.new
    status_updates = []

    geoapify_mock = Object.new
    def geoapify_mock.get_city_from_coordinates(lat, lng)
      "Sarajevo"
    end

    original_save_status = job.method(:save_status)
    job.define_singleton_method(:save_status) do |status, message, results: nil|
      status_updates << { status: status, message: message }
      original_save_status.call(status, message, results: results)
    end

    job.stub :sleep, nil do
      GeoapifyService.stub :new, geoapify_mock do
        job.perform(
          remove_outside_bih: false,
          remove_soup_kitchens: false,
          remove_medical_facilities: false,
          remove_city_mismatches: false
        )
      end
    end

    # Should have progress updates (every 10 locations) plus start and end
    in_progress_count = status_updates.count { |u| u[:status] == "in_progress" }
    assert in_progress_count >= 2, "Should have at least 2 in_progress updates"

    locations.each(&:destroy)
  end

  # === Rate limiting tests ===

  test "perform sleeps after geoapify source" do
    location = create_test_location(name: "Test Place", city: "Sarajevo", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new
    sleep_called_with = nil

    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, "Sarajevo", [43.8563, 18.4131]

    job.define_singleton_method(:sleep) do |duration|
      sleep_called_with = duration
    end

    GeoapifyService.stub :new, geoapify_mock do
      job.perform(
        remove_outside_bih: false,
        remove_soup_kitchens: false,
        remove_medical_facilities: false,
        remove_city_mismatches: false
      )
    end

    assert_equal LocationCityFixJob::GEOAPIFY_SLEEP, sleep_called_with

    location.destroy
  end

  test "perform sleeps after nominatim source" do
    location = create_test_location(name: "Test Place", city: "Sarajevo", lat: 43.8563, lng: 18.4131)

    job = LocationCityFixJob.new
    sleep_called_with = nil

    # Geoapify returns nil, falls back to Nominatim
    geoapify_mock = Minitest::Mock.new
    geoapify_mock.expect :get_city_from_coordinates, nil, [43.8563, 18.4131]

    geocoder_result = OpenStruct.new(
      city: "Sarajevo",
      data: { "address" => { "city" => "Sarajevo" } }
    )

    job.define_singleton_method(:sleep) do |duration|
      sleep_called_with = duration
    end

    GeoapifyService.stub :new, geoapify_mock do
      Geocoder.stub :search, [geocoder_result] do
        job.stub :extract_city_from_result, "Sarajevo" do
          job.perform(
            remove_outside_bih: false,
            remove_soup_kitchens: false,
            remove_medical_facilities: false,
            remove_city_mismatches: false
          )
        end
      end
    end

    assert_equal LocationCityFixJob::NOMINATIM_SLEEP, sleep_called_with

    location.destroy
  end

  # === Helper methods ===

  private

  def build_mock_location(name:, city:, description_en: nil, description_bs: nil, description_hr: nil)
    location = Minitest::Mock.new
    location.expect :name, name
    location.expect :city, city
    location.expect :translate, description_en, [:description, :en]
    location.expect :translate, description_bs, [:description, :bs]
    location.expect :translate, description_hr, [:description, :hr]
    location.expect :translate, nil, [:name, :en]
    location.expect :translate, nil, [:name, :bs]
    location.expect :translate, nil, [:name, :hr]
    location
  end

  def create_test_location(name:, city:, lat: nil, lng: nil)
    Location.create!(
      name: name,
      city: city,
      lat: lat,
      lng: lng
    )
  end
end
