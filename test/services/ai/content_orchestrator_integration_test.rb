# frozen_string_literal: true

require "test_helper"

module Ai
  class ContentOrchestratorIntegrationTest < ActiveSupport::TestCase
    setup do
      # Clear any generation status
      Ai::ContentOrchestrator.force_reset!
    end

    teardown do
      Ai::ContentOrchestrator.force_reset!
    end

    # === Skip options tests ===
    # These tests verify that skip options are properly passed and stored

    test "skip options are stored correctly in results" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(
          skip_locations: true,
          skip_experiences: false,
          skip_plans: true
        )

        results = orchestrator.instance_variable_get(:@results)

        assert results[:skipped][:locations], "Should indicate locations are skipped"
        assert_not results[:skipped][:experiences], "Should indicate experiences are NOT skipped"
        assert results[:skipped][:plans], "Should indicate plans are skipped"
      end
    end

    test "skip_locations flag is stored in instance variable" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(skip_locations: true)
        assert orchestrator.instance_variable_get(:@skip_locations)
      end
    end

    test "skip_experiences flag is stored in instance variable" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(skip_experiences: true)
        assert orchestrator.instance_variable_get(:@skip_experiences)
      end
    end

    test "skip_plans flag is stored in instance variable" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(skip_plans: true)
        assert orchestrator.instance_variable_get(:@skip_plans)
      end
    end

    # === Default max_experiences tests ===

    test "default max_experiences is 200 when nil is passed" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_experiences: nil)

        assert_equal 200, orchestrator.instance_variable_get(:@max_experiences)
      end
    end

    test "custom max_experiences is respected" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_experiences: 50)

        assert_equal 50, orchestrator.instance_variable_get(:@max_experiences)
      end
    end

    test "experiences_limit_reached is true when at max" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_experiences: 2)

        # Simulate already having created 2 experiences
        orchestrator.instance_variable_get(:@results)[:experiences_created] = 2

        # Should be at limit
        assert orchestrator.send(:experiences_limit_reached?)
      end
    end

    test "experiences_limit_reached is false when under max" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_experiences: 10)

        # Simulate having created 5 experiences
        orchestrator.instance_variable_get(:@results)[:experiences_created] = 5

        # Should not be at limit
        refute orchestrator.send(:experiences_limit_reached?)
      end
    end

    test "remaining_experience_slots calculates correctly" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_experiences: 10)

        orchestrator.instance_variable_get(:@results)[:experiences_created] = 3

        assert_equal 7, orchestrator.send(:remaining_experience_slots)
      end
    end

    test "remaining_experience_slots returns 0 when over limit" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_experiences: 5)

        # Simulate having created more than max
        orchestrator.instance_variable_get(:@results)[:experiences_created] = 10

        assert_equal 0, orchestrator.send(:remaining_experience_slots)
      end
    end

    # === Default max_locations tests ===

    test "default max_locations is 100 when nil is passed" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_locations: nil)

        assert_equal 100, orchestrator.instance_variable_get(:@max_locations)
      end
    end

    test "custom max_locations is respected" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_locations: 25)

        assert_equal 25, orchestrator.instance_variable_get(:@max_locations)
      end
    end

    test "max_locations 0 means unlimited (nil)" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_locations: 0)

        assert_nil orchestrator.instance_variable_get(:@max_locations)
      end
    end

    test "locations_limit_reached is true when at max" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_locations: 5)

        orchestrator.instance_variable_get(:@results)[:locations_created] = 5

        assert orchestrator.send(:locations_limit_reached?)
      end
    end

    test "locations_limit_reached is false when under max" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_locations: 10)

        orchestrator.instance_variable_get(:@results)[:locations_created] = 3

        refute orchestrator.send(:locations_limit_reached?)
      end
    end

    test "locations_limit_reached is false when unlimited" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_locations: 0)

        orchestrator.instance_variable_get(:@results)[:locations_created] = 1000

        refute orchestrator.send(:locations_limit_reached?)
      end
    end

    test "remaining_location_slots calculates correctly" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_locations: 10)

        orchestrator.instance_variable_get(:@results)[:locations_created] = 3

        assert_equal 7, orchestrator.send(:remaining_location_slots)
      end
    end

    # === Default max_plans tests ===

    test "default max_plans is 50 when nil is passed" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_plans: nil)

        assert_equal 50, orchestrator.instance_variable_get(:@max_plans)
      end
    end

    test "custom max_plans is respected" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_plans: 25)

        assert_equal 25, orchestrator.instance_variable_get(:@max_plans)
      end
    end

    test "max_plans 0 means unlimited (nil)" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_plans: 0)

        assert_nil orchestrator.instance_variable_get(:@max_plans)
      end
    end

    test "plans_limit_reached is true when at max" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_plans: 5)

        orchestrator.instance_variable_get(:@results)[:plans_created] = 5

        assert orchestrator.send(:plans_limit_reached?)
      end
    end

    test "plans_limit_reached is false when under max" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_plans: 10)

        orchestrator.instance_variable_get(:@results)[:plans_created] = 3

        refute orchestrator.send(:plans_limit_reached?)
      end
    end

    test "plans_limit_reached is false when unlimited" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_plans: 0)

        orchestrator.instance_variable_get(:@results)[:plans_created] = 1000

        refute orchestrator.send(:plans_limit_reached?)
      end
    end

    test "remaining_plan_slots calculates correctly" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_plans: 10)

        orchestrator.instance_variable_get(:@results)[:plans_created] = 3

        assert_equal 7, orchestrator.send(:remaining_plan_slots)
      end
    end

    test "max_experiences 0 means unlimited (nil)" do
      GeoapifyService.stub(:new, -> { Object.new }) do
        orchestrator = Ai::ContentOrchestrator.new(max_experiences: 0)

        assert_nil orchestrator.instance_variable_get(:@max_experiences)
      end
    end

    # === Constants tests ===

    test "DEFAULT_MAX_LOCATIONS is 100" do
      assert_equal 100, Ai::ContentOrchestrator::DEFAULT_MAX_LOCATIONS
    end

    test "DEFAULT_MAX_EXPERIENCES is 200" do
      assert_equal 200, Ai::ContentOrchestrator::DEFAULT_MAX_EXPERIENCES
    end

    test "DEFAULT_MAX_PLANS is 50" do
      assert_equal 50, Ai::ContentOrchestrator::DEFAULT_MAX_PLANS
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

    test "force_reset! resets status to idle" do
      Setting.set("ai.generation.status", "in_progress")
      Setting.set("ai.generation.cancelled", "true")

      Ai::ContentOrchestrator.force_reset!

      assert_equal "idle", Setting.get("ai.generation.status")
      assert_equal "false", Setting.get("ai.generation.cancelled")
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
  end
end
