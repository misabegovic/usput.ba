# frozen_string_literal: true

require "test_helper"

module Ai
  class ContentOrchestratorTest < ActiveSupport::TestCase
    # === Constants tests ===

    test "DEFAULT_MAX_EXPERIENCES is defined as 200" do
      assert_equal 200, Ai::ContentOrchestrator::DEFAULT_MAX_EXPERIENCES
    end

    # === Status methods tests ===

    test "current_status returns hash with expected keys" do
      status = Ai::ContentOrchestrator.current_status

      assert status.is_a?(Hash)
      assert_includes status.keys, :status
      assert_includes status.keys, :message
      assert_includes status.keys, :started_at
      assert_includes status.keys, :plan
      assert_includes status.keys, :results
    end

    test "cancel_generation! sets cancelled flag" do
      Ai::ContentOrchestrator.clear_cancellation!
      assert_equal false, Ai::ContentOrchestrator.cancelled?

      Ai::ContentOrchestrator.cancel_generation!

      assert_equal true, Ai::ContentOrchestrator.cancelled?
    end

    test "clear_cancellation! clears cancelled flag" do
      Ai::ContentOrchestrator.cancel_generation!
      assert_equal true, Ai::ContentOrchestrator.cancelled?

      Ai::ContentOrchestrator.clear_cancellation!

      assert_equal false, Ai::ContentOrchestrator.cancelled?
    end

    test "force_reset! resets all status" do
      Setting.set("ai.generation.status", "in_progress")
      Setting.set("ai.generation.cancelled", "true")

      Ai::ContentOrchestrator.force_reset!

      assert_equal "idle", Setting.get("ai.generation.status")
      assert_equal "false", Setting.get("ai.generation.cancelled")
    end

    # === content_stats tests ===

    test "content_stats returns hash with cities and totals" do
      stats = Ai::ContentOrchestrator.content_stats

      assert stats.is_a?(Hash)
      assert_includes stats.keys, :cities
      assert_includes stats.keys, :totals
      assert stats[:cities].is_a?(Array)
      assert stats[:totals].is_a?(Hash)
    end

    test "content_stats totals include expected keys" do
      stats = Ai::ContentOrchestrator.content_stats

      assert_includes stats[:totals].keys, :locations
      assert_includes stats[:totals].keys, :experiences
      assert_includes stats[:totals].keys, :plans
      assert_includes stats[:totals].keys, :ai_plans
      assert_includes stats[:totals].keys, :audio
    end

    # === Error classes tests ===

    test "GenerationError is a subclass of StandardError" do
      assert Ai::ContentOrchestrator::GenerationError < StandardError
    end

    test "CancellationError is a subclass of StandardError" do
      assert Ai::ContentOrchestrator::CancellationError < StandardError
    end
  end
end
