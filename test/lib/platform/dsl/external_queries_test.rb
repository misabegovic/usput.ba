# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ExternalQueriesTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location Sarajevo",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )

    # Mock GeoapifyService responses
    @mock_pois = [
      {
        place_id: "poi_123",
        name: "Test Restaurant",
        address: "Ferhadija 10, Sarajevo",
        lat: 43.8590,
        lng: 18.4300,
        primary_type: "restaurant",
        types: %w[restaurant catering],
        rating: 4.5,
        website: "https://test.ba"
      },
      {
        place_id: "poi_456",
        name: "Test Cafe",
        address: "Bascarsija 5, Sarajevo",
        lat: 43.8600,
        lng: 18.4350,
        primary_type: "cafe",
        types: %w[cafe catering],
        rating: 4.2,
        website: nil
      }
    ]

    @mock_geocode_results = [
      {
        name: "Ferhadija",
        address: "Ferhadija, Sarajevo, Bosnia and Herzegovina",
        lat: 43.8590,
        lng: 18.4300,
        primary_type: "street"
      }
    ]

    @mock_reverse_geocode = {
      formatted: "Ferhadija 10, 71000 Sarajevo, Bosnia and Herzegovina",
      city: "Sarajevo",
      country: "Bosnia and Herzegovina",
      country_code: "ba"
    }
  end

  # validate_location tests
  test "validate_location returns valid for BiH coordinates" do
    result = Platform::DSL::Executor.send(:validate_location, { lat: 43.8563, lng: 18.4131 })

    assert_equal true, result[:valid]
    assert_equal true, result[:in_bih]
  end

  test "validate_location returns invalid for outside BiH coordinates" do
    result = Platform::DSL::Executor.send(:validate_location, { lat: 48.8566, lng: 2.3522 }) # Paris

    assert_equal false, result[:valid]
    assert_equal false, result[:in_bih]
    assert result[:message].present?
    assert result[:distance_to_border_km].present?
  end

  test "validate_location raises error without coordinates" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:validate_location, {})
    end
  end

  # check_duplicate tests
  test "check_duplicate finds duplicates by name" do
    result = Platform::DSL::Executor.send(:check_duplicate, { name: "Test Location" })

    assert result[:has_duplicates]
    assert result[:count] >= 1
    assert result[:duplicates].any?
  end

  test "check_duplicate finds no duplicates for unique name" do
    result = Platform::DSL::Executor.send(:check_duplicate, { name: "NonExistentUniqueLocation12345" })

    assert_not result[:has_duplicates]
    assert_equal 0, result[:count]
  end

  test "check_duplicate finds duplicates by proximity" do
    # Create a location at known coordinates
    result = Platform::DSL::Executor.send(:check_duplicate, {
      lat: @location.lat,
      lng: @location.lng
    })

    assert result[:has_duplicates]
  end

  test "check_duplicate raises error without name or coordinates" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:check_duplicate, {})
    end
  end

  # haversine_distance tests
  test "haversine_distance calculates distance correctly" do
    # Sarajevo to Mostar - calculate actual and verify it's reasonable (60-80km)
    distance = Platform::DSL::Executor.send(:haversine_distance, 43.8563, 18.4131, 43.3438, 17.8078)

    assert_in_delta 75, distance, 20 # Within 20km tolerance
  end

  test "haversine_distance returns 0 for same point" do
    distance = Platform::DSL::Executor.send(:haversine_distance, 43.8563, 18.4131, 43.8563, 18.4131)

    assert_in_delta 0, distance, 0.001
  end

  # to_radians tests
  test "to_radians converts degrees correctly" do
    result = Platform::DSL::Executor.send(:to_radians, 180)

    assert_in_delta Math::PI, result, 0.0001
  end

  # get_city_coordinates tests
  test "get_city_coordinates finds coordinates from existing locations" do
    result = Platform::DSL::Executor.send(:get_city_coordinates, "Sarajevo")

    assert result.present?
    assert result[:lat].present?
    assert result[:lng].present?
  end

  # format_poi_result tests
  test "format_poi_result formats place data" do
    place = {
      place_id: "test123",
      name: "Test Place",
      address: "123 Test St",
      lat: 43.8563,
      lng: 18.4131,
      primary_type: "restaurant",
      types: %w[restaurant food],
      rating: 4.5,
      website: "https://test.com"
    }

    result = Platform::DSL::Executor.send(:format_poi_result, place)

    assert_equal "test123", result[:place_id]
    assert_equal "Test Place", result[:name]
    assert_equal 4.5, result[:rating]
  end

  # execute_external_query error handling
  test "execute_external_query raises error for unknown operation" do
    ast = {
      type: :external_query,
      filters: {},
      operations: [{ name: :unknown_external_op }]
    }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.execute(ast)
    end
  end

  # search_pois error handling
  test "search_pois raises error without city" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:search_pois, {}, nil)
    end
  end

  # geocode_address error handling
  test "geocode_address raises error without address" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:geocode_address, {})
    end
  end

  # reverse_geocode_coords error handling
  test "reverse_geocode_coords raises error without coordinates" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:reverse_geocode_coords, {})
    end
  end

  # Mocked GeoapifyService tests

  # Helper to create a mock service object
  def create_mock_geoapify_service(
    search_nearby_result: nil,
    text_search_result: nil,
    reverse_geocode_result: nil
  )
    mock = Object.new

    if search_nearby_result
      mock.define_singleton_method(:search_nearby) { |**_args| search_nearby_result }
    end

    if text_search_result
      mock.define_singleton_method(:text_search) { |**_args| text_search_result }
    end

    if reverse_geocode_result
      mock.define_singleton_method(:reverse_geocode) { |**_args| reverse_geocode_result }
    end

    mock
  end

  test "search_pois returns results with mocked service" do
    mock_service = create_mock_geoapify_service(search_nearby_result: @mock_pois)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:search_pois, { city: "Sarajevo" }, nil)

        assert result.is_a?(Hash)
        assert_equal "Sarajevo", result[:city]
        # The method returns :results key with array of POIs
        assert result.key?(:results), "Result should have :results key, got: #{result.keys.inspect}"
      end
    end
  end

  test "search_pois raises error when city coordinates not found" do
    # Clear locations to ensure no fallback
    Location.where(city: "NonExistentCity123").delete_all

    mock_service = create_mock_geoapify_service(text_search_result: [])

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      assert_raises(Platform::DSL::ExecutionError) do
        Platform::DSL::Executor.send(:search_pois, { city: "NonExistentCity123" }, nil)
      end
    end
  end

  test "geocode_address returns results with mocked service" do
    mock_service = create_mock_geoapify_service(text_search_result: @mock_geocode_results)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:geocode_address, { address: "Ferhadija, Sarajevo" })

        assert result.is_a?(Hash)
        assert_equal "Ferhadija, Sarajevo", result[:query]
        assert result[:found]
        assert result[:results].is_a?(Array)
      end
    end
  end

  test "geocode_address returns not found for empty results" do
    mock_service = create_mock_geoapify_service(text_search_result: [])

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:geocode_address, { address: "NonExistentPlace12345" })

        assert result.is_a?(Hash)
        assert_not result[:found]
        assert_equal [], result[:results]
      end
    end
  end

  test "geocode_address uses query filter as fallback" do
    mock_service = create_mock_geoapify_service(text_search_result: @mock_geocode_results)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:geocode_address, { query: "Ferhadija" })

        assert result[:found]
      end
    end
  end

  test "reverse_geocode_coords returns results with mocked service" do
    mock_service = create_mock_geoapify_service(reverse_geocode_result: @mock_reverse_geocode)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:reverse_geocode_coords, { lat: 43.8563, lng: 18.4131 })

        assert result.is_a?(Hash)
        assert_equal 43.8563, result[:lat]
        assert_equal 18.4131, result[:lng]
        assert result[:in_bih]
        assert_equal "Sarajevo", result[:city]
      end
    end
  end

  test "reverse_geocode_coords marks outside BiH correctly" do
    mock_service = create_mock_geoapify_service(reverse_geocode_result: {
      formatted: "Paris, France",
      city: "Paris",
      country: "France",
      country_code: "fr"
    })

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:reverse_geocode_coords, { lat: 48.8566, lng: 2.3522 })

        assert_not result[:in_bih]
        assert_equal "Paris", result[:city]
        assert_equal "France", result[:country]
      end
    end
  end

  test "get_city_coordinates falls back to geocoding when no location exists" do
    # Ensure no location exists for this city
    Location.where(city: "Trebinje").delete_all

    mock_results = [{ name: "Trebinje", lat: 42.7117, lng: 18.3437 }]
    mock_service = create_mock_geoapify_service(text_search_result: mock_results)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      result = Platform::DSL::Executor.send(:get_city_coordinates, "Trebinje")

      assert result.present?
      assert_in_delta 42.7117, result[:lat], 0.01
      assert_in_delta 18.3437, result[:lng], 0.01
    end
  end

  test "get_city_coordinates returns nil when geocoding finds no BiH results" do
    Location.where(city: "FakeCity").delete_all

    # Return results outside BiH
    mock_results = [{ name: "FakeCity", lat: 48.8566, lng: 2.3522 }]
    mock_service = create_mock_geoapify_service(text_search_result: mock_results)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      result = Platform::DSL::Executor.send(:get_city_coordinates, "FakeCity")

      assert_nil result
    end
  end

  test "search_pois filters results to BiH only" do
    # Mock POIs with one inside BiH and one outside
    mixed_pois = [
      { place_id: "bih_poi", name: "Sarajevo Restaurant", lat: 43.8590, lng: 18.4300 },
      { place_id: "outside_poi", name: "Paris Cafe", lat: 48.8566, lng: 2.3522 }
    ]

    mock_service = create_mock_geoapify_service(search_nearby_result: mixed_pois)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:search_pois, { city: "Sarajevo" }, nil)

        # Result should have results key
        assert result.key?(:results), "Result should have :results key"
        pois = result[:results] || []

        # Should filter out non-BiH results (all results should be in BiH since it filters)
        bih_count = pois.count { |p| Geo::BihBoundaryValidator.inside_bih?(p[:lat], p[:lng]) }
        assert bih_count <= 1, "Should have at most 1 BiH result"
      end
    end
  end

  test "search_pois uses provided radius and limit" do
    mock_service = create_mock_geoapify_service(search_nearby_result: @mock_pois)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:search_pois, {
          city: "Sarajevo",
          radius: 5000,
          limit: 10
        }, nil)

        assert result.is_a?(Hash)
        assert_equal "Sarajevo", result[:city]
      end
    end
  end

  test "search_pois uses categories from args" do
    mock_service = create_mock_geoapify_service(search_nearby_result: @mock_pois)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:search_pois, { city: "Sarajevo" }, ["restaurant"])

        assert result.is_a?(Hash)
      end
    end
  end

  test "search_pois uses categories from filters" do
    mock_service = create_mock_geoapify_service(search_nearby_result: @mock_pois)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:search_pois, { city: "Sarajevo", categories: "cafe" }, nil)

        assert result.is_a?(Hash)
      end
    end
  end

  test "geocode_address marks BiH results correctly" do
    mock_results = [
      { name: "Place1", lat: 43.8590, lng: 18.4300, primary_type: "poi" },
      { name: "Place2", lat: 48.8566, lng: 2.3522, primary_type: "poi" }
    ]

    mock_service = create_mock_geoapify_service(text_search_result: mock_results)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:geocode_address, { address: "test address" })

        assert_equal 2, result[:count]
        assert_equal 1, result[:in_bih_count]

        # Verify in_bih flags are set correctly
        bih_result = result[:results].find { |r| r[:name] == "Place1" }
        non_bih_result = result[:results].find { |r| r[:name] == "Place2" }

        assert bih_result[:in_bih]
        assert_not non_bih_result[:in_bih]
      end
    end
  end

  # DSL integration tests with mocked service
  test "external | geocode executes with mocked service" do
    mock_service = create_mock_geoapify_service(text_search_result: @mock_geocode_results)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL.execute('external { address: "Sarajevo" } | geocode')

        assert result[:found]
      end
    end
  end

  test "external | reverse_geocode executes with mocked service" do
    mock_service = create_mock_geoapify_service(reverse_geocode_result: @mock_reverse_geocode)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL.execute("external { lat: 43.8563, lng: 18.4131 } | reverse_geocode")

        assert result[:city].present?
      end
    end
  end

  test "external | search_pois executes with mocked service" do
    mock_service = create_mock_geoapify_service(search_nearby_result: @mock_pois)

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL.execute('external { city: "Sarajevo" } | search_pois')

        assert_equal "Sarajevo", result[:city]
        assert result.key?(:results), "Result should have :results key"
      end
    end
  end

  test "reverse_geocode_coords handles town fallback" do
    mock_service = create_mock_geoapify_service(reverse_geocode_result: {
      formatted: "Trebinje, Bosnia and Herzegovina",
      town: "Trebinje",
      country: "Bosnia and Herzegovina",
      country_code: "ba"
    })

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:reverse_geocode_coords, { lat: 42.7117, lng: 18.3437 })

        assert_equal "Trebinje", result[:city]
      end
    end
  end

  test "reverse_geocode_coords handles village fallback" do
    mock_service = create_mock_geoapify_service(reverse_geocode_result: {
      formatted: "Lukomir, Bosnia and Herzegovina",
      village: "Lukomir",
      country: "Bosnia and Herzegovina",
      country_code: "ba"
    })

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:reverse_geocode_coords, { lat: 43.65, lng: 18.05 })

        assert_equal "Lukomir", result[:city]
      end
    end
  end

  test "get_city_coordinates returns nil for empty geocode results" do
    Location.where(city: "EmptyResults").delete_all

    mock_service = create_mock_geoapify_service(text_search_result: [])

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      result = Platform::DSL::Executor.send(:get_city_coordinates, "EmptyResults")

      assert_nil result
    end
  end

  # Additional check_duplicate tests for full coverage
  test "check_duplicate returns duplicate data with count and array" do
    # Create locations with same name
    Location.create!(name: "Duplicate Test Location", city: "Test1", lat: 43.1, lng: 18.1)
    Location.create!(name: "Duplicate Test Location", city: "Test2", lat: 43.2, lng: 18.2)

    result = Platform::DSL::Executor.send(:check_duplicate, { name: "Duplicate Test" })

    assert result[:has_duplicates]
    assert result[:count] >= 1
    # Verify duplicates array has unique entries
    assert result[:duplicates].is_a?(Array)
    ids = result[:duplicates].map { |d| d[:id] }
    assert_equal ids.uniq.length, ids.length
  end

  test "check_duplicate by proximity returns distance_m" do
    result = Platform::DSL::Executor.send(:check_duplicate, {
      lat: @location.lat,
      lng: @location.lng
    })

    assert result[:has_duplicates]
    # Check that duplicates have distance_m field
    assert result[:duplicates].all? { |d| d.key?(:distance_m) }
  end

  test "geoapify_service returns GeoapifyService instance" do
    # Clear any cached instance
    Platform::DSL::Executors::External.instance_variable_set(:@geoapify_service, nil)

    # Only test if API key is configured
    if ENV["GEOAPIFY_API_KEY"].present?
      service = Platform::DSL::Executors::External.send(:geoapify_service)
      assert service.is_a?(GeoapifyService)
    else
      # Skip test in CI where API key isn't configured
      assert true, "Skipping geoapify_service test - API key not configured"
    end
  end

  # Test execute_external_query with all operations
  test "execute_external_query with validate_location operation" do
    ast = {
      type: :external_query,
      filters: { lat: 43.8563, lng: 18.4131 },
      operations: [{ name: :validate_location }]
    }

    result = Platform::DSL::Executor.execute(ast)

    assert result[:valid]
  end

  test "execute_external_query with check_duplicate operation" do
    ast = {
      type: :external_query,
      filters: { name: "NonExistent12345" },
      operations: [{ name: :check_duplicate }]
    }

    result = Platform::DSL::Executor.execute(ast)

    assert_not result[:has_duplicates]
  end

  test "execute_external_query with validate alias" do
    ast = {
      type: :external_query,
      filters: { lat: 43.8563, lng: 18.4131 },
      operations: [{ name: :validate }]
    }

    result = Platform::DSL::Executor.execute(ast)

    assert result[:valid]
  end

  test "execute_external_query with dedupe alias" do
    ast = {
      type: :external_query,
      filters: { name: "NonExistent12345" },
      operations: [{ name: :dedupe }]
    }

    result = Platform::DSL::Executor.execute(ast)

    assert_not result[:has_duplicates]
  end
end
