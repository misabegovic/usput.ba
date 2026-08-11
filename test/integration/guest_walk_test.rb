# frozen_string_literal: true

require "test_helper"

# A traveller with no account browses, walks explore mode and marks places as
# they go; the walk is held on their device and joins their account the moment
# they sign in. Only uploading a moment asks them to log in.
class GuestWalkTest < ActionDispatch::IntegrationTest
  SARAJEVO = { lat: 43.85, lng: 18.41 }.freeze

  setup do
    @history = ExperienceType.create!(key: "history", name: "History", active: true)
    @location = Location.create!(name: "Guest Fort", city: "Sarajevo", lat: 43.85, lng: 18.41,
                                 suitable_experiences: [ @history.key ])
  end

  teardown do
    @location&.destroy
    @history&.destroy
  end

  test "a guest reaches the deck without being sent to the login page" do
    get explore_bosnia_experience_path("history", **SARAJEVO)

    assert_response :success
    assert_includes response.body, "Guest Fort"
  end

  test "a guest reads a place's moments without a plan" do
    get location_moments_path(@location.uuid)

    assert_response :success
  end

  test "a guest is offered sign-in where a moment would be uploaded" do
    get location_moments_path(@location.uuid)

    assert_response :success
    assert_select "a[href*=?]", login_path, true, "the upload tile should invite sign-in"
    assert_select "input[type='file']", count: 0, message: "a guest gets no upload field"
  end

  test "uploading a moment is refused without an account" do
    plan = Plan.create!(title: "Public walk", visibility: :public_plan)

    assert_no_difference "Moment.count" do
      post plan_moments_path(plan), params: { moment: { location_id: @location.uuid } }
    end

    assert_redirected_to login_path
  ensure
    plan&.destroy
  end

  test "signing in turns the device's check-ins into visits on the explore plan" do
    user = User.create!(username: "arriving", password: "password123")

    post login_path, params: {
      username: user.username, password: "password123",
      travel_profile_data: { "visited" => [ { "id" => @location.uuid, "type" => "location" } ] }.to_json
    }

    plan = Plan.explore_bosnia_for(user)
    assert_equal [ @location.id ], user.plan_visits.where(plan: plan).pluck(:location_id)
  ensure
    user&.destroy
  end

  test "signing up carries the walk across too" do
    assert_difference "PlanVisit.count", 1 do
      post register_path, params: {
        user: { username: "fresh", password: "password123", password_confirmation: "password123" },
        travel_profile_data: { "visited" => [ { "id" => @location.uuid, "type" => "location" } ] }.to_json
      }
    end

    user = User.find_by(username: "fresh")
    assert_equal [ @location.id ], user.plan_visits.pluck(:location_id)
  ensure
    User.find_by(username: "fresh")&.destroy
  end

  # The importer writes its rows with a bulk insert, so it never went near the
  # counters. It no longer has to: they are read from the rows it wrote.
  test "a walk carried in at the door is counted" do
    user = User.create!(username: "counted", password: "password123")

    post login_path, params: {
      username: user.username, password: "password123",
      travel_profile_data: { "visited" => [ { "id" => @location.uuid, "type" => "location" } ] }.to_json
    }

    stats = user.reload.travel_profile_data["stats"]
    assert_equal 1, stats["totalVisits"]
    assert_includes stats["citiesVisited"], "Sarajevo"
  ensure
    user&.destroy
  end

  test "signing in from a browser holding no profile leaves the account's favourites" do
    user = User.create!(username: "favouriting", password: "password123")
    user.merge_travel_profile({ "favorites" => [ { "id" => @location.uuid, "type" => "location" } ] })

    post login_path, params: {
      username: user.username, password: "password123",
      travel_profile_data: { "visited" => [], "favorites" => [] }.to_json
    }

    assert_equal [ @location.uuid ], user.reload.travel_profile_data["favorites"].map { |item| item["id"] }
  ensure
    user&.destroy
  end

  test "signing in carries a plan built without an account" do
    user = User.create!(username: "planner", password: "password123")

    assert_difference "user.plans.count", 1 do
      post login_path, params: {
        username: user.username, password: "password123",
        plans_data: [ { "city_name" => "Sarajevo", "duration_days" => 2 } ].to_json
      }
    end
  ensure
    user&.destroy
  end

  test "signing in with nothing held on the device changes nothing" do
    user = User.create!(username: "empty_handed", password: "password123")

    assert_no_difference "PlanVisit.count" do
      post login_path, params: { username: user.username, password: "password123" }
    end
  ensure
    user&.destroy
  end

  test "the profile sync cannot add a visit once the traveller is signed in" do
    user = User.create!(username: "already_in", password: "password123")
    post login_path, params: { username: user.username, password: "password123" }

    assert_no_difference "PlanVisit.count" do
      post sync_travel_profile_path, params: {
        travel_profile_data: { "visited" => [ { "id" => @location.uuid, "type" => "location" } ] }.to_json
      }
    end
  ensure
    user&.destroy
  end

  # The device's list is the one check-in path that cannot re-verify the 100 m
  # gate, so it is spent once. Replaying it every sign-in would let a traveller
  # mark the whole country visited by signing out and back in.
  test "a second sign-in cannot replay the device's list" do
    user = User.create!(username: "replaying", password: "password123")
    second = Location.create!(name: "Second Fort", city: "Mostar", lat: 43.34, lng: 17.81,
                              suitable_experiences: [ @history.key ])
    walk = { "visited" => [ { "id" => @location.uuid, "type" => "location" } ] }.to_json

    post login_path, params: { username: user.username, password: "password123", travel_profile_data: walk }
    delete logout_path

    assert_no_difference "PlanVisit.count" do
      post login_path, params: {
        username: user.username, password: "password123",
        travel_profile_data: { "visited" => [ { "id" => second.uuid, "type" => "location" } ] }.to_json
      }
    end

    assert_equal [ @location.id ], user.plan_visits.pluck(:location_id)
  ensure
    second&.destroy
    user&.destroy
  end

  test "a traveller who already checked in is not importable from the device" do
    user = User.create!(username: "established", password: "password123")
    user.plan_visits.create!(plan: Plan.explore_bosnia_for(user), location: @location)
    other = Location.create!(name: "Far Fort", city: "Bihać", lat: 44.81, lng: 15.87,
                             suitable_experiences: [ @history.key ])

    assert_no_difference "PlanVisit.count" do
      post login_path, params: {
        username: user.username, password: "password123",
        travel_profile_data: { "visited" => [ { "id" => other.uuid, "type" => "location" } ] }.to_json
      }
    end
  ensure
    other&.destroy
    user&.destroy
  end

  test "a bad password imports nothing, even with visits attached" do
    user = User.create!(username: "wrong_key", password: "password123")

    assert_no_difference "PlanVisit.count" do
      post login_path, params: {
        username: user.username, password: "not-the-password",
        travel_profile_data: { "visited" => [ { "id" => @location.uuid, "type" => "location" } ] }.to_json
      }
    end
  ensure
    user&.destroy
  end

  test "a signed-in traveller reading a place outside a plan can still upload" do
    user = User.create!(username: "browsing", password: "password123")
    post login_path, params: { username: user.username, password: "password123" }

    get location_moments_path(@location.uuid)

    assert_response :success
    assert_select "input[type='file']", minimum: 1
  ensure
    user&.destroy
  end
end
