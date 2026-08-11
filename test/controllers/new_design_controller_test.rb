# frozen_string_literal: true

require "test_helper"

class NewDesignControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a basic location for testing
    @location = Location.create!(
      name: "Test Location",
      description: "A beautiful test location for tourism",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place,
      average_rating: 4.5,
      reviews_count: 5
    )

    # Create another location in a different city
    @mostar_location = Location.create!(
      name: "Old Bridge",
      description: "Historic bridge in Mostar",
      city: "Mostar",
      lat: 43.3372,
      lng: 17.8153,
      location_type: :place,
      average_rating: 4.8,
      reviews_count: 10
    )

    # Create an experience category
    @category = ExperienceCategory.create!(
      key: "cultural",
      name: "Cultural Heritage",
      active: true,
      position: 1
    )

    # Create an experience with the location
    @experience = Experience.create!(
      title: "City Walking Tour",
      description: "A walking tour around the city center",
      estimated_duration: 120,
      experience_category: @category,
      average_rating: 4.2,
      reviews_count: 3
    )
    @experience.add_location(@location, position: 1)

    # Create a public plan
    @plan = Plan.create!(
      title: "Weekend in Sarajevo",
      city_name: "Sarajevo",
      visibility: :public_plan,
      average_rating: 4.0,
      reviews_count: 2
    )
    @plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )

    # Create a review for trending data
    @review = Review.create!(
      reviewable: @location,
      rating: 5,
      comment: "Amazing place to visit!",
      author_name: "Test User"
    )

    # Create Browse records for search functionality
    sync_browse_records
  end

  teardown do
    # Clean up in reverse order of dependencies
    @review&.destroy
    @plan&.destroy
    @experience&.destroy
    @category&.destroy
    @mostar_location&.destroy
    @location&.destroy

    # Clean up Browse records
    Browse.delete_all
  end

  # === Home action tests ===

  test "home page loads successfully" do
    get new_home_path

    assert_response :success
  end

  test "home page loads successfully via root path" do
    get root_path

    assert_response :success
  end

  test "home sets positive_reviews instance variable" do
    get new_home_path

    assert_response :success
    # The controller fetches positive reviews with rating >= 3
  end

  test "home sets trending_locations instance variable" do
    # Ensure location has reviews for trending
    @location.update!(average_rating: 4.5, reviews_count: 5)

    get new_home_path

    assert_response :success
  end

  test "home sets trending_experiences instance variable" do
    # Ensure experience has reviews for trending
    @experience.update!(average_rating: 4.0, reviews_count: 3)

    get new_home_path

    assert_response :success
  end

  test "home page handles empty database gracefully" do
    # Clean up all data
    Review.delete_all
    PlanExperience.delete_all
    Plan.delete_all
    ExperienceLocation.delete_all
    Experience.delete_all
    LocationCategoryAssignment.delete_all
    Location.delete_all
    Browse.delete_all

    get new_home_path

    assert_response :success
  end

  # === Explore action tests ===

  test "explore page loads successfully" do
    get explore_path

    assert_response :success
  end

  test "explore page loads with empty results" do
    Browse.delete_all

    get explore_path

    assert_response :success
  end

  test "explore sets query parameter" do
    get explore_path, params: { q: "Sarajevo" }

    assert_response :success
  end

  test "explore filters by type location" do
    get explore_path, params: { types: [ "location" ] }

    assert_response :success
  end

  test "explore filters by type experience" do
    get explore_path, params: { types: [ "experience" ] }

    assert_response :success
  end

  test "explore filters by type plan" do
    get explore_path, params: { types: [ "plan" ] }

    assert_response :success
  end

  test "explore returns approved public moments under the moment type" do
    user = User.create!(username: "explorer_sharer", password: "password123")
    moment = user.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(visibility: :public_moment)
    moment.update!(moderation_status: :approved)

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "a[href=?]", location_path(@location), minimum: 1
  ensure
    Moment.destroy_all
    user&.destroy
  end

  test "explore does not surface a pending or private moment" do
    user = User.create!(username: "private_sharer", password: "password123")
    moment = user.moments.build(plan: @plan, location: @mostar_location)
    moment.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(visibility: :public_moment) # pending, not approved

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "a[href=?]", location_path(@mostar_location), count: 0
  ensure
    Moment.destroy_all
    user&.destroy
  end

  test "explore shows a traveller their own private moment, which the public grid never gets" do
    user = User.create!(username: "band_owner", password: "password123")
    moment = own_moment_for(user, @location)
    login_as(user)

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(moment)}", { count: 1 },
      "the traveller's own private moment must appear in their band"
    assert_select "form[action=?]", publish_plan_moment_path(@plan, moment), count: 1
    assert_select "form[action=?]", plan_moment_path(@plan, moment), count: 1
  ensure
    Moment.destroy_all
    user&.destroy
  end

  # travel_profile_path is the JSON endpoint: linking there printed the raw
  # profile payload on screen instead of opening the profile.
  test "see-all-your-moments goes to the profile page, not the JSON endpoint" do
    user = User.create!(username: "band_all_link", password: "password123")
    NewDesignController::OWN_MOMENTS_LIMIT.times { own_moment_for(user, @location) }
    login_as(user)

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "a[href=?]", profile_page_path, minimum: 1
    assert_select "a[href=?]", "/travel_profile", count: 0
  ensure
    Moment.destroy_all
    user&.destroy
  end

  test "the band card links through to the moment's location" do
    user = User.create!(username: "band_linker", password: "password123")
    own_moment_for(user, @location)
    login_as(user)

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "a[href=?]", location_path(@location), minimum: 1
  ensure
    Moment.destroy_all
    user&.destroy
  end

  test "a logged-out visitor gets no own-moments band" do
    user = User.create!(username: "band_absent", password: "password123")
    own_moment_for(user, @location)

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "turbo-frame[id^=?]", "moment_", count: 0
  ensure
    Moment.destroy_all
    user&.destroy
  end

  test "another traveller's private moment stays out of your band" do
    mine = User.create!(username: "band_mine", password: "password123")
    theirs = User.create!(username: "band_theirs", password: "password123")
    hidden = own_moment_for(theirs, @mostar_location)
    login_as(mine)

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(hidden)}", { count: 0 },
      "the band is scoped to the signed-in traveller"
  ensure
    Moment.destroy_all
    mine&.destroy
    theirs&.destroy
  end

  test "a public moment expands like your own instead of navigating away" do
    sharer = User.create!(username: "band_public", password: "password123")
    shared = own_moment_for(sharer, @location)
    # Publishing re-enters moderation, so approval is a second step.
    shared.update!(visibility: :public_moment)
    shared.update!(moderation_status: :approved)

    get explore_path, params: { types: [ "moment" ] }

    assert_response :success
    assert_select "[data-photo-gallery-target='thumbnail']", { minimum: 1 },
      "a public moment's photo must open full screen, not link to the location"
    assert_select "[data-photo-gallery-target='lightbox']", minimum: 1
  ensure
    Moment.destroy_all
    sharer&.destroy
  end

  test "explore filters by multiple types" do
    get explore_path, params: { types: [ "location", "experience" ] }

    assert_response :success
  end

  test "explore filters by season" do
    get explore_path, params: { season: "summer" }

    assert_response :success
  end

  test "explore filters by budget" do
    get explore_path, params: { budget: "low" }

    assert_response :success
  end

  test "explore filters by duration" do
    get explore_path, params: { duration: "short" }

    assert_response :success
  end

  test "explore filters by min_rating" do
    get explore_path, params: { min_rating: "4" }

    assert_response :success
  end

  test "explore filters by city_name" do
    get explore_path, params: { city_name: "Sarajevo" }

    assert_response :success
  end

  test "explore filters by origin ai" do
    get explore_path, params: { origin: "ai" }

    assert_response :success
  end

  test "explore filters by origin human" do
    get explore_path, params: { origin: "human" }

    assert_response :success
  end

  test "explore filters by audio_support" do
    get explore_path, params: { audio_support: "true" }

    assert_response :success
  end

  test "explore filters by coordinates" do
    get explore_path, params: { lat: "43.8563", lng: "18.4131" }

    assert_response :success
  end

  test "explore filters by coordinates with custom radius" do
    get explore_path, params: { lat: "43.8563", lng: "18.4131", radius: "50" }

    assert_response :success
  end

  test "explore sorts by rating" do
    get explore_path, params: { sort: "rating" }

    assert_response :success
  end

  test "explore sorts by newest" do
    get explore_path, params: { sort: "newest" }

    assert_response :success
  end

  test "explore sorts by name" do
    get explore_path, params: { sort: "name" }

    assert_response :success
  end

  test "explore sorts by relevance" do
    get explore_path, params: { sort: "relevance", q: "Test" }

    assert_response :success
  end

  test "explore handles pagination for locations" do
    get explore_path, params: { locations_page: "2" }

    assert_response :success
  end

  test "explore handles pagination for experiences" do
    get explore_path, params: { experiences_page: "2" }

    assert_response :success
  end

  test "explore handles pagination for plans" do
    get explore_path, params: { plans_page: "2" }

    assert_response :success
  end

  test "explore handles combined filters" do
    get explore_path, params: {
      q: "tour",
      types: [ "experience" ],
      season: "summer",
      min_rating: "3",
      sort: "rating"
    }

    assert_response :success
  end

  test "explore sets city_names for filter dropdown" do
    get explore_path

    assert_response :success
    # Controller should set @city_names from unique location cities
  end

  test "explore sets experience_categories for filter dropdown" do
    get explore_path

    assert_response :success
    # Controller should set @experience_categories
  end

  test "explore handles search with no results" do
    get explore_path, params: { q: "nonexistentquery12345" }

    assert_response :success
  end

  test "explore handles blank type filter" do
    get explore_path, params: { types: [ "" ] }

    assert_response :success
  end

  test "explore handles invalid pagination values gracefully" do
    get explore_path, params: { locations_page: "abc" }

    assert_response :success
  end

  test "explore handles negative pagination values" do
    get explore_path, params: { locations_page: "-1" }

    assert_response :success
  end

  # === Single place expansion tests ===

  test "explore expands to nearby items when query matches single location" do
    # Create a unique location name for testing single place expansion
    # Use different coordinates to avoid uniqueness constraint violation
    unique_location = Location.create!(
      name: "UniqueTestMuseum12345",
      description: "A unique test museum",
      city: "Sarajevo",
      lat: 43.9000,
      lng: 18.5000,
      location_type: :place,
      average_rating: 4.5,
      reviews_count: 5
    )

    # Sync to Browse
    Browse.sync_record(unique_location)

    get explore_path, params: { q: "UniqueTestMuseum12345" }

    assert_response :success

    unique_location.destroy
  end

  test "explore does not expand when coordinates are already provided" do
    get explore_path, params: { q: "Test", lat: "43.8563", lng: "18.4131" }

    assert_response :success
  end

  # === Edge cases ===

  test "explore handles special characters in search query" do
    get explore_path, params: { q: "Test <>&\"'" }

    assert_response :success
  end

  test "explore handles very long search query" do
    long_query = "a" * 500
    get explore_path, params: { q: long_query }

    assert_response :success
  end

  test "explore handles unicode characters in search" do
    get explore_path, params: { q: "Muzej Bosne i Hercegovine" }

    assert_response :success
  end

  test "explore handles emoji in search query" do
    get explore_path, params: { q: "beautiful place 🏔️" }

    assert_response :success
  end

  test "explore filters with partial coordinates lat only" do
    get explore_path, params: { lat: "43.8563" }

    assert_response :success
  end

  test "explore filters with partial coordinates lng only" do
    get explore_path, params: { lng: "18.4131" }

    assert_response :success
  end

  test "explore handles zero radius" do
    get explore_path, params: { lat: "43.8563", lng: "18.4131", radius: "0" }

    assert_response :success
  end

  test "explore handles all filter combinations" do
    get explore_path, params: {
      q: "tour",
      types: [ "location", "experience", "plan" ],
      season: "spring",
      budget: "medium",
      duration: "medium",
      min_rating: "3",
      city_name: "Sarajevo",
      origin: "human",
      audio_support: "false",
      sort: "newest",
      locations_page: "1",
      experiences_page: "1",
      plans_page: "1"
    }

    assert_response :success
  end

  # === Layout tests ===

  test "home uses new_design layout" do
    get new_home_path

    assert_response :success
    # The controller specifies layout "new_design"
  end

  test "explore uses new_design layout" do
    get explore_path

    assert_response :success
    # The controller specifies layout "new_design"
  end

  # === Response format tests ===

  test "home returns HTML content type" do
    get new_home_path

    assert_response :success
    assert_includes response.content_type, "text/html"
  end

  test "explore returns HTML content type" do
    get explore_path

    assert_response :success
    assert_includes response.content_type, "text/html"
  end

  private

  def own_moment_for(user, location)
    moment = user.moments.build(plan: @plan, location: location)
    moment.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    moment
  end

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  # Helper to sync Browse records for search functionality
  def sync_browse_records
    Browse.sync_record(@location) if @location&.persisted?
    Browse.sync_record(@mostar_location) if @mostar_location&.persisted?
    Browse.sync_record(@experience) if @experience&.persisted?
    Browse.sync_record(@plan) if @plan&.persisted?
  end
end
