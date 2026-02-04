# frozen_string_literal: true

require "test_helper"

class Platform::DSL::Executors::ExternalTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
  end

  # ===================
  # External Query Tests
  # ===================

  test "execute_external_query raises for unknown operation" do
    ast = {
      filters: {},
      operations: [ { name: :unknown_operation } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_external_query(ast)
    end

    assert_match(/Nepoznata external operacija/i, error.message)
  end

  test "execute_external_query raises for nil operation" do
    ast = {
      filters: {},
      operations: nil
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_external_query(ast)
    end

    assert_match(/Nepoznata external operacija/i, error.message)
  end

  # ===================
  # Geocode Tests
  # ===================

  test "geocode_address raises without address filter" do
    ast = {
      filters: {},
      operations: [ { name: :geocode } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_external_query(ast)
    end

    assert_match(/geocode zahtijeva filter: address/i, error.message)
  end

  test "geocode_address with mocked service" do
    mock_results = [
      { name: "Test", address: "Test Address", lat: 43.85, lng: 18.41, primary_type: "city" }
    ]

    mock_service = Object.new
    mock_service.define_singleton_method(:text_search) { |**_args| mock_results }

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(opts, &block) { block.call }) do
        ast = {
          filters: { address: "Sarajevo" },
          operations: [ { name: :geocode } ]
        }

        result = Platform::DSL::Executors::External.execute_external_query(ast)

        assert_equal "Sarajevo", result[:query]
        assert result[:found]
      end
    end
  end

  # ===================
  # Reverse Geocode Tests
  # ===================

  test "reverse_geocode_coords raises without lat/lng filters" do
    ast = {
      filters: { lat: 43.85 },
      operations: [ { name: :reverse_geocode } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_external_query(ast)
    end

    assert_match(/reverse_geocode zahtijeva filtere: lat, lng/i, error.message)
  end

  test "reverse_geocode_coords with mocked service" do
    mock_result = {
      formatted: "Test Address, Sarajevo",
      city: "Sarajevo",
      country: "Bosnia and Herzegovina",
      country_code: "BA"
    }

    mock_service = Object.new
    mock_service.define_singleton_method(:reverse_geocode) { |**_args| mock_result }

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(opts, &block) { block.call }) do
        ast = {
          filters: { lat: 43.85, lng: 18.41 },
          operations: [ { name: :reverse_geocode } ]
        }

        result = Platform::DSL::Executors::External.execute_external_query(ast)

        assert_equal 43.85, result[:lat]
        assert_equal 18.41, result[:lng]
        assert result[:in_bih]
      end
    end
  end

  # ===================
  # Validate Location Tests
  # ===================

  test "validate_location raises without lat/lng filters" do
    ast = {
      filters: { lat: 43.85 },
      operations: [ { name: :validate_location } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_external_query(ast)
    end

    assert_match(/validate_location zahtijeva filtere: lat, lng/i, error.message)
  end

  test "validate_location for location inside BiH" do
    ast = {
      filters: { lat: 43.85, lng: 18.41 },
      operations: [ { name: :validate_location } ]
    }

    result = Platform::DSL::Executors::External.execute_external_query(ast)

    assert result[:in_bih]
    assert result[:valid]
  end

  test "validate_location for location outside BiH" do
    ast = {
      filters: { lat: 48.85, lng: 2.35 },  # Paris
      operations: [ { name: :validate } ]
    }

    result = Platform::DSL::Executors::External.execute_external_query(ast)

    assert_not result[:in_bih]
    assert_not result[:valid]
    assert result[:distance_to_border_km].present?
    assert result[:message].present?
  end

  # ===================
  # Check Duplicate Tests
  # ===================

  test "check_duplicate raises without name or lat/lng" do
    ast = {
      filters: {},
      operations: [ { name: :check_duplicate } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_external_query(ast)
    end

    assert_match(/check_duplicate zahtijeva filter: name ili/i, error.message)
  end

  test "check_duplicate by name" do
    ast = {
      filters: { name: @location.name },
      operations: [ { name: :check_duplicate } ]
    }

    result = Platform::DSL::Executors::External.execute_external_query(ast)

    assert result[:has_duplicates]
    assert result[:duplicates].any? { |d| d[:id] == @location.id }
  end

  test "check_duplicate by coords" do
    ast = {
      filters: { lat: @location.lat, lng: @location.lng },
      operations: [ { name: :dedupe } ]
    }

    result = Platform::DSL::Executors::External.execute_external_query(ast)

    assert result[:has_duplicates]
    assert result[:duplicates].any? { |d| d[:id] == @location.id }
  end

  test "check_duplicate returns empty for non-matching" do
    ast = {
      filters: { name: "NonExistentLocationXYZ123456" },
      operations: [ { name: :check_duplicate } ]
    }

    result = Platform::DSL::Executors::External.execute_external_query(ast)

    assert_not result[:has_duplicates]
    assert_equal 0, result[:count]
  end

  # ===================
  # Search POIs Tests
  # ===================

  test "search_pois raises without city filter" do
    ast = {
      filters: {},
      operations: [ { name: :search_pois } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_external_query(ast)
    end

    assert_match(/search_pois zahtijeva filter: city/i, error.message)
  end

  # ===================
  # Code Query Tests
  # ===================

  test "execute_code_query returns code overview by default" do
    ast = {
      filters: {},
      operations: nil
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :code_overview, result[:action]
    assert result[:app].present?
    assert result[:lib].present?
    assert result[:test].present?
    assert result[:config].present?
  end

  test "execute_code_query reads file" do
    ast = {
      filters: { file: "Gemfile" },
      operations: [ { name: :read_file } ]
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :read_file, result[:action]
    assert_equal "Gemfile", result[:path]
    assert result[:content].present?
  end

  test "read_file raises for missing file" do
    ast = {
      filters: { file: "nonexistent_file_xyz.rb" },
      operations: [ { name: :read_file } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_code_query(ast)
    end

    assert_match(/Fajl nije pronađen/i, error.message)
  end

  test "read_file raises for path outside project" do
    ast = {
      filters: { file: "/etc/passwd" },
      operations: [ { name: :read_file } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_code_query(ast)
    end

    assert_match(/Pristup fajlovima izvan projekta nije dozvoljen/i, error.message)
  end

  test "read_file raises without file filter" do
    ast = {
      filters: {},
      operations: [ { name: :read_file } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_code_query(ast)
    end

    assert_match(/Potreban filter: file ili path/i, error.message)
  end

  test "read_file with line range" do
    ast = {
      filters: { file: "Gemfile", from: 1, to: 5 },
      operations: [ { name: :read_file } ]
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :read_file, result[:action]
    assert_equal "1-5", result[:showing]
  end

  test "execute_code_query searches code" do
    ast = {
      filters: { path: "app/models" },
      operations: [ { name: :search, args: [ "ApplicationRecord" ] } ]
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :search_code, result[:action]
    assert_equal "ApplicationRecord", result[:pattern]
    assert result[:results].is_a?(Array)
  end

  test "search_code raises without pattern" do
    ast = {
      filters: {},
      operations: [ { name: :search, args: nil } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_code_query(ast)
    end

    assert_match(/Potreban search pattern/i, error.message)
  end

  test "execute_code_query greps code" do
    ast = {
      filters: { path: "app/models" },
      operations: [ { name: :grep, args: [ "has_many" ] } ]
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :search_code, result[:action]
    assert_equal "has_many", result[:pattern]
  end

  test "execute_code_query shows code structure" do
    ast = {
      filters: { path: "app/models" },
      operations: [ { name: :structure } ]
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :code_structure, result[:action]
    assert result[:structure].present?
  end

  test "show_code_structure raises for non-existent directory" do
    ast = {
      filters: { path: "nonexistent_directory_xyz" },
      operations: [ { name: :structure } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_code_query(ast)
    end

    assert_match(/Direktorij nije pronađen/i, error.message)
  end

  test "execute_code_query lists models" do
    ast = {
      filters: {},
      operations: [ { name: :models } ]
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :list_models, result[:action]
    assert result[:models].any?
    assert result[:models].any? { |m| m[:name] == "Location" }
  end

  test "execute_code_query lists routes" do
    ast = {
      filters: {},
      operations: [ { name: :routes } ]
    }

    result = Platform::DSL::Executors::External.execute_code_query(ast)

    assert_equal :list_routes, result[:action]
    assert result[:routes].is_a?(Array)
    assert result[:count] > 0
  end

  # ===================
  # Helper Method Tests
  # ===================

  test "haversine_distance calculates correctly" do
    # Sarajevo to Mostar is approximately 120 km
    distance = Platform::DSL::Executors::External.send(
      :haversine_distance,
      43.8563, 18.4131,  # Sarajevo
      43.3436, 17.8078   # Mostar
    )

    assert distance > 50
    assert distance < 150
  end

  test "to_radians converts correctly" do
    result = Platform::DSL::Executors::External.send(:to_radians, 180)
    assert_in_delta Math::PI, result, 0.0001
  end

  test "format_poi_result returns correct structure" do
    place = {
      place_id: "123",
      name: "Test Place",
      address: "Test Address",
      lat: 43.85,
      lng: 18.41,
      primary_type: "restaurant",
      types: [ "restaurant", "food" ],
      rating: 4.5,
      website: "https://example.com"
    }

    result = Platform::DSL::Executors::External.send(:format_poi_result, place)

    assert_equal "123", result[:place_id]
    assert_equal "Test Place", result[:name]
    assert_equal 43.85, result[:lat]
  end

  # Additional branch coverage tests

  test "check_duplicate handles locations without coordinates" do
    # Create a location without coordinates
    Location.create!(name: "No Coords Location", city: "Test City", lat: nil, lng: nil)

    ast = {
      filters: { lat: 43.85, lng: 18.41 },
      operations: [ { name: :check_duplicate } ]
    }

    result = Platform::DSL::Executors::External.execute_external_query(ast)

    assert result[:has_duplicates].is_a?(TrueClass) || result[:has_duplicates].is_a?(FalseClass)
  end

  test "grep_code with nil args" do
    ast = {
      filters: { path: "app/models" },
      operations: [ { name: :grep, args: nil } ]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::External.execute_code_query(ast)
    end

    assert_match(/Potreban search pattern/i, error.message)
  end

  test "get_city_coordinates returns nil for city without location" do
    # Make sure there's no location for this city
    Location.where(city: "NonExistentCity123").delete_all

    mock_service = Object.new
    mock_service.define_singleton_method(:text_search) { |**_args| [] }

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      result = Platform::DSL::Executors::External.send(:get_city_coordinates, "NonExistentCity123")
      assert_nil result
    end
  end

  test "get_city_coordinates returns location coords if available" do
    # This tests the first branch - when location with coords exists
    loc = Location.create!(name: "Test", city: "TestCoordCity", lat: 44.0, lng: 18.0)

    result = Platform::DSL::Executors::External.send(:get_city_coordinates, "TestCoordCity")

    assert_equal 44.0, result[:lat]
    assert_equal 18.0, result[:lng]
  end

  test "geoapify_service creates service instance" do
    # Verify the method exists and tries to create service
    # Skip if API key not configured
    begin
      result = Platform::DSL::Executors::External.send(:geoapify_service)
      assert result.is_a?(GeoapifyService)
    rescue GeoapifyService::ConfigurationError
      # API key not configured in test - just verify method exists
      assert Platform::DSL::Executors::External.respond_to?(:geoapify_service, true)
    end
  end
end
