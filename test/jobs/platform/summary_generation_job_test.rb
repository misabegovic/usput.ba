# frozen_string_literal: true

require "test_helper"

class Platform::SummaryGenerationJobTest < ActiveSupport::TestCase
  setup do
    KnowledgeSummary.delete_all

    # Create test location
    @location = Location.create!(
      name: "Test Location",
      city: "TestJobCity",
      lat: 43.8,
      lng: 18.4
    )
  end

  test "perform generates summary for specific city" do
    Platform::SummaryGenerationJob.perform_now(dimension: "city", value: "TestJobCity")

    assert KnowledgeSummary.exists?(dimension: "city", dimension_value: "TestJobCity")
  end

  test "perform generates all summaries for dimension" do
    # Create another location in different city
    Location.create!(
      name: "Another Location",
      city: "AnotherCity",
      lat: 44.0,
      lng: 19.0
    )

    Platform::SummaryGenerationJob.perform_now(dimension: "city")

    assert KnowledgeSummary.exists?(dimension: "city", dimension_value: "TestJobCity")
    assert KnowledgeSummary.exists?(dimension: "city", dimension_value: "AnotherCity")
  end

  test "perform handles missing data gracefully" do
    # Should not raise for non-existent city
    assert_nothing_raised do
      Platform::SummaryGenerationJob.perform_now(dimension: "city", value: "NonExistent")
    end
  end

  test "perform updates computed_at timestamp" do
    before_time = Time.current

    Platform::SummaryGenerationJob.perform_now(dimension: "city", value: "TestJobCity")

    summary = KnowledgeSummary.find_by(dimension: "city", dimension_value: "TestJobCity")
    assert summary.generated_at >= before_time
  end

  test "perform generates all summaries when no dimension specified" do
    Platform::SummaryGenerationJob.perform_now

    assert KnowledgeSummary.exists?(dimension: "city", dimension_value: "TestJobCity")
  end

  test "perform handles category dimension" do
    # Ensure at least one category exists for the iteration
    LocationCategory.create!(key: "test_cat_#{SecureRandom.hex(4)}", name: "Test Category")

    assert_nothing_raised do
      Platform::SummaryGenerationJob.perform_now(dimension: "category")
    end
  end

  test "perform generates summaries for each category" do
    # Create categories with required name field
    LocationCategory.create!(key: "cat_job_test_1_#{SecureRandom.hex(4)}", name: "Category One")
    LocationCategory.create!(key: "cat_job_test_2_#{SecureRandom.hex(4)}", name: "Category Two")

    # This should iterate over categories and call generate_single for each
    assert_nothing_raised do
      Platform::SummaryGenerationJob.perform_now(dimension: "category")
    end
  end

  test "perform warns for unknown dimension" do
    assert_nothing_raised do
      Platform::SummaryGenerationJob.perform_now(dimension: "unknown_dimension")
    end
  end

  test "perform handles no return from generate_summary" do
    Platform::Knowledge::LayerOne.stub(:generate_summary, nil) do
      assert_nothing_raised do
        Platform::SummaryGenerationJob.perform_now(dimension: "city", value: "TestJobCity")
      end
    end
  end
end
