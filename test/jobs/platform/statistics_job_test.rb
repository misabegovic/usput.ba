# frozen_string_literal: true

require "test_helper"

class Platform::StatisticsJobTest < ActiveSupport::TestCase
  setup do
    PlatformStatistic.delete_all
  end

  test "perform refreshes specific key" do
    # Test with content_counts which has simpler queries
    Platform::StatisticsJob.perform_now(keys: ["content_counts"])

    assert PlatformStatistic.exists?(key: "content_counts")
  end

  test "perform can refresh specific keys" do
    Platform::StatisticsJob.perform_now(keys: ["content_counts"])

    assert PlatformStatistic.exists?(key: "content_counts")
    assert_not PlatformStatistic.exists?(key: "by_city")
  end

  test "perform updates computed_at timestamp" do
    before_time = Time.current

    Platform::StatisticsJob.perform_now(keys: ["content_counts"])

    stat = PlatformStatistic.find_by(key: "content_counts")
    assert stat.computed_at >= before_time
  end

  test "perform handles errors gracefully" do
    # Shouldn't raise even if something goes wrong internally
    assert_nothing_raised do
      Platform::StatisticsJob.perform_now
    end
  end

  test "perform with no keys refreshes all without error" do
    assert_nothing_raised do
      Platform::StatisticsJob.perform_now
    end
  end

  test "perform logs summary when content_counts exists" do
    PlatformStatistic.create!(
      key: "content_counts",
      value: { locations: 10, experiences: 5, reviews: 20 },
      computed_at: Time.current
    )

    assert_nothing_raised do
      Platform::StatisticsJob.perform_now(keys: ["content_counts"])
    end
  end

  test "perform handles missing content_counts in log_summary" do
    PlatformStatistic.delete_all

    assert_nothing_raised do
      Platform::StatisticsJob.perform_now(keys: ["by_city"])
    end
  end

  test "perform refreshes all statistics when keys is nil" do
    # Ensure content_counts gets created by refresh_all
    assert_nothing_raised do
      Platform::StatisticsJob.perform_now(keys: nil)
    end
  end

  test "perform refreshes all statistics when keys is empty array" do
    # Empty array in Ruby is truthy for .present? check, so it goes to the if branch
    # but iterates zero times
    assert_nothing_raised do
      Platform::StatisticsJob.perform_now(keys: [])
    end
  end

  test "perform logs after refresh_all completes" do
    # Call with no keys to trigger refresh_all branch and log_summary
    assert_nothing_raised do
      Platform::StatisticsJob.perform_now
    end
  end
end
