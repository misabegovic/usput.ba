# frozen_string_literal: true

require "test_helper"

# The "start a plan" walk: a plan renders its locations as steps. A step starts
# as "I was here"; marking it visited persists (server-owned, per-user) and
# swaps in the moment capture. Progress survives leaving and returning.
class PlanStartTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "walker", password: "password123")
    @location = Location.create!(name: "Walk Loc", city: "Sarajevo", lat: 43.85, lng: 18.41)
    @experience = Experience.create!(title: "Walk Exp", description: "desc")
    @experience.locations << @location
    @plan = Plan.create!(title: "Walk Plan", city_name: "Sarajevo", visibility: :private_plan, user: @user)
    @plan.plan_experiences.create!(experience: @experience, day_number: 1)
  end

  teardown do
    @plan&.destroy
    @experience&.destroy
    @location&.destroy
    @user&.destroy
  end

  test "the plan page links to the start walk" do
    login_as(@user)

    get plan_path(@plan)

    assert_response :success
    assert_select "a[href=?]", start_plan_path(@plan), count: 1
  end

  test "an unvisited step offers to mark visited; capture lives in the stories" do
    login_as(@user)

    get start_plan_path(@plan)

    assert_response :success
    assert_select "form[action=?]", plan_visits_path(@plan), count: @plan.all_locations.size
    # the upload form arrives with the moments panel — one lazy frame per card
    assert_select "turbo-frame[id^='moments_frame_'][loading='lazy']", count: @plan.all_locations.size
  end

  test "marking a step visited persists it and reveals the capture" do
    login_as(@user)

    post plan_visits_path(@plan), params: { location_id: @location.uuid, user_lat: @location.lat, user_lng: @location.lng }, as: :turbo_stream

    assert_response :success
    assert @user.plan_visits.exists?(plan: @plan, location: @location), "the visit must be recorded"
    assert_select "turbo-stream[action=replace][target=?]", ActionView::RecordIdentifier.dom_id(@location, :step)
    assert_select "turbo-stream[action=replace][target=?]",
                  ActionView::RecordIdentifier.dom_id(@location, :stories), count: 1,
                  msg: "the stories refresh alongside the step; capture is the + button outside the stream"
  end

  # A visit is permanent — it survives the delete of the plan it was made on, so
  # there is no route that takes one back either.
  test "there is no route that un-does a visit" do
    login_as(@user)
    @user.plan_visits.create!(plan: @plan, location: @location)

    delete "/plans/#{@plan.uuid}/visits/#{@location.uuid}"

    assert_response :not_found
    assert_equal 1, @user.plan_visits.count
  end

  test "visited progress survives leaving and returning to the walk" do
    @user.plan_visits.create!(plan: @plan, location: @location)
    login_as(@user)

    get start_plan_path(@plan)

    assert_response :success
    assert_select "form[action=?]", plan_visits_path(@plan), count: 0, msg: "already visited, so no I-was-here form"
    assert_select "turbo-frame[id^='moments_frame_'][loading='lazy']", count: 1, msg: "one moments frame per card"
  end

  test "capturing a photo on the walk adds it and shows it on the step" do
    login_as(@user)

    post plan_moments_path(@plan), params: {
      moment: {
        location_id: @location.uuid,
        photo: fixture_file_upload("test/fixtures/files/real_image.jpg", "image/jpeg")
      }
    }

    assert_equal 1, @user.moments.where(plan: @plan, location: @location).count

    moment = @user.moments.where(plan: @plan).last
    get plan_moments_path(@plan, location_id: @location.uuid, context: "walk"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@location, :moments_frame) }

    assert_response :success
    # a thumbnail in the panel; the story variant only loads with the lightbox
    assert_select "img[src=?]", photo_plan_moment_path(@plan, moment, size: "thumb"), count: 1
    assert_select "[data-photo-gallery-full-url=?]",
      photo_plan_moment_path(@plan, moment, size: "story"), count: 1
  end

  test "a guest walking a public plan is asked to log in, not to capture" do
    @plan.update!(visibility: :public_plan)

    get start_plan_path(@plan)

    assert_response :success
    assert_select "form[action=?]", plan_visits_path(@plan), count: 0
    assert_select "form[action=?]", plan_moments_path(@plan), count: 0
  end

  # A guest may look at a place's moments; capturing one is what needs an account,
  # so the tile signs them in and brings them back to the walk.
  test "a guest walking a public plan is offered sign-in from the moments panel" do
    @plan.update!(visibility: :public_plan)

    get start_plan_path(@plan)

    assert_response :success
    assert_select "turbo-frame[id^='moments_frame_']", count: 1

    get plan_moments_path(@plan, location_id: @location.uuid),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@location, :moments_frame),
                   "Referer" => start_plan_url(@plan) }

    assert_response :success
    assert_select "a[href=?][aria-label=?]",
                  login_path(return_to: start_plan_path(@plan)), I18n.t("plans.moments.add"), count: 1
  end

  test "signing in from a walk comes back to the walk" do
    @plan.update!(visibility: :public_plan)

    get login_path(return_to: start_plan_path(@plan))
    post login_path, params: { username: @user.username, password: "password123" }

    assert_redirected_to start_plan_path(@plan)
  end

  test "a return path pointing off the site is refused" do
    get login_path(return_to: "//evil.example.com")
    post login_path, params: { username: @user.username, password: "password123" }

    assert_redirected_to root_path
  end

  test "a guest cannot walk a private plan" do
    get start_plan_path(@plan)

    assert_redirected_to "/explore"
  end

  test "the walk renders a deck of location cards with the check-in relabelled" do
    login_as(@user)

    get start_plan_path(@plan)

    assert_response :success
    assert_select "div[data-controller=plan-deck]", count: 1
    assert_select "[data-plan-deck-target=card]", count: @plan.all_locations.size
    assert_includes response.body, "Check if I&#39;m here"
  end

  test "another traveller's private moment never surfaces as a shared moment on the walk" do
    stranger = User.create!(username: "stranger", password: "password123")
    Moment.create!(user: stranger, plan: @plan, location: @location,
                   photo: fixture_file_upload("test/fixtures/files/real_image.jpg", "image/jpeg"))
    login_as(@user)

    get start_plan_path(@plan)

    assert_response :success
    assert_select "[data-moment-lightbox-url]", count: 0,
      msg: "a private moment must not leak onto the card as a shared moment"
  ensure
    stranger&.destroy
  end

  test "an admin checks in from anywhere, so the walk can be reviewed remotely" do
    admin = User.create!(username: "chief_walker", password: "password123", user_type: :admin)
    admin_plan = Plan.create!(title: "Chief Plan", city_name: "Sarajevo", visibility: :private_plan, user: admin)
    admin_plan.plan_experiences.create!(experience: @experience, day_number: 1)
    login_as(admin)

    post plan_visits_path(admin_plan), params: { location_id: @location.uuid, user_lat: 40.0, user_lng: 10.0 }, as: :turbo_stream

    assert_response :success
    assert admin.plan_visits.exists?(plan: admin_plan, location: @location), "the admin bypass must record the visit"
  ensure
    admin_plan&.destroy
    admin&.destroy
  end

  test "a traveller is still held to the geofence" do
    login_as(@user)

    post plan_visits_path(@plan), params: { location_id: @location.uuid, user_lat: 40.0, user_lng: 10.0 }, as: :turbo_stream

    assert_response :success
    refute @user.plan_visits.exists?(plan: @plan, location: @location), "a check-in from 2000 km away must not count"
  end

  # These two moved here with `touch_visit_stats`, which used to live on the
  # location page's own check-in endpoint and so only ever fired on that one
  # surface. It belongs to recording a visit, whichever screen asked.
  test "checking in updates the profile's visit stats" do
    login_as(@user)

    post plan_visits_path(@plan), params: { location_id: @location.uuid, user_lat: @location.lat, user_lng: @location.lng }, as: :turbo_stream

    stats = @user.reload.travel_profile_data["stats"]
    assert_equal 1, stats["totalVisits"]
    assert_includes stats["citiesVisited"], @location.city
    assert_includes stats["seasonsVisited"], Location.current_season
  end

  test "checking in twice records one visit and does not inflate the stats" do
    login_as(@user)
    coordinates = { location_id: @location.uuid, user_lat: @location.lat, user_lng: @location.lng }

    2.times { post plan_visits_path(@plan), params: coordinates, as: :turbo_stream }

    assert_equal 1, @user.plan_visits.where(plan: @plan, location: @location).count
    assert_equal 1, @user.reload.travel_profile_data["stats"]["totalVisits"]
  end

  # Same guard as the deck's: the walk renders the same card, and the readers
  # behind it query past a preload unless they branch on `loaded?`.
  test "the walk costs the same whether it stacks one card or twelve" do
    login_as(@user)

    one = walk_queries
    11.times do |i|
      extra = Location.create!(name: "Stop #{i}", city: "Sarajevo", lat: 43.8 + i * 0.01, lng: 18.4)
      @experience.add_location(extra, position: i + 2)
    end
    twelve = walk_queries

    assert_equal 12, @plan.reload.all_location_count
    assert_equal one, twelve,
                 "stacking twelve cards cost #{twelve} queries against #{one} for one — a per-card query is back"
  end

  test "a deep fallback locale costs the walk nothing extra" do
    login_as(@user)

    assert_equal walk_queries(locale: :en), walk_queries(locale: :pl),
                 "Polish falls back through cs and sk; the chain must resolve in one query, not four"
  end

  private

  def walk_queries(locale: :en)
    # Warm first: the request that opens a connection pays for schema reads.
    get start_plan_path(@plan), params: { locale: locale }

    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]

      count += 1
    end
    ActiveRecord::Base.connection.clear_query_cache
    get start_plan_path(@plan), params: { locale: locale }
    assert_response :success
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end
end
