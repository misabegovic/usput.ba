# frozen_string_literal: true

require "test_helper"

module Ai
  class PlanAnalyzerIntegrationTest < ActiveSupport::TestCase
    setup do
      @analyzer = Ai::PlanAnalyzer.new
      @city = "Sarajevo"

      # Create experience for plans
      @experience = Experience.create!(title: "Test Experience")
    end

    # === Unlimited limit tests ===

    test "generate_report with limit: nil returns all plans without truncation" do
      # Create 25 AI-generated plans with issues (more than default limit of 20)
      plans = []
      25.times do |i|
        plan = Plan.create!(
          title: "Test Plan #{i}",
          city_name: @city,
          user_id: nil
        )
        # Add an experience so it won't be marked for deletion
        plan.plan_experiences.create!(experience: @experience, day_number: 1, position: 1)
        plans << plan
      end

      # Generate report with unlimited (nil) limit
      report = @analyzer.generate_report(limit: nil)

      # Should return all 25 plans, not truncated to 20
      assert_equal 25, report[:worst_plans].length + report[:deletable_plans].length,
                   "With nil limit, should return all plans needing action"
    end

    test "generate_report with limit: 20 (default) truncates results" do
      # Create 25 AI-generated plans with issues
      plans = []
      25.times do |i|
        plan = Plan.create!(
          title: "Short", # Short title = quality issue
          city_name: @city,
          user_id: nil
        )
        plan.plan_experiences.create!(experience: @experience, day_number: 1, position: 1)
        plans << plan
      end

      # Generate report with default limit
      report = @analyzer.generate_report

      # Should truncate to 20
      assert report[:worst_plans].length <= 20, "Default limit should cap worst_plans at 20"
      assert report[:deletable_plans].length <= 20, "Default limit should cap deletable_plans at 20"
    end

    test "generate_report similar_plans uses limit / 2" do
      # Create many similar plan pairs
      # First, create base plans
      15.times do |i|
        # Create two similar plans (same city, same profile)
        plan1 = Plan.create!(
          title: "Family Sarajevo Tour Part 1",
          city_name: @city,
          user_id: nil,
          preferences: { "tourist_profile" => "family" }
        )
        plan1.plan_experiences.create!(experience: @experience, day_number: 1, position: 1)

        plan2 = Plan.create!(
          title: "Family Sarajevo Tour Part 2",
          city_name: @city,
          user_id: nil,
          preferences: { "tourist_profile" => "family" }
        )
        plan2.plan_experiences.create!(experience: @experience, day_number: 1, position: 1)
      end

      # With limit: 20, similar_plans should be capped at 10 (20/2)
      report = @analyzer.generate_report(limit: 20)
      assert report[:similar_plans].length <= 10, "Similar plans should be limited to limit/2"

      # With nil limit, all similar plans should be returned
      report_unlimited = @analyzer.generate_report(limit: nil)
      # Note: exact count depends on similarity calculation
      assert report_unlimited[:similar_plans].length >= report[:similar_plans].length,
             "Unlimited should return at least as many similar plans as limited"
    end

    test "generate_report with custom limit respects that limit" do
      # Create 15 AI-generated plans
      15.times do |i|
        plan = Plan.create!(
          title: "Test Plan #{i}",
          city_name: @city,
          user_id: nil
        )
        plan.plan_experiences.create!(experience: @experience, day_number: 1, position: 1)
      end

      # Use small limit
      report = @analyzer.generate_report(limit: 5)

      assert report[:worst_plans].length <= 5, "Should respect custom limit for worst_plans"
      assert report[:deletable_plans].length <= 5, "Should respect custom limit for deletable_plans"
      assert report[:similar_plans].length <= 2, "Similar plans should be limit/2 = 2"
    end

    # === Score calculation tests ===

    test "plans with critical issues have score <= 70" do
      # Create plan with critical issues (no experiences)
      plan = Plan.create!(
        title: "Test Plan",
        city_name: @city,
        user_id: nil
      )
      # Don't add experiences - this is a critical issue

      result = @analyzer.analyze(plan)

      assert result[:score] <= 70, "Critical issue (no experiences) should reduce score significantly"
      assert result[:issues].any? { |i| i[:severity] == :critical }, "Should have critical issues"
    end

    test "plans with ekavica have high severity issues" do
      plan = Plan.create!(
        title: "Lepo mesto za posetu", # Ekavica words
        city_name: @city,
        user_id: nil
      )
      plan.plan_experiences.create!(experience: @experience, day_number: 1, position: 1)

      # Set Bosnian title translation with ekavica
      plan.set_translation(:title, "Lepo mesto za posetu", :bs)
      plan.save!

      result = @analyzer.analyze(plan)

      ekavica_issues = result[:issues].select { |i| i[:type] == :ekavica_violation }
      assert ekavica_issues.any?, "Should detect ekavica violations"
      assert ekavica_issues.first[:severity] == :high, "Ekavica should be high severity"
    end

    test "user-owned plans are skipped" do
      user = User.create!(username: "testuser", password: "password123")

      plan = Plan.create!(
        title: "User Plan",
        city_name: @city,
        user: user
      )

      result = @analyzer.analyze(plan)

      assert result[:skipped], "User-owned plan should be skipped"
      assert_equal "User-owned plan", result[:skip_reason]
      assert_equal 100, result[:score], "Skipped plans should have score 100"
    end

    test "plans with score <= 20 should be marked for deletion" do
      # Create plan with many issues to get very low score
      plan = Plan.create!(
        title: "X", # Too short
        city_name: @city,
        user_id: nil
      )
      # No experiences = critical issue
      # No translations = more issues

      result = @analyzer.analyze(plan)

      assert result[:should_delete], "Very low score plan should be marked for deletion"
      assert result[:delete_reason].present?, "Should have delete reason"
    end
  end
end
