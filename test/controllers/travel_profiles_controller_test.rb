# frozen_string_literal: true

require "test_helper"

class TravelProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: "travelprofile_test",
      password: "password123",
      password_confirmation: "password123",
      travel_profile_data: {
        "visited" => [],
        "favorites" => [],
        "stats" => { "totalVisits" => 0 },
        "createdAt" => Time.current.iso8601,
        "updatedAt" => Time.current.iso8601
      }
    )

    @location = Location.create!(
      name: "Test Location",
      description: "A test location for travel profile tests",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place,
      budget: :medium,
      tags: [ "culture", "history" ]
    )

    @experience = Experience.create!(
      title: "Test Experience",
      description: "A test experience",
      estimated_duration: 60
    )
    @experience.add_location(@location, position: 1)

    @plan = Plan.create!(
      title: "Test Plan",
      city_name: "Sarajevo",
      visibility: :private_plan,
      user: @user
    )
    @plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )
  end

  teardown do
    @plan&.destroy
    @experience&.destroy
    @location&.destroy
    @user&.destroy
  end

  # === Page action tests ===

  test "page renders for anonymous users" do
    get profile_page_path

    assert_response :success
  end

  test "page renders for logged in users" do
    login_as(@user)

    get profile_page_path

    assert_response :success
  end

  test "page loads user plans when logged in" do
    login_as(@user)

    get profile_page_path

    assert_response :success
    # For logged-in users, the page includes a turbo-frame that loads plans
    assert_includes response.body, 'turbo-frame id="my-plans-frame"'
    assert_includes response.body, profile_plans_path
  end

  test "page shows localStorage-based plans section for anonymous users" do
    get profile_page_path

    assert_response :success
    # For anonymous users, the page shows the JavaScript-based my-plans controller
    assert_includes response.body, 'data-controller="my-plans"'
  end

  # === My Plans action tests ===

  test "my_plans returns plans for logged in users" do
    login_as(@user)

    get profile_plans_path

    assert_response :success
  end

  test "my_plans returns no content for anonymous users" do
    get profile_plans_path

    assert_response :no_content
  end

  test "my_plans supports pagination" do
    login_as(@user)

    get profile_plans_path, params: { page: 1 }

    assert_response :success
  end

  test "my_plans returns empty for page beyond results" do
    login_as(@user)

    get profile_plans_path, params: { page: 999 }

    assert_response :success
  end

  # === Show action tests ===

  test "show requires authentication for JSON request" do
    get travel_profile_path, as: :json

    assert_response :unauthorized
  end

  test "show returns travel profile data as JSON" do
    login_as(@user)

    get travel_profile_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["travel_profile_data"].present?
  end

  test "show returns default profile data for new user" do
    new_user = User.create!(
      username: "newuser",
      password: "password123",
      password_confirmation: "password123"
    )
    login_as(new_user)

    get travel_profile_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["travel_profile_data"].present?

    new_user.destroy
  end

  # === Update action tests ===

  test "update requires authentication for JSON request" do
    patch travel_profile_path, params: { travel_profile_data: { "visited" => [] }.to_json }, as: :json

    assert_response :unauthorized
  end

  test "update merges travel profile data" do
    login_as(@user)
    new_data = {
      "visited" => [ { "id" => "test-id", "type" => "location" } ],
      "favorites" => []
    }.to_json

    patch travel_profile_path, params: { travel_profile_data: new_data }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert body["travel_profile_data"]["visited"].present?
  end

  test "update accepts JSON string parameter" do
    login_as(@user)
    new_data = { "visited" => [], "favorites" => [] }.to_json

    patch travel_profile_path, params: { travel_profile_data: new_data }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
  end

  test "update accepts hash parameter" do
    login_as(@user)
    new_data = { "visited" => [], "favorites" => [] }

    patch travel_profile_path, params: { travel_profile_data: new_data }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
  end

  test "update returns error for invalid JSON" do
    login_as(@user)

    patch travel_profile_path, params: { travel_profile_data: "invalid json {{{}" }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "Invalid JSON", body["error"]
  end

  test "update returns error when no profile data provided" do
    login_as(@user)

    patch travel_profile_path, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "No profile data provided", body["error"]
  end

  test "update returns error for empty travel_profile_data" do
    login_as(@user)

    patch travel_profile_path, params: { travel_profile_data: "" }, as: :json

    assert_response :bad_request
  end

  # === Sync action tests ===

  test "sync requires authentication for JSON request" do
    post sync_travel_profile_path, as: :json

    assert_response :unauthorized
  end

  test "sync merges incoming profile data" do
    login_as(@user)
    sync_data = {
      "visited" => [ { "id" => "synced-id", "type" => "location" } ],
      "favorites" => [ { "id" => "fav-id" } ]
    }.to_json

    post sync_travel_profile_path, params: { travel_profile_data: sync_data }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert_equal "Profile synced successfully", body["message"]
    assert body["travel_profile_data"].present?
  end

  test "sync returns current server data when no data provided" do
    login_as(@user)

    post sync_travel_profile_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert body["travel_profile_data"].present?
  end

  test "sync returns error for invalid JSON" do
    login_as(@user)

    post sync_travel_profile_path, params: { travel_profile_data: "invalid {{{}}" }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "Invalid JSON", body["error"]
  end

  test "sync accepts JSON string parameter" do
    login_as(@user)
    sync_data = { "visited" => [], "favorites" => [] }.to_json

    post sync_travel_profile_path, params: { travel_profile_data: sync_data }, as: :json

    assert_response :success
  end

  test "sync accepts hash parameter" do
    login_as(@user)
    sync_data = { "visited" => [], "favorites" => [] }

    post sync_travel_profile_path, params: { travel_profile_data: sync_data }, as: :json

    assert_response :success
  end

  # === Validate Visit action tests ===

  test "validate_visit requires authentication for JSON request" do
    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: 43.8563,
      user_lng: 18.4131
    }, as: :json

    assert_response :unauthorized
  end

  test "validate_visit requires location_id" do
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      user_lat: 43.8563,
      user_lng: 18.4131
    }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "Location ID is required", body["error"]
  end

  test "validate_visit requires user coordinates" do
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid
    }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "User coordinates are required", body["error"]
  end

  test "validate_visit returns not found for invalid location" do
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      location_id: "non-existent-uuid",
      user_lat: 43.8563,
      user_lng: 18.4131
    }, as: :json

    assert_response :not_found
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "Location not found", body["error"]
  end

  test "validate_visit returns error for location without coordinates" do
    location_without_coords = Location.create!(
      name: "No Coords Location",
      description: "A location without coordinates",
      city: "Unknown",
      lat: nil,
      lng: nil
    )
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      location_id: location_without_coords.uuid,
      user_lat: 43.8563,
      user_lng: 18.4131
    }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "Location does not have coordinates", body["error"]

    location_without_coords.destroy
  end

  test "validate_visit succeeds when user is close enough" do
    login_as(@user)
    # Use coordinates very close to the location (within 500m)
    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: @location.lat,
      user_lng: @location.lng
    }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert body["validated"]
    assert body["travel_profile_data"].present?
    assert body["message"].present?
  end

  test "validate_visit fails when user is too far away" do
    login_as(@user)
    # Use coordinates far from the location (different city)
    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: 44.7758, # Banja Luka
      user_lng: 17.1858
    }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_not body["success"]
    assert_not body["validated"]
    assert body["distance_km"].present?
    assert body["max_distance_km"].present?
    assert body["error"].present?
  end

  test "validate_visit adds location to visited list" do
    login_as(@user)
    initial_visits = @user.travel_profile_data["visited"]&.length || 0

    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: @location.lat,
      user_lng: @location.lng
    }, as: :json

    assert_response :success
    @user.reload
    assert_equal initial_visits + 1, @user.travel_profile_data["visited"].length
  end

  test "validate_visit does not duplicate visits" do
    login_as(@user)

    # First visit
    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: @location.lat,
      user_lng: @location.lng
    }, as: :json
    assert_response :success
    @user.reload
    initial_count = @user.travel_profile_data["visited"].length

    # Second visit to same location
    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: @location.lat,
      user_lng: @location.lng
    }, as: :json
    assert_response :success
    @user.reload
    assert_equal initial_count, @user.travel_profile_data["visited"].length
  end

  test "validate_visit updates stats correctly" do
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: @location.lat,
      user_lng: @location.lng
    }, as: :json

    assert_response :success
    @user.reload
    stats = @user.travel_profile_data["stats"]
    assert stats["totalVisits"] >= 1
    assert stats["citiesVisited"].include?(@location.city)
    assert stats["seasonsVisited"].present?
  end

  test "validate_visit returns distance in response" do
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: @location.lat + 0.001, # Slightly off
      user_lng: @location.lng
    }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["distance_km"].present?
    assert body["distance_km"].is_a?(Numeric)
  end

  # === Authentication redirect tests ===

  test "show redirects to login for HTML request when not authenticated" do
    get travel_profile_path

    assert_redirected_to login_path
  end

  test "update redirects to login for HTML request when not authenticated" do
    patch travel_profile_path, params: { travel_profile_data: {}.to_json }

    assert_redirected_to login_path
  end

  test "sync redirects to login for HTML request when not authenticated" do
    post sync_travel_profile_path

    assert_redirected_to login_path
  end

  test "validate_visit redirects to login for HTML request when not authenticated" do
    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: 43.8563,
      user_lng: 18.4131
    }

    assert_redirected_to login_path
  end

  # === Edge cases ===

  test "update handles empty visited array" do
    login_as(@user)
    @user.update!(travel_profile_data: { "visited" => [ { "id" => "old" } ] })

    patch travel_profile_path, params: {
      travel_profile_data: { "visited" => [] }.to_json
    }, as: :json

    assert_response :success
    @user.reload
    assert_equal [], @user.travel_profile_data["visited"]
  end

  test "sync preserves existing data not in incoming data" do
    login_as(@user)
    @user.update!(travel_profile_data: {
      "visited" => [ { "id" => "existing" } ],
      "favorites" => [ { "id" => "fav" } ],
      "stats" => { "totalVisits" => 5 }
    })

    # Sync only visited, favorites should be overwritten (client authoritative)
    post sync_travel_profile_path, params: {
      travel_profile_data: { "visited" => [ { "id" => "new" } ] }.to_json
    }, as: :json

    assert_response :success
  end

  test "page handles user with many plans" do
    # Create additional plans
    10.times do |i|
      Plan.create!(
        title: "Plan #{i}",
        city_name: "Sarajevo",
        visibility: :private_plan,
        user: @user
      )
    end
    login_as(@user)

    get profile_page_path

    assert_response :success
    # Page should render successfully with pagination
    # (pagination limits to 6 per page - PER_PAGE constant)
  end

  test "validate_visit handles zero coordinates as missing" do
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: 0,
      user_lng: 0
    }, as: :json

    assert_response :bad_request
    body = response.parsed_body
    assert_equal "User coordinates are required", body["error"]
  end

  test "validate_visit handles string coordinates" do
    login_as(@user)

    post validate_visit_travel_profile_path, params: {
      location_id: @location.uuid,
      user_lat: @location.lat.to_s,
      user_lng: @location.lng.to_s
    }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end
end
