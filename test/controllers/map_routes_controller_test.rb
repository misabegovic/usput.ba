# frozen_string_literal: true

require "test_helper"

class MapRoutesControllerTest < ActionDispatch::IntegrationTest
  VALID = { from_lat: 43.85, from_lng: 18.41, to_lat: 43.86, to_lng: 18.42 }.freeze

  test "missing or malformed coordinates are rejected" do
    get map_route_path
    assert_response :bad_request

    get map_route_path, params: VALID.merge(from_lat: "abc")
    assert_response :bad_request

    get map_route_path, params: VALID.merge(to_lat: 91)
    assert_response :bad_request
  end

  test "without an API key the endpoint reports unavailable" do
    original = ENV.delete("OPENROUTESERVICE_API_KEY")

    get map_route_path, params: VALID

    assert_response :service_unavailable
  ensure
    ENV["OPENROUTESERVICE_API_KEY"] = original if original
  end

  test "a fetched route is returned as JSON and cached" do
    ENV["OPENROUTESERVICE_API_KEY"] = "test-key"
    route = { points: [ [ 43.85, 18.41 ], [ 43.86, 18.42 ] ], distance_m: 1500, duration_s: 1080 }
    calls = 0
    fetcher = lambda do |**|
      calls += 1
      route
    end

    Rails.cache.clear
    Maps::RouteFetcher.stub :call, fetcher do
      get map_route_path, params: VALID
      assert_response :success
      assert_equal 1500, response.parsed_body["distance_m"]

      get map_route_path, params: VALID
      assert_response :success
    end

    assert_equal 1, calls if Rails.cache.class.name != "ActiveSupport::Cache::NullStore"
  ensure
    ENV.delete("OPENROUTESERVICE_API_KEY")
    Rails.cache.clear
  end

  test "an engine failure surfaces as bad gateway" do
    ENV["OPENROUTESERVICE_API_KEY"] = "test-key"

    Rails.cache.clear
    Maps::RouteFetcher.stub :call, nil do
      get map_route_path, params: VALID.merge(to_lng: 18.43)
    end

    assert_response :bad_gateway
  ensure
    ENV.delete("OPENROUTESERVICE_API_KEY")
    Rails.cache.clear
  end
end
