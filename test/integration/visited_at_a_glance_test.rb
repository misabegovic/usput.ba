# frozen_string_literal: true

require "test_helper"

# A traveller should be able to see their own state without opening anything:
# visited places are marked on the cards, and the location page carries the
# moments surface.
class VisitedAtAGlanceTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "glance_user", password: "password123")
    @visited = Location.create!(name: "Been Here Fort", city: "Sarajevo", lat: 43.85, lng: 18.41)
    @unvisited = Location.create!(name: "Not Yet Fort", city: "Sarajevo", lat: 43.86, lng: 18.42)
    @plan = Plan.create!(title: "Trip", visibility: :private_plan, user: @user)
    @user.plan_visits.create!(plan: @plan, location: @visited)
  end

  teardown do
    @user&.destroy
    [ @visited, @unvisited ].each { |location| location&.destroy }
  end

  test "a guest sees no visited marking" do
    get explore_path(q: "Fort", type: "location")

    assert_response :success
    assert_select "a[href=?].ring-2", location_path(@visited), count: 0
  end

  test "the visited marking costs one query no matter how many cards" do
    login_as(@user)
    get explore_path(q: "Fort", type: "location") # warm

    count = 0
    counter = ->(_a, _b, _c, _d, payload) { count += 1 if payload[:sql]&.include?("plan_visits") && !payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get explore_path(q: "Fort", type: "location")
    end

    assert_operator count, :<=, 1, "expected the visited set to be fetched once, was #{count}"
  end

  test "the location page carries a lazy moments frame for a logged-in traveller" do
    login_as(@user)

    get location_path(@visited)

    assert_response :success
    assert_select "turbo-frame[id=?][loading='lazy']",
                  ActionView::RecordIdentifier.dom_id(@visited, :moments_frame), count: 1
  end

  test "a guest sees a place's moments too, on the plan-free route" do
    get location_path(@visited)

    assert_response :success
    assert_select "turbo-frame[id=?][loading='lazy']",
                  ActionView::RecordIdentifier.dom_id(@visited, :moments_frame), count: 1
    assert_select "turbo-frame[src=?]",
                  location_moments_path(@visited.uuid, context: "location"), count: 1
  end

  test "a guest reads a place's public moments without a plan" do
    get location_moments_path(@visited.uuid, context: "location")

    assert_response :success
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end
end
