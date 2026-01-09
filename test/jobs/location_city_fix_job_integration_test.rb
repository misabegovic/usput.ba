# frozen_string_literal: true

require "test_helper"

class LocationCityFixJobIntegrationTest < ActiveJob::TestCase
  setup do
    # Create test locations with coordinates
    @location1 = Location.create!(
      name: "Test Location 1",
      city: "WrongCity",
      lat: 43.8563,
      lng: 18.4131
    )

    @location2 = Location.create!(
      name: "Test Location 2",
      city: "AnotherWrongCity",
      lat: 43.8570,
      lng: 18.4150
    )
  end

  teardown do
    LocationCityFixJob.clear_status!
  end

  # === Rate limiting constants tests ===

  test "GEOAPIFY_SLEEP is 0.2 seconds (5 req/s)" do
    assert_equal 0.2, LocationCityFixJob::GEOAPIFY_SLEEP
  end

  test "NOMINATIM_SLEEP is 1.1 seconds (1 req/s with buffer)" do
    assert_equal 1.1, LocationCityFixJob::NOMINATIM_SLEEP
  end

  test "Geoapify is faster than Nominatim" do
    assert LocationCityFixJob::GEOAPIFY_SLEEP < LocationCityFixJob::NOMINATIM_SLEEP
  end

  test "Nominatim rate limit respects 1 request per second" do
    assert LocationCityFixJob::NOMINATIM_SLEEP > 1.0, "Nominatim needs > 1s delay (1 req/s limit)"
  end

  # === get_city_from_coordinates source detection tests ===

  test "get_city_from_coordinates returns override source for Zvornik coordinates" do
    job = LocationCityFixJob.new

    # Use coordinates that match the COORDINATE_OVERRIDES (Zvornik area)
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

  # === Coordinate override tests ===

  test "check_coordinate_overrides returns Zvornik for matching coordinates" do
    job = LocationCityFixJob.new

    # Within Zvornik override range
    result = job.send(:check_coordinate_overrides, 44.40, 19.10)
    assert_equal "Zvornik", result

    # Outside override range
    result = job.send(:check_coordinate_overrides, 43.85, 18.41)
    assert_nil result
  end

  test "COORDINATE_OVERRIDES includes Zvornik area" do
    overrides = LocationCityFixJob::COORDINATE_OVERRIDES

    zvornik_override = overrides.find { |o| o[:city] == "Zvornik" }
    assert_not_nil zvornik_override, "Should have Zvornik coordinate override"
    assert zvornik_override[:lat_range].is_a?(Range)
    assert zvornik_override[:lng_range].is_a?(Range)
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = LocationCityFixJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "clear_status! resets to idle" do
    Setting.set("location_fix.status", "in_progress")

    LocationCityFixJob.clear_status!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
  end

  test "force_reset_city_fix! resets stuck job" do
    Setting.set("location_fix.status", "in_progress")

    LocationCityFixJob.force_reset_city_fix!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
  end

  # === City comparison tests ===

  test "cities_different? returns true for blank vs present" do
    job = LocationCityFixJob.new

    assert job.send(:cities_different?, "", "Sarajevo")
    assert job.send(:cities_different?, nil, "Sarajevo")
  end

  test "cities_different? returns false for same city (case insensitive)" do
    job = LocationCityFixJob.new

    refute job.send(:cities_different?, "Sarajevo", "sarajevo")
    refute job.send(:cities_different?, "SARAJEVO", "Sarajevo")
  end

  test "cities_different? handles special characters" do
    job = LocationCityFixJob.new

    # Same city with different formatting
    refute job.send(:cities_different?, "Banja Luka", "Banja Luka")
  end

  # === City name cleaning tests ===

  test "clean_city_name removes Grad prefix" do
    job = LocationCityFixJob.new

    assert_equal "Zvornik", job.send(:clean_city_name, "Grad Zvornik")
    assert_equal "Sarajevo", job.send(:clean_city_name, "Grad Sarajevo")
  end

  test "clean_city_name removes Općina prefix" do
    job = LocationCityFixJob.new

    assert_equal "Mostar", job.send(:clean_city_name, "Općina Mostar")
  end

  test "clean_city_name removes Opština prefix" do
    job = LocationCityFixJob.new

    assert_equal "Banja Luka", job.send(:clean_city_name, "Opština Banja Luka")
  end

  test "clean_city_name removes Municipality of prefix" do
    job = LocationCityFixJob.new

    assert_equal "Sarajevo", job.send(:clean_city_name, "Municipality of Sarajevo")
  end
end
