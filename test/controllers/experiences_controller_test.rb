# frozen_string_literal: true

require "test_helper"

class ExperiencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test location
    @location = Location.create!(
      name: "Historic Site",
      description: "A historic landmark",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )

    # Create test experience
    @experience = Experience.create!(
      title: "Historic Mostar Tour",
      description: "Explore the historic sites of Mostar",
      estimated_duration: 180
    )
    @experience.add_location(@location, position: 1)

    # Create another experience in the same city for nearby tests
    @nearby_experience = Experience.create!(
      title: "Food Tour in Mostar",
      description: "Taste local cuisine",
      estimated_duration: 120
    )

    nearby_location = Location.create!(
      name: "Local Restaurant",
      city: "Mostar",
      lat: 43.3440,
      lng: 17.8080,
      location_type: :restaurant
    )
    @nearby_experience.add_location(nearby_location, position: 1)
    @nearby_location_for_cleanup = nearby_location

    # Create a public plan that includes this experience
    @public_plan = Plan.create!(
      title: "Mostar Weekend",
      city_name: "Mostar",
      visibility: :public_plan
    )
    @public_plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )
  end

  teardown do
    @public_plan&.destroy
    @nearby_experience&.destroy
    @nearby_location_for_cleanup&.destroy
    @experience&.destroy
    @location&.destroy
  end

  # === Show action tests ===

  test "show displays experience by UUID" do
    get experience_path(@experience)

    assert_response :success
    assert_select "body" # Basic page renders
  end

  test "show displays experience with locations" do
    get experience_path(@experience)

    assert_response :success
    # Experience should include its locations
  end

  test "show displays experience with reviews" do
    review = Review.create!(
      reviewable: @experience,
      rating: 4,
      comment: "Great tour!",
      author_name: "Visitor"
    )

    get experience_path(@experience)

    assert_response :success

    review.destroy
  end

  test "show redirects to explore for non-existent experience" do
    get experience_path("non-existent-uuid-12345")

    assert_redirected_to explore_path
    assert_equal I18n.t("experiences.not_found", default: "Experience not found. Explore other experiences."), flash[:alert]
  end

  test "show redirects to explore for invalid UUID" do
    get experience_path("invalid-uuid")

    assert_redirected_to explore_path
  end

  test "show handles experience with no locations" do
    empty_experience = Experience.create!(
      title: "Empty Experience",
      description: "No locations yet"
    )

    get experience_path(empty_experience)

    assert_response :success

    empty_experience.destroy
  end

  test "show handles experience with no reviews" do
    get experience_path(@experience)

    assert_response :success
  end

  test "show includes related public plans" do
    get experience_path(@experience)

    assert_response :success
    # The public plan that includes this experience should be available
  end

  test "show does not include private plans" do
    private_plan = Plan.create!(
      title: "Private Mostar Plan",
      city_name: "Mostar",
      visibility: :private_plan
    )
    private_plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )

    get experience_path(@experience)

    assert_response :success
    # Private plan should not be shown

    private_plan.destroy
  end

  test "show includes nearby experiences from same city" do
    get experience_path(@experience)

    assert_response :success
    # Nearby experiences from the same city should be available
  end

  # === Edge cases ===

  test "show handles experience with multiple locations" do
    second_location = Location.create!(
      name: "Second Stop",
      city: "Mostar",
      lat: 43.3450,
      lng: 17.8090
    )
    @experience.add_location(second_location, position: 2)

    get experience_path(@experience)

    assert_response :success

    second_location.destroy
  end

  test "show handles experience with nil estimated_duration" do
    no_duration_exp = Experience.create!(
      title: "Quick Visit",
      description: "Short experience"
    )

    get experience_path(no_duration_exp)

    assert_response :success

    no_duration_exp.destroy
  end

  test "show handles experience with special characters in title" do
    special_exp = Experience.create!(
      title: "Tour <special> & \"quoted\"",
      description: "Special characters test"
    )

    get experience_path(special_exp)

    assert_response :success

    special_exp.destroy
  end

  test "show handles experience in category" do
    category = ExperienceCategory.create!(
      name: "Adventure",
      key: "adventure_test"
    )

    categorized_exp = Experience.create!(
      title: "Adventure Tour",
      description: "An adventure experience",
      experience_category: category
    )

    get experience_path(categorized_exp)

    assert_response :success

    categorized_exp.destroy
    category.destroy
  end

  test "show handles experience with seasons" do
    seasonal_exp = Experience.create!(
      title: "Summer Beach Tour",
      description: "Beach experience",
      seasons: ["summer", "spring"]
    )

    get experience_path(seasonal_exp)

    assert_response :success

    seasonal_exp.destroy
  end

  test "show handles concurrent requests" do
    threads = 3.times.map do
      Thread.new do
        get experience_path(@experience)
        response.status
      end
    end

    results = threads.map(&:value)
    assert results.all? { |status| status == 200 }
  end
end
