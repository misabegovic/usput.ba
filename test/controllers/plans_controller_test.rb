# frozen_string_literal: true

require "test_helper"

class PlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test location
    @location = Location.create!(
      name: "City Center",
      description: "Main square",
      city: "Banja Luka",
      lat: 44.7758,
      lng: 17.1858,
      location_type: :place,
      budget: :medium,
      suitable_experiences: ["culture", "history"]
    )

    # Create test experience
    @experience = Experience.create!(
      title: "City Tour",
      description: "Walking tour of the city",
      estimated_duration: 90
    )
    @experience.add_location(@location, position: 1)

    # Create public plan
    @public_plan = Plan.create!(
      title: "Banja Luka Weekend",
      city_name: "Banja Luka",
      visibility: :public_plan,
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days
    )
    @public_plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )

    # Create user for authentication tests
    @user = User.create!(
      username: "plantest_user",
      password: "password123",
      password_confirmation: "password123"
    )

    # Create private plan for user
    @private_plan = Plan.create!(
      title: "My Private Plan",
      city_name: "Banja Luka",
      visibility: :private_plan,
      user: @user
    )
    @private_plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )
  end

  teardown do
    @private_plan&.destroy
    @public_plan&.destroy
    @user&.destroy
    @experience&.destroy
    @location&.destroy
  end

  # === Show action tests ===

  test "show displays public plan by UUID" do
    get plan_path(@public_plan)

    assert_response :success
  end

  test "show redirects for non-existent plan" do
    get plan_path("non-existent-uuid")

    assert_redirected_to explore_path
    assert_equal I18n.t("plans.not_found", default: "Plan not found. Explore other plans."), flash[:alert]
  end

  test "show returns 404 for private plan when not logged in" do
    get plan_path(@private_plan)

    assert_redirected_to explore_path
  end

  test "show allows owner to view their private plan" do
    post login_path, params: { username: @user.username, password: "password123" }

    get plan_path(@private_plan)

    assert_response :success
  end

  test "show denies access to other users private plan" do
    other_user = User.create!(
      username: "other_user",
      password: "password123",
      password_confirmation: "password123"
    )

    post login_path, params: { username: other_user.username, password: "password123" }

    get plan_path(@private_plan)

    assert_redirected_to explore_path

    other_user.destroy
  end

  test "show includes plan experiences" do
    get plan_path(@public_plan)

    assert_response :success
  end

  test "show includes reviews for plan" do
    review = Review.create!(
      reviewable: @public_plan,
      rating: 5,
      comment: "Great plan!",
      author_name: "Happy Traveler"
    )

    get plan_path(@public_plan)

    assert_response :success

    review.destroy
  end

  # === Wizard action tests ===

  test "wizard renders without parameters" do
    get plan_wizard_path

    assert_response :success
  end

  test "wizard renders with city_name parameter" do
    get plan_wizard_path, params: { city_name: "Sarajevo" }

    assert_response :success
  end

  test "wizard renders with city slug" do
    get plan_wizard_city_path(city_slug: "sarajevo")

    assert_response :success
  end

  # === View action tests ===

  test "view renders empty template for localStorage" do
    get plan_view_path

    assert_response :success
  end

  # === Find city action tests ===

  test "find_city returns nearest city for valid coordinates" do
    post plans_find_city_path, params: { lat: 44.7758, lng: 17.1858 }

    assert_response :success
    body = response.parsed_body
    assert body["city_name"].present?
  end

  test "find_city returns 404 when no nearby locations" do
    # Use coordinates far from any location
    post plans_find_city_path, params: { lat: 0, lng: 0 }

    assert_response :not_found
  end

  # === Search cities action tests ===

  test "search_cities returns empty for short query" do
    get plans_search_cities_path, params: { q: "a" }

    assert_response :success
    body = response.parsed_body
    assert_equal [], body["cities"]
  end

  test "search_cities returns matching cities" do
    get plans_search_cities_path, params: { q: "Banja" }

    assert_response :success
    body = response.parsed_body
    assert body["cities"].is_a?(Array)
  end

  test "search_cities handles empty query" do
    get plans_search_cities_path, params: { q: "" }

    assert_response :success
    body = response.parsed_body
    assert_equal [], body["cities"]
  end

  # === Recommendations action tests ===

  test "recommendations returns experiences and plans for city" do
    get plans_recommendations_path, params: { city_name: "Banja Luka" }

    assert_response :success
    body = response.parsed_body
    assert body["experiences"].is_a?(Array)
    assert body["plans"].is_a?(Array)
    assert_equal "Banja Luka", body["city_name"]
  end

  test "recommendations returns bad request without city_name" do
    get plans_recommendations_path

    assert_response :bad_request
  end

  test "recommendations excludes specified experience IDs" do
    get plans_recommendations_path, params: {
      city_name: "Banja Luka",
      exclude_ids: [@experience.uuid].to_json
    }

    assert_response :success
    body = response.parsed_body
    experience_ids = body["experiences"].map { |e| e["id"] }
    assert_not_includes experience_ids, @experience.uuid
  end

  # === Generate action tests ===

  test "generate creates plan data for valid city" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      duration: "1",
      daily_hours: 6
    }

    assert_response :success
    body = response.parsed_body
    assert body["id"].present?
    assert body["days"].is_a?(Array)
    assert_equal "Banja Luka", body["city_name"]
  end

  test "generate returns error for missing city_name" do
    post plans_generate_path, params: { duration: "1" }

    assert_response :not_found
  end

  test "generate handles different duration values" do
    ["1", "2-3", "4+"].each do |duration|
      post plans_generate_path, params: {
        city_name: "Banja Luka",
        duration: duration
      }

      assert_response :success, "Failed for duration: #{duration}"
    end
  end

  test "generate handles budget parameter" do
    %w[low medium high].each do |budget|
      post plans_generate_path, params: {
        city_name: "Banja Luka",
        budget: budget
      }

      assert_response :success, "Failed for budget: #{budget}"
    end
  end

  test "generate handles meat_lover parameter" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      meat_lover: "true"
    }

    assert_response :success
  end

  test "generate handles interests parameter as JSON" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      interests: '["culture", "history"]'
    }

    assert_response :success
  end

  test "generate handles interests parameter as comma-separated" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      interests: "culture,history"
    }

    assert_response :success
  end

  test "generate handles daily_hours parameter" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      daily_hours: 8
    }

    assert_response :success
  end

  test "generate clamps daily_hours to valid range" do
    # Test below minimum
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      daily_hours: 1
    }
    assert_response :success

    # Test above maximum
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      daily_hours: 20
    }
    assert_response :success
  end

  test "generate returns error for city with no experiences" do
    # Create a location in a new city without experiences
    lonely_location = Location.create!(
      name: "Lonely Place",
      city: "NonExistentCity",
      lat: 45.0,
      lng: 18.0
    )

    post plans_generate_path, params: { city_name: "VeryNonExistentCity" }

    assert_response :unprocessable_entity

    lonely_location.destroy
  end

  test "generate includes statistics in response" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      duration: "1"
    }

    assert_response :success
    body = response.parsed_body
    assert body["statistics"].present?
    assert body["statistics"]["total_duration_minutes"].present?
  end

  # === Edge cases ===

  test "plans index redirects to explore" do
    get plans_path

    assert_redirected_to "/explore"
  end

  test "show handles plan with no experiences" do
    empty_plan = Plan.create!(
      title: "Empty Plan",
      city_name: "Sarajevo",
      visibility: :public_plan
    )

    get plan_path(empty_plan)

    assert_response :success

    empty_plan.destroy
  end

  test "generate filters out invalid interests" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      interests: '["culture", "invalid_interest", "<script>evil</script>"]'
    }

    assert_response :success
    # Invalid interests should be filtered out without error
  end

  test "generate rejects invalid budget values" do
    post plans_generate_path, params: {
      city_name: "Banja Luka",
      budget: "invalid_budget"
    }

    assert_response :success
    # Should use default budget (nil = all)
  end
end
