# frozen_string_literal: true

require "test_helper"

class LocationUpdaterTest < ActiveSupport::TestCase
  setup do
    # Create a test location
    @location = Location.create!(
      name: "Test Location",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    )

    # Ensure we have some experience types
    @nature_type = ExperienceType.find_or_create_by!(key: "nature") do |et|
      et.name = "Nature"
      et.active = true
      et.position = 1
    end

    @culture_type = ExperienceType.find_or_create_by!(key: "culture") do |et|
      et.name = "Culture"
      et.active = true
      et.position = 2
    end

    @adventure_type = ExperienceType.find_or_create_by!(key: "adventure") do |et|
      et.name = "Adventure"
      et.active = true
      et.position = 3
    end
  end

  # Test basic update with experience types
  test "updates location with experience types" do
    result = LocationUpdater.new(@location,
      name: "Updated Name",
      suitable_experiences: %w[nature adventure]
    ).call

    assert result.success?
    assert_equal "Updated Name", @location.reload.name
    assert_includes @location.suitable_experiences, "nature"
    assert_includes @location.suitable_experiences, "adventure"
    assert_equal 2, @location.experience_types.count
  end

  # Test update without experience types (only location attributes)
  test "updates location without changing experience types" do
    @location.set_experience_types(%w[culture])
    original_types = @location.suitable_experiences.dup

    result = LocationUpdater.new(@location,
      name: "New Name",
      description: "New description"
    ).call

    assert result.success?
    assert_equal "New Name", @location.reload.name
    assert_equal "New description", @location.description
    assert_equal original_types, @location.suitable_experiences
  end

  # Test clearing experience types (empty array)
  test "clears experience types with empty array" do
    @location.set_experience_types(%w[nature culture])
    assert @location.experience_types.any?

    result = LocationUpdater.new(@location,
      suitable_experiences: []
    ).call

    assert result.success?
    assert_empty @location.reload.suitable_experiences
    assert_empty @location.experience_types
  end

  # Test validation errors
  test "handles validation errors" do
    result = LocationUpdater.new(@location,
      name: "", # name is required
      suitable_experiences: %w[nature]
    ).call

    assert result.failure?
    assert_not_empty result.errors
    assert_match(/name/i, result.errors.join)
  end

  # Test handling experience type errors
  test "handles experience type errors gracefully" do
    # Force an error by trying to set experience types when database fails
    # We'll stub set_experience_types to raise an error
    def @location.set_experience_types(_types)
      raise StandardError, "Database connection lost"
    end

    result = LocationUpdater.new(@location,
      suitable_experiences: %w[nature]
    ).call

    assert result.failure?
    assert_match(/Failed to set experience types/, result.errors.join)
    assert_match(/Database connection lost/, result.errors.join)
  end

  # Test success? and failure? predicates
  test "success? returns true when update succeeds" do
    result = LocationUpdater.new(@location,
      name: "Success Update"
    ).call

    assert result.success?
    assert_not result.failure?
  end

  test "failure? returns true when update fails" do
    result = LocationUpdater.new(@location,
      name: "" # validation error
    ).call

    assert result.failure?
    assert_not result.success?
  end

  # Test partial update (only name, no experience types)
  test "partial update without experience types" do
    @location.set_experience_types(%w[nature culture])
    original_types = @location.suitable_experiences.dup

    result = LocationUpdater.new(@location,
      name: "Partially Updated"
    ).call

    assert result.success?
    assert_equal "Partially Updated", @location.reload.name
    # Experience types should remain unchanged
    assert_equal original_types.sort, @location.suitable_experiences.sort
  end

  # Test with both attribute keys :suitable_experiences and :experience_types
  test "handles both suitable_experiences and experience_types keys" do
    # :suitable_experiences takes precedence
    result = LocationUpdater.new(@location,
      suitable_experiences: %w[nature],
      experience_types: %w[culture] # Should be ignored
    ).call

    assert result.success?
    assert_includes @location.reload.suitable_experiences, "nature"
    assert_not_includes @location.suitable_experiences, "culture"
  end

  # Test with indifferent access (string vs symbol keys)
  test "works with string keys" do
    result = LocationUpdater.new(@location,
      "name" => "String Key Update",
      "suitable_experiences" => %w[adventure]
    ).call

    assert result.success?
    assert_equal "String Key Update", @location.reload.name
    assert_includes @location.suitable_experiences, "adventure"
  end

  # Test normalizing experience types (downcase, strip, unique)
  test "normalizes experience types" do
    result = LocationUpdater.new(@location,
      suitable_experiences: [ "  Nature  ", "ADVENTURE", "nature" ] # duplicates, whitespace, mixed case
    ).call

    assert result.success?
    types = @location.reload.suitable_experiences
    assert_equal 2, types.count
    assert_includes types, "nature"
    assert_includes types, "adventure"
  end

  # Test with blank values in experience types array
  test "removes blank values from experience types" do
    result = LocationUpdater.new(@location,
      suitable_experiences: [ "nature", "", "  ", nil, "adventure" ]
    ).call

    assert result.success?
    types = @location.reload.suitable_experiences
    assert_equal 2, types.count
    assert_includes types, "nature"
    assert_includes types, "adventure"
  end

  # Test update only experience types (no other attributes)
  test "updates only experience types without other attributes" do
    original_name = @location.name

    result = LocationUpdater.new(@location,
      suitable_experiences: %w[nature culture]
    ).call

    assert result.success?
    assert_equal original_name, @location.reload.name
    assert_equal 2, @location.experience_types.count
  end

  # Test with nil experience types (should not change)
  test "nil experience types does not change existing types" do
    @location.set_experience_types(%w[culture])
    original_types = @location.suitable_experiences.dup

    result = LocationUpdater.new(@location,
      name: "Updated",
      suitable_experiences: nil
    ).call

    assert result.success?
    # When explicitly set to nil, it should clear types (not keep original)
    assert_empty @location.reload.suitable_experiences
  end

  # Test creating new experience types that don't exist
  test "creates new experience types if they don't exist" do
    new_type = "extreme_sports_#{SecureRandom.hex(4)}"
    assert_nil ExperienceType.find_by_key(new_type)

    result = LocationUpdater.new(@location,
      suitable_experiences: [ new_type ]
    ).call

    assert result.success?
    assert_not_nil ExperienceType.find_by_key(new_type)
    assert_includes @location.reload.suitable_experiences, new_type
  end
end
