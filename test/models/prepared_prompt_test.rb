# frozen_string_literal: true

require "test_helper"

class PreparedPromptModelTest < ActiveSupport::TestCase
  setup do
    @prompt = PreparedPrompt.create!(
      title: "Test Prompt",
      content: "Test content description",
      prompt_type: :fix,
      status: :pending
    )
  end

  test "validates title presence" do
    prompt = PreparedPrompt.new(content: "content", prompt_type: :fix)
    assert_not prompt.valid?
    assert prompt.errors[:title].any?
  end

  test "validates content presence" do
    prompt = PreparedPrompt.new(title: "title", prompt_type: :fix)
    assert_not prompt.valid?
    assert prompt.errors[:content].any?
  end

  test "creates valid prompt" do
    prompt = PreparedPrompt.create!(
      title: "Valid Prompt",
      content: "Valid content",
      prompt_type: :feature,
      status: :pending
    )

    assert prompt.persisted?
    assert_equal "feature", prompt.prompt_type
  end

  test "start! marks prompt as in_progress" do
    @prompt.start!

    assert_equal "in_progress", @prompt.status
  end

  test "apply! marks prompt as applied with notes" do
    @prompt.apply!(notes: "Applied successfully")

    assert_equal "applied", @prompt.status
    assert_equal "Applied successfully", @prompt.metadata["apply_notes"]
    assert @prompt.metadata["applied_at"].present?
  end

  test "reject! marks prompt as rejected with reason" do
    @prompt.reject!(reason: "Not applicable")

    assert_equal "rejected", @prompt.status
    assert_equal "Not applicable", @prompt.metadata["rejection_reason"]
    assert @prompt.metadata["rejected_at"].present?
  end

  test "to_claude_prompt includes required sections" do
    @prompt.update!(
      analysis: "Test analysis",
      solution: "Test solution",
      severity: :high,
      target_file: "app/models/test.rb"
    )

    result = @prompt.to_claude_prompt

    assert result.include?(@prompt.title)
    assert result.include?("Fix")
    assert result.include?("High")
    assert result.include?(@prompt.target_file)
    assert result.include?(@prompt.content)
    assert result.include?(@prompt.analysis)
    assert result.include?(@prompt.solution)
  end

  test "to_claude_prompt omits empty sections" do
    result = @prompt.to_claude_prompt

    assert result.include?(@prompt.title)
    assert result.include?(@prompt.content)
    # Should not have Analysis/Solution sections when empty
  end

  test "to_claude_prompt includes context when present" do
    @prompt.update!(metadata: { "context" => "Extra context info" })

    result = @prompt.to_claude_prompt

    assert result.include?("Extra context info")
  end

  test "pending scope returns pending prompts" do
    applied = PreparedPrompt.create!(
      title: "Applied",
      content: "Content",
      prompt_type: :fix,
      status: :applied
    )

    result = PreparedPrompt.pending

    assert_includes result, @prompt
    assert_not_includes result, applied
  end

  test "fixes scope returns fix type prompts" do
    feature = PreparedPrompt.create!(
      title: "Feature",
      content: "Content",
      prompt_type: :feature
    )

    result = PreparedPrompt.fixes

    assert_includes result, @prompt
    assert_not_includes result, feature
  end

  test "features scope returns feature type prompts" do
    feature = PreparedPrompt.create!(
      title: "Feature",
      content: "Content",
      prompt_type: :feature
    )

    result = PreparedPrompt.features

    assert_includes result, feature
    assert_not_includes result, @prompt
  end

  test "recent scope orders by created_at desc" do
    old = PreparedPrompt.create!(
      title: "Old",
      content: "Content",
      prompt_type: :fix,
      created_at: 1.day.ago
    )

    result = PreparedPrompt.recent

    assert_equal @prompt, result.first
  end

  test "to_short_format returns hash with required keys" do
    result = @prompt.to_short_format

    assert result.key?(:id)
    assert result.key?(:type)
    assert result.key?(:title)
    assert_equal @prompt.id, result[:id]
    assert_equal "fix", result[:type]
  end
end
