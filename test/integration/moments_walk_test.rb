# frozen_string_literal: true

require "test_helper"

# Moments are captured only on the walk; the plan card links to the server-rendered
# plan page, and the walk offers publish/unpublish.
class MomentsWalkTest < ActionDispatch::IntegrationTest
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

  test "the profile shows the traveller's own moments with location and photo" do
    add_moment(note: "sunset")
    login_as(@user)

    get profile_page_path

    assert_response :success
    assert_match @location.name, response.body
    assert_select "img[src*='/moments/']", { minimum: 1 }, "the moment photo renders on the profile"
  end

  test "the profile's visited places reflect a walk check-in (PlanVisit)" do
    @user.plan_visits.create!(plan: @plan, location: @location)
    login_as(@user)

    get profile_page_path

    assert_response :success
    assert_select "a[href=?]", location_path(@location), { minimum: 1 }, "the checked-in location appears under Visited places"
    assert_match @location.name, response.body
  end

  test "a plan card links to the plan page where moments live" do
    login_as(@user)

    # Cards are lazy-loaded into a turbo-frame, so they are not in the profile HTML
    get profile_plans_path

    assert_response :success
    assert_select "a[href=?]", plan_path(@plan), count: 1
  end

  test "the walk offers to share a private moment" do
    add_moment(note: "shareable")
    login_as(@user)

    get plan_moments_path(@plan, location_id: @location.uuid, context: "walk"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@location, :moments_frame) }

    assert_response :success
    assert_select "form[action=?]", publish_plan_moment_path(@plan, @user.moments.first)
  end

  test "publishing from the walk's stories streams in place, no redirect" do
    add_moment(note: "to share")
    login_as(@user)

    patch publish_plan_moment_path(@plan, @user.moments.first),
          params: { context: "walk" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action=replace][target=?]",
                  ActionView::RecordIdentifier.dom_id(@location, :stories), count: 1
    assert @user.moments.first.visibility_public_moment?
  end

  test "an already-public moment shows badged in the stories with a delete" do
    add_moment(note: "shared").update!(visibility: :public_moment)
    login_as(@user)

    get plan_moments_path(@plan, location_id: @location.uuid, context: "walk"),
        headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(@location, :moments_frame) }

    assert_response :success
    # unsharing moved to the profile; the moment tile offers delete
    assert_select "form[action=?]", unpublish_plan_moment_path(@plan, @user.moments.first), count: 0
    assert_select "form[action=?]", plan_moment_path(@plan, @user.moments.first), count: 1
  end

  test "marking a location visited within 100m records the visit" do
    login_as(@user)

    assert_difference -> { @user.plan_visits.count }, 1 do
      post plan_visits_path(@plan), params: { location_id: @location.uuid, user_lat: @location.lat, user_lng: @location.lng }
    end
  end

  test "marking a location visited from too far away is rejected with an alert" do
    login_as(@user)

    assert_no_difference -> { @user.plan_visits.count } do
      post plan_visits_path(@plan), params: { location_id: @location.uuid, user_lat: 43.90, user_lng: 18.50 }
    end
    assert flash[:alert].present?, "a too-far visit must surface an alert"
  end

  test "marking a location visited without coordinates is rejected" do
    login_as(@user)

    assert_no_difference -> { @user.plan_visits.count } do
      post plan_visits_path(@plan), params: { location_id: @location.uuid, user_lat: 0, user_lng: 0 }
    end
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def add_moment(note: nil)
    moment = @user.moments.build(plan: @plan, location: @location, note: note)
    moment.photo.attach(
      io: File.open("test/fixtures/files/test_image.jpg"),
      filename: "moment.jpg",
      content_type: "image/jpeg"
    )
    moment.save!
    moment
  end
end
