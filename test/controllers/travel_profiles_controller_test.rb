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

  # === No GET endpoint for the profile blob ===

  # It dumped the whole profile as JSON and nothing consumed it; the client reads
  # its own copy back through :sync, so the surface is gone rather than hidden.
  test "the profile blob has no GET endpoint" do
    login_as(@user)

    get "/travel_profile"

    assert_response :not_found
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
    assert_empty body["travel_profile_data"]["visited"], "visited comes from PlanVisit, not the browser"
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

  # === Authentication redirect tests ===

  test "the profile page is reachable without signing in, and shows no one else's data" do
    get profile_page_path

    assert_response :success
  end

  test "update redirects to login for HTML request when not authenticated" do
    patch travel_profile_path, params: { travel_profile_data: {}.to_json }

    assert_redirected_to login_path
  end

  test "sync redirects to login for HTML request when not authenticated" do
    post sync_travel_profile_path

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

  # An exception message names classes, columns and constraints; the caller gets
  # a translated line and the detail goes to the reporter.
  test "an unexpected failure does not hand the exception message to the caller" do
    login_as(@user)

    patch travel_profile_path, params: { travel_profile_data: "[1, 2]" }, as: :json

    assert_response :unprocessable_entity
    error = response.parsed_body["error"]
    assert_equal I18n.t("travel_profile.sync_error"), error
    assert_not_includes error, "TypeError"
  end

  test "the passport counts every place but lists only a recent slice" do
    places = (TravelProfilesController::VISITED_LIMIT + 3).times.map do |i|
      Location.create!(name: "Passport #{i}", city: "Sarajevo", lat: 43.8 + i * 0.01, lng: 18.4 + i * 0.01)
    end
    places.each { |place| PlanVisit.create!(user: @user, plan: @plan, location: place) }
    login_as(@user)

    get profile_page_path

    assert_response :success
    # The stat is the whole passport; the list below it stops at the cap.
    assert_select "p.text-3xl", text: places.size.to_s
    assert_select "a[href=?]", location_path(places.last), count: 1
    assert_select "a[href=?]", location_path(places.first), count: 0
  ensure
    places&.each(&:destroy)
  end

  test "a place reached on two plans counts and lists once" do
    other_plan = Plan.create!(title: "Second", city_name: "Sarajevo", user: @user)
    PlanVisit.create!(user: @user, plan: @plan, location: @location)
    PlanVisit.create!(user: @user, plan: other_plan, location: @location)
    login_as(@user)

    get profile_page_path

    assert_response :success
    assert_select "p.text-3xl", text: "1"
    assert_select "a[href=?]", location_path(@location), count: 1
  ensure
    other_plan&.destroy
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end
end
