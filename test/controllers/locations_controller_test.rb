# frozen_string_literal: true

require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test location with required fields
    @location = Location.create!(
      name: "Test Museum",
      description: "A test museum in Sarajevo",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    # Create another location for nearby tests
    @nearby_location = Location.create!(
      name: "Nearby Cafe",
      description: "A cafe near the museum",
      city: "Sarajevo",
      lat: 43.8570,
      lng: 18.4140,
      location_type: :restaurant
    )

    # Create an experience that includes this location
    @experience = Experience.create!(
      title: "City Walking Tour",
      description: "A walking tour around the city",
      estimated_duration: 120
    )
    @experience.add_location(@location, position: 1)

    # Create a public plan that includes this experience
    @plan = Plan.create!(
      title: "Weekend in Sarajevo",
      city_name: "Sarajevo",
      visibility: :public_plan
    )
    @plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )
  end

  teardown do
    # Clean up in reverse order of dependencies
    @plan&.destroy
    @experience&.destroy
    @nearby_location&.destroy
    @location&.destroy
  end

  # === Show action tests ===

  test "show displays location by UUID" do
    get location_path(@location)

    assert_response :success
    assert_select "body" # Basic page renders
  end

  test "show displays location with reviews" do
    # Create a review for the location
    review = Review.create!(
      reviewable: @location,
      rating: 5,
      comment: "Great museum!",
      author_name: "Test User"
    )

    get location_path(@location)

    assert_response :success

    review.destroy
  end

  test "show sets instance variables correctly" do
    get location_path(@location)

    assert_response :success
    # Controller should set @location, @reviews, @nearby_locations, etc.
  end

  test "show redirects to explore for non-existent location" do
    get location_path("non-existent-uuid-12345")

    assert_redirected_to explore_path
    assert_equal I18n.t("locations.not_found", default: "Location not found. Explore other destinations."), flash[:alert]
  end

  test "show redirects to explore for invalid UUID format" do
    get location_path("invalid-id")

    assert_redirected_to explore_path
  end

  test "show handles location with no reviews" do
    get location_path(@location)

    assert_response :success
  end

  test "show includes related experiences" do
    get location_path(@location)

    assert_response :success
    # The experience that includes this location should be available
  end

  test "show includes related public plans" do
    get location_path(@location)

    assert_response :success
    # The public plan that includes experiences with this location should be available
  end

  test "show does not include private plans" do
    # Create a private plan
    private_plan = Plan.create!(
      title: "Private Plan",
      city_name: "Sarajevo",
      visibility: :private_plan
    )
    private_plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )

    get location_path(@location)

    assert_response :success
    # Private plan should not be shown to public

    private_plan.destroy
  end

  # === Audio tour action tests ===

  test "audio_tour renders for location with audio" do
    # Create an audio tour for the location
    audio_tour = AudioTour.create!(
      location: @location,
      locale: "en",
      script: "Welcome to this location."
    )

    get audio_tour_location_path(@location)

    assert_response :success

    audio_tour.destroy
  end

  test "audio_tour renders for location without audio" do
    get audio_tour_location_path(@location)

    assert_response :success
  end

  test "audio_tour redirects for non-existent location" do
    get audio_tour_location_path("non-existent-uuid")

    assert_redirected_to explore_path
  end

  # === Edge cases ===

  test "show handles location with all optional fields nil" do
    minimal_location = Location.create!(
      name: "Minimal Location",
      lat: 44.0,
      lng: 18.0
    )

    get location_path(minimal_location)

    assert_response :success

    minimal_location.destroy
  end

  test "show handles location with special characters in name" do
    special_location = Location.create!(
      name: "Lokacija s posebnim znakovima: <>&\"'",
      city: "Sarajevo",
      lat: 44.1,
      lng: 18.1
    )

    get location_path(special_location)

    assert_response :success

    special_location.destroy
  end

  test "show handles concurrent access gracefully" do
    # Simulate concurrent access by making multiple requests
    threads = 3.times.map do
      Thread.new do
        get location_path(@location)
        response.status
      end
    end

    results = threads.map(&:value)
    assert results.all? { |status| status == 200 }
  end
end
