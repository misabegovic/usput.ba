require "test_helper"

class SyncExperienceTypesFromJsonTest < ActiveSupport::TestCase
  setup do
    # Create test experience types
    @culture = ExperienceType.find_or_create_by!(key: "culture") do |et|
      et.name = "Culture"
      et.active = true
    end

    @history = ExperienceType.find_or_create_by!(key: "history") do |et|
      et.name = "History"
      et.active = true
    end

    @food = ExperienceType.find_or_create_by!(key: "food") do |et|
      et.name = "Food"
      et.active = true
    end
  end

  # Helper method to simulate migration logic
  def sync_experience_types_from_json
    Location.find_each do |location|
      suitable_experiences = location.read_attribute(:suitable_experiences)
      next if suitable_experiences.blank?

      keys = Array(suitable_experiences).map(&:to_s).map(&:downcase).uniq

      keys.each do |key|
        exp_type = ExperienceType.find_by("LOWER(key) = ?", key)
        next unless exp_type

        LocationExperienceType.find_or_initialize_by(
          location_id: location.id,
          experience_type_id: exp_type.id
        ).save!
      end
    end
  end

  test "syncs experience types from JSON to relational data" do
    # Create a location with suitable_experiences JSON but no relations
    location = Location.create!(
      name: "Test Location",
      city: "Test City",
      lat: 43.8564,
      lng: 18.4131
    )

    # Manually set the JSON field without triggering callbacks
    location.update_column(:suitable_experiences, [ "culture", "history" ])

    # Remove any existing relations (in case callbacks created them)
    location.location_experience_types.destroy_all

    # Verify no relations exist
    assert_equal 0, location.location_experience_types.count

    # Run the sync
    sync_experience_types_from_json

    # Verify relations were created
    location.reload
    assert_equal 2, location.location_experience_types.count
    assert_includes location.experience_types.pluck(:key), "culture"
    assert_includes location.experience_types.pluck(:key), "history"
  end

  test "handles locations with empty suitable_experiences" do
    # Create location with no suitable_experiences
    location = Location.create!(
      name: "Empty Location",
      city: "Test City",
      lat: 43.8565,
      lng: 18.4132
    )

    location.update_column(:suitable_experiences, nil)

    # Run sync
    sync_experience_types_from_json

    # Verify no relations were created
    location.reload
    assert_equal 0, location.location_experience_types.count
  end

  test "does not create duplicate relations" do
    # Create location with JSON data
    location = Location.create!(
      name: "Duplicate Test",
      city: "Test City",
      lat: 43.8566,
      lng: 18.4133
    )

    location.update_column(:suitable_experiences, [ "culture" ])

    # Create one relation manually
    LocationExperienceType.create!(
      location: location,
      experience_type: @culture
    )

    assert_equal 1, location.location_experience_types.count

    # Run sync
    sync_experience_types_from_json

    # Verify no duplicate was created
    location.reload
    assert_equal 1, location.location_experience_types.count
  end

  test "handles missing experience types gracefully" do
    # Create location with JSON that includes non-existent type
    location = Location.create!(
      name: "Missing Type Test",
      city: "Test City",
      lat: 43.8567,
      lng: 18.4134
    )

    location.update_column(:suitable_experiences, [ "culture", "nonexistent" ])
    location.location_experience_types.destroy_all

    # Run sync (should not raise error)
    assert_nothing_raised do
      sync_experience_types_from_json
    end

    # Verify only valid type was synced
    location.reload
    assert_equal 1, location.location_experience_types.count
    assert_equal "culture", location.experience_types.first.key
  end

  test "handles case-insensitive experience type keys" do
    # Create location with mixed case keys
    location = Location.create!(
      name: "Case Test",
      city: "Test City",
      lat: 43.8568,
      lng: 18.4135
    )

    location.update_column(:suitable_experiences, [ "Culture", "HISTORY" ])
    location.location_experience_types.destroy_all

    # Run sync
    sync_experience_types_from_json

    # Verify relations were created (case-insensitive match)
    location.reload
    assert_equal 2, location.location_experience_types.count
    assert_includes location.experience_types.pluck(:key), "culture"
    assert_includes location.experience_types.pluck(:key), "history"
  end

  test "processes multiple locations in batch" do
    # Create multiple locations with JSON data
    locations = []
    3.times do |i|
      location = Location.create!(
        name: "Batch Test #{i}",
        city: "Test City",
        lat: 43.8570 + i * 0.001,
        lng: 18.4136 + i * 0.001
      )
      location.update_column(:suitable_experiences, [ "culture", "food" ])
      location.location_experience_types.destroy_all
      locations << location
    end

    # Run sync
    sync_experience_types_from_json

    # Verify all locations were processed
    locations.each do |location|
      location.reload
      assert_equal 2, location.location_experience_types.count,
        "Location #{location.name} should have 2 relations"
    end
  end
end
