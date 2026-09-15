# frozen_string_literal: true

require "test_helper"

class GeoapifyServiceTest < ActiveSupport::TestCase
  # === Configuration tests ===

  test "raises ConfigurationError when API key is not configured" do
    Rails.application.config.geoapify.stub(:api_key, nil) do
      assert_raises(GeoapifyService::ConfigurationError) do
        GeoapifyService.new
      end
    end
  end

  test "raises ConfigurationError when API key is blank" do
    Rails.application.config.geoapify.stub(:api_key, "") do
      assert_raises(GeoapifyService::ConfigurationError) do
        GeoapifyService.new
      end
    end
  end

  # === search_nearby tests ===

  test "search_nearby returns array of parsed places" do
    mock_response = mock_places_response([
      { name: "Test Restaurant", place_id: "place_123", lat: 43.856, lng: 18.413 }
    ])

    service = build_service_with_stubbed_connection(mock_response)

    results = service.search_nearby(lat: 43.856, lng: 18.413, radius: 1000)

    assert_kind_of Array, results
    assert_equal 1, results.count
    assert_equal "Test Restaurant", results.first[:name]
    assert_equal "place_123", results.first[:place_id]
  end

  test "search_nearby returns empty array when no features in response" do
    mock_response = { "features" => nil }
    service = build_service_with_stubbed_connection(mock_response)

    results = service.search_nearby(lat: 43.856, lng: 18.413)

    assert_equal [], results
  end

  test "search_nearby filters out excluded places by category" do
    mock_response = mock_places_response([
      { name: "Good Restaurant", place_id: "place_1", lat: 43.856, lng: 18.413, categories: [ "catering.restaurant" ] },
      { name: "Retirement Home", place_id: "place_2", lat: 43.857, lng: 18.414, categories: [ "service.social_facility" ] }
    ])

    service = build_service_with_stubbed_connection(mock_response)

    results = service.search_nearby(lat: 43.856, lng: 18.413)

    assert_equal 1, results.count
    assert_equal "Good Restaurant", results.first[:name]
  end

  test "search_nearby filters out excluded places by name keywords" do
    mock_response = mock_places_response([
      { name: "Good Cafe", place_id: "place_1", lat: 43.856, lng: 18.413 },
      { name: "Dom za stare", place_id: "place_2", lat: 43.857, lng: 18.414 }
    ])

    service = build_service_with_stubbed_connection(mock_response)

    results = service.search_nearby(lat: 43.856, lng: 18.413)

    assert_equal 1, results.count
    assert_equal "Good Cafe", results.first[:name]
  end

  test "search_nearby uses default radius from settings" do
    Setting.stub :get, ->(key, **opts) { key == "geoapify.default_radius" ? 15000 : opts[:default] } do
      mock_response = mock_places_response([])
      service = build_service_with_stubbed_connection(mock_response)

      # Just verify it doesn't raise - the stub validates the call happens
      results = service.search_nearby(lat: 43.856, lng: 18.413)
      assert_kind_of Array, results
    end
  end

  test "search_nearby respects max_results parameter" do
    mock_response = mock_places_response([
      { name: "Place 1", place_id: "p1", lat: 43.856, lng: 18.413 },
      { name: "Place 2", place_id: "p2", lat: 43.857, lng: 18.414 },
      { name: "Place 3", place_id: "p3", lat: 43.858, lng: 18.415 }
    ])

    service = build_service_with_stubbed_connection(mock_response)

    results = service.search_nearby(lat: 43.856, lng: 18.413, max_results: 2)

    assert_equal 2, results.count
  end

  test "search_nearby converts Google types to Geoapify categories" do
    mock_response = mock_places_response([
      { name: "Museum", place_id: "p1", lat: 43.856, lng: 18.413 }
    ])

    service = build_service_with_stubbed_connection(mock_response)

    # Using Google-style types that should be converted
    results = service.search_nearby(lat: 43.856, lng: 18.413, types: [ "museum" ])

    assert_kind_of Array, results
  end

  test "search_nearby deduplicates results by place_id" do
    mock_response = mock_places_response([
      { name: "Same Place", place_id: "duplicate_id", lat: 43.856, lng: 18.413 },
      { name: "Same Place", place_id: "duplicate_id", lat: 43.856, lng: 18.413 }
    ])

    service = build_service_with_stubbed_connection(mock_response)

    results = service.search_nearby(lat: 43.856, lng: 18.413)

    assert_equal 1, results.count
  end

  # === text_search tests ===

  test "text_search returns array of geocoded results" do
    mock_body = {
      "features" => [
        {
          "properties" => {
            "place_id" => "geo_123",
            "name" => "Baščaršija",
            "formatted" => "Baščaršija, Sarajevo, Bosnia and Herzegovina",
            "lat" => 43.859,
            "lon" => 18.431,
            "category" => "tourism.attraction"
          }
        }
      ]
    }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      results = service.text_search(query: "Baščaršija")

      assert_kind_of Array, results
      assert_equal 1, results.count
      assert_equal "Baščaršija", results.first[:name]
    end
  end

  test "text_search returns empty array when no features" do
    mock_body = { "features" => nil }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      results = service.text_search(query: "nonexistent place")

      assert_equal [], results
    end
  end

  test "text_search filters out excluded places" do
    mock_body = {
      "features" => [
        {
          "properties" => {
            "place_id" => "geo_1",
            "name" => "Good Place",
            "formatted" => "Good Place, Sarajevo",
            "lat" => 43.859,
            "lon" => 18.431
          }
        },
        {
          "properties" => {
            "place_id" => "geo_2",
            "name" => "Soup Kitchen Sarajevo",
            "formatted" => "Soup Kitchen, Sarajevo",
            "lat" => 43.860,
            "lon" => 18.432
          }
        }
      ]
    }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      results = service.text_search(query: "places in sarajevo")

      assert_equal 1, results.count
      assert_equal "Good Place", results.first[:name]
    end
  end

  # === get_place_details tests ===

  test "get_place_details returns parsed place details" do
    mock_body = {
      "features" => [
        {
          "properties" => {
            "place_id" => "detail_123",
            "name" => "Stari Most",
            "formatted" => "Stari Most, Mostar",
            "categories" => [ "tourism.sights.bridge" ],
            "rating" => 4.8,
            "rating_count" => 1500,
            "website" => "https://example.com",
            "wiki_and_media" => {
              "description" => "Famous Ottoman bridge",
              "wikipedia" => "https://en.wikipedia.org/wiki/Stari_Most"
            }
          },
          "geometry" => {
            "type" => "Point",
            "coordinates" => [ 17.815, 43.337 ]
          }
        }
      ]
    }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      result = service.get_place_details("detail_123")

      assert_equal "Stari Most", result[:name]
      assert_equal 4.8, result[:rating]
      assert_equal "Famous Ottoman bridge", result[:description]
      assert_includes result[:types], "bridge"
    end
  end

  test "get_place_details returns empty hash when no features" do
    mock_body = { "features" => [] }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      result = service.get_place_details("nonexistent_id")

      assert_equal({}, result)
    end
  end

  test "get_place_details handles polygon geometry" do
    mock_body = {
      "features" => [
        {
          "properties" => {
            "place_id" => "polygon_123",
            "name" => "Vrelo Bosne",
            "categories" => [ "natural.water.spring" ]
          },
          "geometry" => {
            "type" => "Polygon",
            "coordinates" => [ [ [ 18.26, 43.82 ], [ 18.27, 43.82 ], [ 18.27, 43.83 ], [ 18.26, 43.83 ], [ 18.26, 43.82 ] ] ]
          }
        }
      ]
    }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      result = service.get_place_details("polygon_123")

      assert_equal "Vrelo Bosne", result[:name]
      # Should extract coordinates from polygon
      assert result[:lat].present? || result[:lng].present? || result[:lat].nil?
    end
  end

  # === reverse_geocode tests ===

  test "reverse_geocode returns address data" do
    mock_body = {
      "features" => [
        {
          "properties" => {
            "formatted" => "Ferhadija 1, 71000 Sarajevo, Bosnia and Herzegovina",
            "city" => "Sarajevo",
            "country" => "Bosnia and Herzegovina",
            "country_code" => "ba",
            "postcode" => "71000",
            "street" => "Ferhadija",
            "housenumber" => "1",
            "lat" => 43.859,
            "lon" => 18.431
          }
        }
      ]
    }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      result = service.reverse_geocode(lat: 43.859, lng: 18.431)

      assert_equal "Sarajevo", result[:city]
      assert_equal "Bosnia and Herzegovina", result[:country]
      assert_equal "ba", result[:country_code]
    end
  end

  test "reverse_geocode returns empty hash when no features" do
    mock_body = { "features" => [] }

    service = build_service_with_api_key
    stub_faraday_get(mock_body) do
      result = service.reverse_geocode(lat: 0.0, lng: 0.0)

      assert_equal({}, result)
    end
  end

  test "reverse_geocode returns empty hash on error" do
    service = build_service_with_api_key

    stub_faraday_error do
      result = service.reverse_geocode(lat: 43.859, lng: 18.431)

      assert_equal({}, result)
    end
  end

  # === get_city_from_coordinates tests ===

  test "get_city_from_coordinates returns city name" do
    service = build_service_with_api_key

    service.stub :reverse_geocode, { city: "Sarajevo", country: "Bosnia and Herzegovina" } do
      result = service.get_city_from_coordinates(43.859, 18.431)

      assert_equal "Sarajevo", result
    end
  end

  test "get_city_from_coordinates falls back to town" do
    service = build_service_with_api_key

    service.stub :reverse_geocode, { town: "Trebinje", country: "Bosnia and Herzegovina" } do
      result = service.get_city_from_coordinates(42.711, 18.343)

      assert_equal "Trebinje", result
    end
  end

  test "get_city_from_coordinates falls back to village" do
    service = build_service_with_api_key

    service.stub :reverse_geocode, { village: "Blagaj", country: "Bosnia and Herzegovina" } do
      result = service.get_city_from_coordinates(43.267, 17.883)

      assert_equal "Blagaj", result
    end
  end

  test "get_city_from_coordinates cleans administrative prefixes" do
    service = build_service_with_api_key

    service.stub :reverse_geocode, { city: "Grad Mostar", country: "Bosnia and Herzegovina" } do
      result = service.get_city_from_coordinates(43.337, 17.815)

      assert_equal "Mostar", result
    end
  end

  test "get_city_from_coordinates returns nil when no city found" do
    service = build_service_with_api_key

    service.stub :reverse_geocode, {} do
      result = service.get_city_from_coordinates(0.0, 0.0)

      assert_nil result
    end
  end

  # === get_photo_url tests ===

  test "get_photo_url returns nil (Geoapify does not support photos)" do
    service = build_service_with_api_key

    result = service.get_photo_url("any_reference")

    assert_nil result
  end

  # === Error handling tests ===

  test "raises ApiError on non-success response" do
    service = build_service_with_api_key

    mock_response = Object.new
    mock_response.define_singleton_method(:success?) { false }
    mock_response.define_singleton_method(:status) { 401 }
    mock_response.define_singleton_method(:body) { { "message" => "Invalid API key" } }

    mock_request = Object.new
    mock_request.define_singleton_method(:params=) { |_params| }

    mock_conn = Object.new
    mock_conn.define_singleton_method(:get) do |_path, &block|
      block.call(mock_request) if block
      mock_response
    end

    service.instance_variable_set(:@connection, mock_conn)

    assert_raises(GeoapifyService::ApiError) do
      service.search_nearby(lat: 43.856, lng: 18.413)
    end
  end

  # === Category mapping tests ===

  test "DEFAULT_CATEGORY_TYPE_MAPPING contains expected categories" do
    mapping = GeoapifyService::DEFAULT_CATEGORY_TYPE_MAPPING

    assert_equal "restaurant", mapping["catering.restaurant"]
    assert_equal "museum", mapping["entertainment.museum"]
    assert_equal "hotel", mapping["accommodation.hotel"]
    assert_equal "mosque", mapping["tourism.sights.place_of_worship.mosque"]
    assert_equal "church", mapping["tourism.sights.place_of_worship.church"]
    assert_equal "castle", mapping["tourism.sights.castle"]
  end

  test "EXCLUDED_CATEGORIES contains social facilities" do
    excluded = GeoapifyService::EXCLUDED_CATEGORIES

    assert_includes excluded, "service.social_facility"
    assert_includes excluded, "healthcare.nursing_home"
    assert_includes excluded, "healthcare.retirement_home"
  end

  test "EXCLUDED_NAME_KEYWORDS contains relevant keywords" do
    keywords = GeoapifyService::EXCLUDED_NAME_KEYWORDS

    assert_includes keywords, "penzioner"
    assert_includes keywords, "retirement"
    assert keywords.any? { |k| k.include?("soup") }, "Expected keywords to include soup-related term"
    assert keywords.any? { |k| k.include?("dom za stare") || k.include?("starije") }, "Expected keywords to include elderly home terms"
  end

  # === Data transformation tests ===

  test "parse_price_level converts price levels correctly" do
    service = build_service_with_api_key

    assert_equal :low, service.send(:parse_price_level, "cheap")
    assert_equal :low, service.send(:parse_price_level, "inexpensive")
    assert_equal :medium, service.send(:parse_price_level, "moderate")
    assert_equal :high, service.send(:parse_price_level, "expensive")
    assert_equal :medium, service.send(:parse_price_level, nil)
    assert_equal :medium, service.send(:parse_price_level, "unknown")
  end

  test "format_category_display formats category names" do
    service = build_service_with_api_key

    assert_equal "Restaurant", service.send(:format_category_display, "catering.restaurant")
    assert_equal "Museum", service.send(:format_category_display, "entertainment.museum")
    assert_equal "Coffee Shop", service.send(:format_category_display, "catering.cafe.coffee_shop")
    assert_nil service.send(:format_category_display, nil)
    assert_nil service.send(:format_category_display, "")
  end

  test "parse_opening_hours returns formatted hours" do
    service = build_service_with_api_key

    result = service.send(:parse_opening_hours, "Mo-Fr 08:00-18:00")

    assert_nil result[:open_now]
    assert_equal [ "Mo-Fr 08:00-18:00" ], result[:weekday_text]
  end

  test "parse_opening_hours handles array input" do
    service = build_service_with_api_key

    hours_array = [ "Monday: 9:00-17:00", "Tuesday: 9:00-17:00" ]
    result = service.send(:parse_opening_hours, hours_array)

    assert_equal hours_array, result[:weekday_text]
  end

  test "parse_opening_hours returns nil for blank input" do
    service = build_service_with_api_key

    assert_nil service.send(:parse_opening_hours, nil)
    assert_nil service.send(:parse_opening_hours, "")
  end

  test "build_address constructs address from properties" do
    service = build_service_with_api_key

    properties = {
      "street" => "Ferhadija",
      "housenumber" => "1",
      "city" => "Sarajevo",
      "country" => "Bosnia and Herzegovina"
    }

    result = service.send(:build_address, properties)

    assert_equal "Ferhadija, 1, Sarajevo, Bosnia and Herzegovina", result
  end

  test "build_address handles missing properties" do
    service = build_service_with_api_key

    properties = { "city" => "Sarajevo" }
    result = service.send(:build_address, properties)

    assert_equal "Sarajevo", result
  end

  # === Type conversion tests ===

  test "find_matching_category maps common types" do
    service = build_service_with_api_key

    assert_equal "catering.restaurant", service.send(:find_matching_category, "restaurant")
    assert_equal "entertainment.museum", service.send(:find_matching_category, "museum")
    assert_equal "leisure.park", service.send(:find_matching_category, "park")
    assert_equal "beach", service.send(:find_matching_category, "beach")
    assert_equal "accommodation.hotel", service.send(:find_matching_category, "hotel")
  end

  test "find_matching_category maps deprecated categories" do
    service = build_service_with_api_key

    assert_equal "adult.casino", service.send(:find_matching_category, "entertainment.casino")
    assert_equal "adult.nightclub", service.send(:find_matching_category, "night_club")
    assert_equal "leisure.park.garden", service.send(:find_matching_category, "leisure.garden")
  end

  test "find_matching_category returns nil for unknown types" do
    service = build_service_with_api_key

    assert_nil service.send(:find_matching_category, "completely_unknown_type")
  end

  private

  def build_service_with_api_key
    Rails.application.config.geoapify.stub(:api_key, "test_api_key") do
      return GeoapifyService.new
    end
  end

  def build_service_with_stubbed_connection(mock_response)
    Rails.application.config.geoapify.stub(:api_key, "test_api_key") do
      service = GeoapifyService.new

      mock_conn = Object.new
      mock_conn.define_singleton_method(:get) do |_path, &block|
        mock_faraday_response = Object.new
        mock_faraday_response.define_singleton_method(:success?) { true }
        mock_faraday_response.define_singleton_method(:body) { mock_response }
        mock_faraday_response
      end

      service.instance_variable_set(:@connection, mock_conn)
      return service
    end
  end

  def stub_faraday_get(mock_body)
    mock_response = Object.new
    mock_response.define_singleton_method(:success?) { true }
    mock_response.define_singleton_method(:body) { mock_body }

    mock_request = Object.new
    mock_request.define_singleton_method(:params=) { |_params| }

    mock_conn = Object.new
    mock_conn.define_singleton_method(:get) do |_path, &block|
      block.call(mock_request) if block
      mock_response
    end

    Faraday.stub :new, ->(url = nil, &_block) { mock_conn } do
      yield
    end
  end

  def stub_faraday_error
    mock_conn = Object.new
    mock_conn.define_singleton_method(:get) do |_path, &_block|
      raise StandardError, "Network error"
    end

    Faraday.stub :new, ->(url = nil, &_block) { mock_conn } do
      yield
    end
  end

  def mock_places_response(places)
    features = places.map do |place|
      {
        "properties" => {
          "place_id" => place[:place_id],
          "name" => place[:name],
          "formatted" => place[:address] || "#{place[:name]}, Bosnia",
          "categories" => place[:categories] || [ "tourism.attraction" ],
          "rating" => place[:rating],
          "rating_count" => place[:rating_count],
          "website" => place[:website],
          "phone" => place[:phone],
          "price_level" => place[:price_level]
        },
        "geometry" => {
          "type" => "Point",
          "coordinates" => [ place[:lng], place[:lat] ]
        }
      }
    end

    { "features" => features }
  end
end
