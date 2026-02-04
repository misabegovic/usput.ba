# frozen_string_literal: true

require "test_helper"

class LocationCreatorTest < ActiveSupport::TestCase
  test "creates location with experience types successfully" do
    result = LocationCreator.new(
      name: "Stari Most",
      city: "Mostar",
      lat: 43.337085,
      lng: 17.815094,
      suitable_experiences: [ "culture", "history" ]
    ).call

    assert result.success?
    assert_not result.failure?
    assert_empty result.errors

    location = result.location
    assert location.persisted?
    assert_equal "Stari Most", location.name
    assert_equal "Mostar", location.city
    assert_equal 43.337085, location.lat
    assert_equal 17.815094, location.lng

    # Verify experience types were assigned
    assert_equal 2, location.experience_types.count
    assert_includes location.suitable_experiences, "culture"
    assert_includes location.suitable_experiences, "history"
  end

  test "creates location without experience types" do
    result = LocationCreator.new(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    ).call

    assert result.success?
    assert result.location.persisted?
    assert_equal 0, result.location.experience_types.count
  end

  test "handles validation errors" do
    result = LocationCreator.new(
      name: "", # name is required
      city: "Sarajevo"
    ).call

    assert result.failure?
    assert_not result.success?
    assert_not_empty result.errors
    assert_includes result.errors.join, "Name can't be blank"
    assert_nil result.location.id
  end

  test "normalizes experience type keys" do
    result = LocationCreator.new(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      suitable_experiences: [ "  Culture  ", "HISTORY", "nature" ]
    ).call

    assert result.success?

    location = result.location
    assert_equal 3, location.experience_types.count
    assert_includes location.suitable_experiences, "culture"
    assert_includes location.suitable_experiences, "history"
    assert_includes location.suitable_experiences, "nature"
  end

  test "removes duplicate experience types" do
    result = LocationCreator.new(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      suitable_experiences: [ "culture", "CULTURE", "culture" ]
    ).call

    assert result.success?

    location = result.location
    assert_equal 1, location.experience_types.count
    assert_equal [ "culture" ], location.suitable_experiences
  end

  test "accepts experience_types as alias for suitable_experiences" do
    result = LocationCreator.new(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      experience_types: [ "culture", "history" ]
    ).call

    assert result.success?

    location = result.location
    assert_equal 2, location.experience_types.count
    assert_includes location.suitable_experiences, "culture"
    assert_includes location.suitable_experiences, "history"
  end

  test "handles invalid coordinates" do
    result = LocationCreator.new(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563
      # lng missing - should fail validation
    ).call

    assert result.failure?
    assert_includes result.errors.join, "latitude and longitude"
  end

  test "handles duplicate coordinates" do
    # Create first location
    Location.create!(
      name: "Original Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )

    # Try to create duplicate
    result = LocationCreator.new(
      name: "Duplicate Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    ).call

    assert result.failure?
    assert_includes result.errors.join, "i longitude kombinacija već postoji"
  end

  test "skips blank experience types" do
    result = LocationCreator.new(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      suitable_experiences: [ "culture", "", "  ", "history" ]
    ).call

    assert result.success?

    location = result.location
    assert_equal 2, location.experience_types.count
    assert_includes location.suitable_experiences, "culture"
    assert_includes location.suitable_experiences, "history"
  end
end
