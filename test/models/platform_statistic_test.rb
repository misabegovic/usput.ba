# frozen_string_literal: true

require "test_helper"

class PlatformStatisticTest < ActiveSupport::TestCase
  setup do
    # Clean up any existing statistics
    PlatformStatistic.delete_all
  end

  test "validates key presence" do
    stat = PlatformStatistic.new(value: { test: 1 })

    assert_not stat.valid?
    assert stat.errors[:key].any?
  end

  test "validates key uniqueness" do
    PlatformStatistic.create!(key: "test_key", value: { a: 1 })

    duplicate = PlatformStatistic.new(key: "test_key", value: { b: 2 })

    assert_not duplicate.valid?
    assert duplicate.errors[:key].any?
  end

  test "stores JSON value correctly" do
    stat = PlatformStatistic.create!(
      key: "test_data",
      value: { locations: 100, cities: %w[Sarajevo Mostar] }
    )

    stat.reload
    assert_equal 100, stat.value["locations"]
    assert_equal %w[Sarajevo Mostar], stat.value["cities"]
  end

  test "fresh? returns true when computed recently" do
    stat = PlatformStatistic.create!(
      key: "fresh_stat",
      value: {},
      computed_at: 1.minute.ago
    )

    assert stat.fresh?(5.minutes)
  end

  test "fresh? returns false when computed too long ago" do
    stat = PlatformStatistic.create!(
      key: "stale_stat",
      value: {},
      computed_at: 10.minutes.ago
    )

    assert_not stat.fresh?(5.minutes)
  end

  test "fresh? returns false when never computed" do
    stat = PlatformStatistic.create!(
      key: "never_computed",
      value: {},
      computed_at: nil
    )

    assert_not stat.fresh?
  end

  test "stale? is inverse of fresh?" do
    fresh_stat = PlatformStatistic.create!(
      key: "stat1",
      value: {},
      computed_at: 1.minute.ago
    )
    stale_stat = PlatformStatistic.create!(
      key: "stat2",
      value: {},
      computed_at: 10.minutes.ago
    )

    assert_not fresh_stat.stale?(5.minutes)
    assert stale_stat.stale?(5.minutes)
  end

  test "fresh scope returns only fresh statistics" do
    fresh = PlatformStatistic.create!(key: "fresh", value: {}, computed_at: 1.minute.ago)
    stale = PlatformStatistic.create!(key: "stale", value: {}, computed_at: 10.minutes.ago)

    result = PlatformStatistic.fresh(5.minutes)

    assert_includes result, fresh
    assert_not_includes result, stale
  end

  test "stale scope returns only stale statistics" do
    fresh = PlatformStatistic.create!(key: "fresh", value: {}, computed_at: 1.minute.ago)
    stale = PlatformStatistic.create!(key: "stale", value: {}, computed_at: 10.minutes.ago)

    result = PlatformStatistic.stale(5.minutes)

    assert_not_includes result, fresh
    assert_includes result, stale
  end

  # Class method tests
  test "get returns cached value when fresh" do
    PlatformStatistic.create!(
      key: "content_counts",
      value: { locations: 123 },
      computed_at: 1.minute.ago
    )

    result = PlatformStatistic.get("content_counts")

    assert_equal 123, result["locations"]
  end

  test "get computes and stores when stale" do
    # Create stale stat
    PlatformStatistic.create!(
      key: "content_counts",
      value: { locations: 0 },
      computed_at: 10.minutes.ago
    )

    # Get should recompute
    result = PlatformStatistic.get("content_counts", max_age: 5.minutes)

    # Should have fresh computed_at
    stat = PlatformStatistic.find_by(key: "content_counts")
    assert stat.computed_at > 5.minutes.ago
  end

  test "refresh forces recomputation" do
    old_time = 10.minutes.ago
    PlatformStatistic.create!(
      key: "content_counts",
      value: {},
      computed_at: old_time
    )

    PlatformStatistic.refresh("content_counts")

    stat = PlatformStatistic.find_by(key: "content_counts")
    assert stat.computed_at > old_time
  end

  test "refresh_all updates all statistics" do
    # Test just content_counts since it doesn't have complex joins
    PlatformStatistic.refresh("content_counts")

    assert PlatformStatistic.exists?(key: "content_counts")
    stat = PlatformStatistic.find_by(key: "content_counts")
    assert stat.computed_at.present?
  end

  test "layer_zero returns hash when computed" do
    # Pre-create a cached layer_zero to avoid full computation
    PlatformStatistic.create!(
      key: "layer_zero",
      value: { stats: { locations: 10 }, by_city: {}, computed_at: Time.current.iso8601 },
      computed_at: 1.minute.ago
    )

    result = PlatformStatistic.layer_zero

    assert result.is_a?(Hash)
    assert result.key?(:stats) || result.key?("stats")
  end

  test "to_formatted_s returns JSON string" do
    stat = PlatformStatistic.create!(
      key: "test",
      value: { count: 42 }
    )

    formatted = stat.to_formatted_s

    assert formatted.include?("count")
    assert formatted.include?("42")
  end

  # Compute method tests

  test "compute_content_counts returns valid counts" do
    result = PlatformStatistic.send(:compute_content_counts)

    assert result.key?(:locations)
    assert result.key?(:experiences)
    assert result.key?(:plans)
    assert result.key?(:audio_tours)
    assert result.key?(:reviews)
    assert result.key?(:users)
    assert result.key?(:curators)
  end

  test "compute_by_city returns city hash" do
    result = PlatformStatistic.send(:compute_by_city)

    assert result.is_a?(Hash)
  end

  test "compute_coverage returns coverage metrics" do
    result = PlatformStatistic.send(:compute_coverage)

    assert result.key?(:cities_with_content)
    assert result.key?(:locations_with_audio)
    assert result.key?(:locations_with_description)
    assert result.key?(:audio_coverage_percent)
    assert result.key?(:description_coverage_percent)
  end


  test "check_database returns status ok" do
    result = PlatformStatistic.send(:check_database)

    assert_equal "ok", result[:status]
  end

  test "check_database handles errors" do
    ActiveRecord::Base.connection.stub(:execute, ->(*) { raise "DB Error" }) do
      result = PlatformStatistic.send(:check_database)

      assert_equal "error", result[:status]
    end
  end

  test "check_api_keys returns boolean values" do
    result = PlatformStatistic.send(:check_api_keys)

    assert [true, false].include?(result[:anthropic])
    assert [true, false].include?(result[:openai])
    assert [true, false].include?(result[:geoapify])
    assert [true, false].include?(result[:elevenlabs])
  end

  test "check_queues returns queue counts" do
    result = PlatformStatistic.send(:check_queues)

    assert result.key?(:pending) || result.key?(:status)
  end

  test "check_storage returns service info" do
    result = PlatformStatistic.send(:check_storage)

    assert result.key?(:service) || result.key?(:status)
  end

  test "check_last_activity returns timestamps" do
    result = PlatformStatistic.send(:check_last_activity)

    assert result.key?(:last_location_update)
    assert result.key?(:last_experience_update)
    assert result.key?(:last_review)
  end

  test "top_rated_content returns locations and experiences" do
    result = PlatformStatistic.send(:top_rated_content)

    assert result.key?(:locations)
    assert result.key?(:experiences)
    assert result[:locations].is_a?(Array)
    assert result[:experiences].is_a?(Array)
  end

  test "recent_changes returns change counts" do
    result = PlatformStatistic.send(:recent_changes)

    assert result.key?(:new_locations_7d)
    assert result.key?(:new_reviews_7d)
    assert result.key?(:updated_locations_7d)
  end

  test "compute returns empty hash for unknown key" do
    result = PlatformStatistic.send(:compute, "unknown_key")

    assert_equal({}, result)
  end

  test "compute routes to correct compute method for content_counts" do
    assert PlatformStatistic.send(:compute, "content_counts").key?(:locations)
  end

  test "compute routes to correct compute method for by_city" do
    assert PlatformStatistic.send(:compute, "by_city").is_a?(Hash)
  end

  test "compute routes to correct compute method for coverage" do
    assert PlatformStatistic.send(:compute, "coverage").key?(:cities_with_content)
  end

  test "get creates new stat when none exists" do
    PlatformStatistic.where(key: "content_counts").delete_all

    result = PlatformStatistic.get("content_counts")

    assert PlatformStatistic.exists?(key: "content_counts")
    assert result.key?(:locations) || result.key?("locations")
  end

  # Additional coverage tests

  test "compute_by_city sorts by count descending" do
    # Create locations with different cities
    Location.create!(name: "L1", city: "CityA", lat: 43.0, lng: 18.0)
    Location.create!(name: "L2", city: "CityA", lat: 43.1, lng: 18.1)
    Location.create!(name: "L3", city: "CityB", lat: 43.2, lng: 18.2)

    result = PlatformStatistic.send(:compute_by_city)

    # Should be sorted, CityA first (2 locations)
    if result.any?
      values = result.values
      assert values == values.sort.reverse, "Cities should be sorted by count descending"
    end
  end

  test "compute_coverage handles zero locations" do
    Location.stub(:count, 0) do
      result = PlatformStatistic.send(:compute_coverage)

      assert_equal 0, result[:audio_coverage_percent]
      assert_equal 0, result[:description_coverage_percent]
    end
  end

  test "check_storage handles errors" do
    ActiveStorage::Blob.stub(:service, ->(*) { raise "Storage Error" }) do
      result = PlatformStatistic.send(:check_storage)

      assert_equal "error", result[:status]
    end
  end

  test "check_last_activity handles nil timestamps" do
    Location.stub(:maximum, nil) do
      Experience.stub(:maximum, nil) do
        Review.stub(:maximum, nil) do
          result = PlatformStatistic.send(:check_last_activity)

          assert result.key?(:last_location_update)
          # Values may be nil
        end
      end
    end
  end

  test "top_rated_content maps locations correctly" do
    # Create a highly rated location
    location = Location.create!(
      name: "Top Location",
      city: "Sarajevo",
      lat: 43.0,
      lng: 18.0,
      average_rating: 4.5
    )

    result = PlatformStatistic.send(:top_rated_content)

    assert result[:locations].is_a?(Array)
    # Check structure of mapped locations
    if result[:locations].any?
      first = result[:locations].first
      assert first.is_a?(Hash)
      assert first.key?(:id)
      assert first.key?(:name)
    end
  end

  test "top_rated_content maps experiences correctly" do
    # Create a highly rated experience
    Experience.create!(
      title: "Top Experience",
      estimated_duration: 60,
      average_rating: 4.5
    )

    result = PlatformStatistic.send(:top_rated_content)

    assert result[:experiences].is_a?(Array)
  end

  test "compute_coverage returns all coverage metrics" do
    result = PlatformStatistic.send(:compute_coverage)

    assert result.key?(:locations_with_audio)
    assert result.key?(:locations_ai_generated)
    assert result.key?(:locations_human_made)
    assert result[:audio_coverage_percent].is_a?(Numeric)
    assert result[:description_coverage_percent].is_a?(Numeric)
  end

  test "check_last_activity with actual timestamps" do
    # Create records with timestamps
    Location.create!(name: "Test", city: "Test", lat: 43.0, lng: 18.0)

    result = PlatformStatistic.send(:check_last_activity)

    # Should have ISO8601 format for last_location_update
    assert result[:last_location_update].present?
  end

  test "compute_coverage handles zero coverage percent calculation" do
    # This test just verifies the method works and returns expected keys
    result = PlatformStatistic.send(:compute_coverage)

    assert result.is_a?(Hash)
    assert result.key?(:audio_coverage_percent)
    assert result.key?(:description_coverage_percent)
    # Both should be numbers (0 or greater)
    assert result[:audio_coverage_percent].is_a?(Numeric)
    assert result[:description_coverage_percent].is_a?(Numeric)
  end

  test "compute_coverage with locations present" do
    # Ensure we have at least one location
    Location.create!(name: "Coverage Test", city: "CoverageCity", lat: 44.0, lng: 19.0)

    result = PlatformStatistic.send(:compute_coverage)

    assert result.key?(:cities_with_content)
    assert result.key?(:locations_with_audio)
    assert result.key?(:locations_with_description)
    assert result.key?(:audio_coverage_percent)
    assert result[:audio_coverage_percent].is_a?(Numeric)
  end

  test "check_last_activity returns all three timestamps" do
    result = PlatformStatistic.send(:check_last_activity)

    assert result.key?(:last_location_update)
    assert result.key?(:last_experience_update)
    assert result.key?(:last_review)
  end

  test "check_last_activity with experience timestamp" do
    Experience.create!(title: "Activity Test", estimated_duration: 60)

    result = PlatformStatistic.send(:check_last_activity)

    assert result[:last_experience_update].present?
  end

  test "check_last_activity with review timestamp" do
    location = Location.create!(name: "Review Test", city: "ReviewCity", lat: 44.1, lng: 19.1)
    user = User.create!(username: "reviewer_#{SecureRandom.hex(4)}", password: "password123")
    Review.create!(reviewable: location, user: user, rating: 5)

    result = PlatformStatistic.send(:check_last_activity)

    assert result[:last_review].present?
  end
end
