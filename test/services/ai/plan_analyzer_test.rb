# frozen_string_literal: true

require "test_helper"

module Ai
  class PlanAnalyzerTest < ActiveSupport::TestCase
    setup do
      @analyzer = Ai::PlanAnalyzer.new
    end

    # === generate_report limit parameter tests ===

    test "generate_report accepts limit parameter" do
      assert_nothing_raised do
        @analyzer.generate_report(limit: 10)
      end
    end

    test "generate_report with limit nil returns all results" do
      report = @analyzer.generate_report(limit: nil)

      # With nil limit, should return all plans needing rebuild
      assert report[:worst_plans].is_a?(Array)
    end

    test "generate_report with limit restricts worst_plans count" do
      report = @analyzer.generate_report(limit: 5)

      assert report[:worst_plans].length <= 5
    end

    test "generate_report with limit restricts deletable_plans count" do
      report = @analyzer.generate_report(limit: 5)

      assert report[:deletable_plans].length <= 5
    end

    test "generate_report with limit restricts similar_plans count" do
      report = @analyzer.generate_report(limit: 10)

      # similar_plans uses limit / 2
      assert report[:similar_plans].length <= 5
    end

    test "generate_report default limit is 20" do
      report = @analyzer.generate_report

      assert report[:worst_plans].length <= 20
      assert report[:deletable_plans].length <= 20
      assert report[:similar_plans].length <= 10
    end

    # === Report structure tests ===

    test "generate_report returns expected keys" do
      report = @analyzer.generate_report

      assert_includes report.keys, :total_plans
      assert_includes report.keys, :plans_with_issues
      assert_includes report.keys, :plans_needing_rebuild
      assert_includes report.keys, :plans_to_delete
      assert_includes report.keys, :similar_plan_pairs
      assert_includes report.keys, :issues_by_severity
      assert_includes report.keys, :issues_by_type
      assert_includes report.keys, :worst_plans
      assert_includes report.keys, :deletable_plans
      assert_includes report.keys, :similar_plans
    end

    # === Score threshold tests ===

    test "DELETE_THRESHOLD_SCORE is defined" do
      assert_equal 20, Ai::PlanAnalyzer::DELETE_THRESHOLD_SCORE
    end

    test "SIMILARITY_THRESHOLD is defined" do
      assert_equal 0.7, Ai::PlanAnalyzer::SIMILARITY_THRESHOLD
    end
  end
end
