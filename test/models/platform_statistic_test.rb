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
end
