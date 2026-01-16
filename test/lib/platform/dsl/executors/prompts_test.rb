# frozen_string_literal: true

require "test_helper"

class Platform::DSL::Executors::PromptsTest < ActiveSupport::TestCase
  setup do
    @prompt = PreparedPrompt.create!(
      prompt_type: "fix",
      title: "Test Fix Prompt",
      content: "Test content for fix",
      status: "pending",
      severity: "medium"
    )

    @feature_prompt = PreparedPrompt.create!(
      prompt_type: "feature",
      title: "Test Feature Prompt",
      content: "Test content for feature",
      status: "pending",
      severity: "low"
    )
  end

  # ===================
  # Prompts Query Tests
  # ===================

  test "execute_prompts_query lists prompts by default" do
    ast = { filters: {} }

    result = Platform::DSL::Executors::Prompts.execute_prompts_query(ast)

    assert_equal :list_prompts, result[:action]
    assert result[:prompts].is_a?(Array)
  end

  test "execute_prompts_query with nil operations lists prompts" do
    ast = { filters: {}, operations: nil }

    result = Platform::DSL::Executors::Prompts.execute_prompts_query(ast)

    assert_equal :list_prompts, result[:action]
  end

  test "execute_prompts_query shows prompt" do
    ast = {
      filters: { id: @prompt.id },
      operations: [{ name: :show }]
    }

    result = Platform::DSL::Executors::Prompts.execute_prompts_query(ast)

    assert_equal :show_prompt, result[:action]
    assert result[:prompt].present?
    assert_equal @prompt.id, result[:prompt][:id]
  end

  test "execute_prompts_query counts prompts" do
    ast = {
      filters: {},
      operations: [{ name: :count }]
    }

    result = Platform::DSL::Executors::Prompts.execute_prompts_query(ast)

    # count_prompts returns total, pending, etc. keys
    assert result[:total] >= 0
    assert result[:pending].present? || result[:pending] == 0
  end

  test "execute_prompts_query with pending operation" do
    ast = {
      filters: {},
      operations: [{ name: :pending }]
    }

    result = Platform::DSL::Executors::Prompts.execute_prompts_query(ast)

    assert_equal :list_prompts, result[:action]
  end

  test "execute_prompts_query with unknown operation falls back to list" do
    ast = {
      filters: {},
      operations: [{ name: :unknown_operation }]
    }

    result = Platform::DSL::Executors::Prompts.execute_prompts_query(ast)

    assert_equal :list_prompts, result[:action]
  end

  test "execute_prompts_query exports prompt" do
    ast = {
      filters: { id: @prompt.id },
      operations: [{ name: :export }]
    }

    result = Platform::DSL::Executors::Prompts.execute_prompts_query(ast)

    assert_equal :export_prompt, result[:action]
    assert_equal @prompt.id, result[:prompt_id]
  end

  # ===================
  # Improvement Tests
  # ===================

  test "execute_improvement creates fix prompt" do
    ast = {
      improvement_type: :fix,
      description: "Fix the broken button in the header",
      severity: "high"
    }

    # Stub the LLM calls
    Platform::DSL::Executors::Prompts.stub(:generate_with_llm, "AI response") do
      result = Platform::DSL::Executors::Prompts.execute_improvement(ast)

      assert result[:success]
      assert_equal :prepare_prompt, result[:action]
      assert_equal "fix", result[:type]
    end
  end

  test "execute_improvement creates feature prompt" do
    ast = {
      improvement_type: :feature,
      description: "Add dark mode support",
      severity: "medium"
    }

    Platform::DSL::Executors::Prompts.stub(:generate_with_llm, "AI analysis") do
      result = Platform::DSL::Executors::Prompts.execute_improvement(ast)

      assert result[:success]
      assert_equal "feature", result[:type]
    end
  end

  test "execute_improvement creates improvement prompt" do
    ast = {
      improvement_type: :improvement,
      description: "Improve performance of search",
      severity: "low"
    }

    Platform::DSL::Executors::Prompts.stub(:generate_with_llm, "AI analysis") do
      result = Platform::DSL::Executors::Prompts.execute_improvement(ast)

      assert result[:success]
      assert_equal "improvement", result[:type]
    end
  end

  test "execute_improvement with unknown type defaults to fix" do
    ast = {
      improvement_type: :unknown_type,
      description: "Some description",
      severity: "low"
    }

    Platform::DSL::Executors::Prompts.stub(:generate_with_llm, "AI analysis") do
      result = Platform::DSL::Executors::Prompts.execute_improvement(ast)

      assert result[:success]
      assert_equal "fix", result[:type]
    end
  end

  test "execute_improvement raises without description" do
    ast = {
      improvement_type: :fix,
      description: nil,
      severity: "high"
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Prompts.execute_improvement(ast)
    end

    assert_match(/Potreban opis/i, error.message)
  end

  # ===================
  # Prompt Action Tests
  # ===================

  test "execute_prompt_action applies prompt" do
    ast = {
      action: :apply,
      filters: { id: @prompt.id }
    }

    result = Platform::DSL::Executors::Prompts.execute_prompt_action(ast)

    assert_equal :apply_prompt, result[:action]
    @prompt.reload
    assert_equal "applied", @prompt.status
  end

  test "execute_prompt_action rejects prompt with reason" do
    ast = {
      action: :reject,
      filters: { id: @prompt.id },
      reason: "Not needed anymore"
    }

    result = Platform::DSL::Executors::Prompts.execute_prompt_action(ast)

    assert_equal :reject_prompt, result[:action]
    @prompt.reload
    assert_equal "rejected", @prompt.status
  end

  test "execute_prompt_action raises for unknown action" do
    ast = {
      action: :unknown_action,
      filters: { id: @prompt.id }
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Prompts.execute_prompt_action(ast)
    end

    assert_match(/Nepoznata prompt akcija/i, error.message)
  end

  # ===================
  # Helper Tests
  # ===================

  test "list_prompts with status filter" do
    result = Platform::DSL::Executors::Prompts.send(:list_prompts, { status: "pending" })

    assert_equal :list_prompts, result[:action]
  end

  test "list_prompts with type filter" do
    result = Platform::DSL::Executors::Prompts.send(:list_prompts, { type: "fix" })

    assert_equal :list_prompts, result[:action]
  end

  test "list_prompts with severity filter" do
    result = Platform::DSL::Executors::Prompts.send(:list_prompts, { severity: "high" })

    assert_equal :list_prompts, result[:action]
  end

  test "show_prompt raises for non-existent prompt" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Prompts.send(:show_prompt, { id: 999999 })
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "find_prompt raises without filter" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Prompts.send(:find_prompt, {})
    end

    assert_match(/Potreban filter/i, error.message)
  end

  test "reject_prompt raises without reason" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Prompts.send(:reject_prompt, { id: @prompt.id }, nil)
    end

    assert_match(/Potreban razlog/i, error.message)
  end

  test "reject_prompt updates status with reason" do
    result = Platform::DSL::Executors::Prompts.send(:reject_prompt, { id: @prompt.id }, "Test reason")

    assert_equal :reject_prompt, result[:action]
    @prompt.reload
    assert_equal "rejected", @prompt.status
  end

  test "generate_title creates appropriate title" do
    Platform::DSL::Executors::Prompts.stub(:generate_with_llm, "Generated title") do
      result = Platform::DSL::Executors::Prompts.send(:generate_title, "Fix the search bug", "fix")
      assert result.is_a?(String)
      assert result.present?
    end
  end

  test "generate_title falls back on error" do
    Platform::DSL::Executors::Prompts.stub(:generate_with_llm, -> (_) { raise "LLM error" }) do
      result = Platform::DSL::Executors::Prompts.send(:generate_title, "Fix the search bug", "fix")
      assert result.is_a?(String)
      assert result.start_with?("Fix")
    end
  end
end
