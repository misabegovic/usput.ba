# frozen_string_literal: true

require "test_helper"

class Platform::DSL::SelfImprovementTest < ActiveSupport::TestCase
  setup do
    @prompt = PreparedPrompt.create!(
      prompt_type: "fix",
      title: "Fix N+1 query in LocationsController",
      content: "N+1 query detected in LocationsController#index",
      status: "pending",
      severity: "high",
      target_file: "app/controllers/locations_controller.rb"
    )

    @feature_prompt = PreparedPrompt.create!(
      prompt_type: "feature",
      title: "Add rating to locations",
      content: "Allow users to rate locations with 1-5 stars",
      status: "pending",
      severity: "medium"
    )

    @applied_prompt = PreparedPrompt.create!(
      prompt_type: "improvement",
      title: "Refactor authentication",
      content: "Simplify authentication flow",
      status: "applied"
    )
  end

  # ============================================
  # Parser Tests - Prompts queries
  # ============================================

  test "parses prompts list command" do
    ast = Platform::DSL::Parser.parse('prompts { status: "pending" } | list')

    assert_equal :prompts_query, ast[:type]
    assert_equal "pending", ast[:filters][:status]
    assert_equal :list, ast[:operations].first[:name]
  end

  test "parses prompts show command" do
    ast = Platform::DSL::Parser.parse("prompts { id: 123 } | show")

    assert_equal :prompts_query, ast[:type]
    assert_equal 123, ast[:filters][:id]
    assert_equal :show, ast[:operations].first[:name]
  end

  test "parses prompts count command" do
    ast = Platform::DSL::Parser.parse("prompts | count")

    assert_equal :prompts_query, ast[:type]
    assert_equal :count, ast[:operations].first[:name]
  end

  test "parses prompts without operations" do
    ast = Platform::DSL::Parser.parse("prompts")

    assert_equal :prompts_query, ast[:type]
  end

  # ============================================
  # Parser Tests - Improvement commands
  # ============================================

  test "parses prepare fix command" do
    ast = Platform::DSL::Parser.parse('prepare fix for "N+1 query in LocationsController"')

    assert_equal :improvement, ast[:type]
    assert_equal :fix, ast[:improvement_type]
    assert_equal "N+1 query in LocationsController", ast[:description]
  end

  test "parses prepare fix with severity" do
    ast = Platform::DSL::Parser.parse('prepare fix for "N+1 query" severity "high"')

    assert_equal :improvement, ast[:type]
    assert_equal :fix, ast[:improvement_type]
    assert_equal "high", ast[:severity]
  end

  test "parses prepare fix with file" do
    ast = Platform::DSL::Parser.parse('prepare fix for "N+1 query" file "app/controllers/locations_controller.rb"')

    assert_equal :improvement, ast[:type]
    assert_equal "app/controllers/locations_controller.rb", ast[:target_file]
  end

  test "parses prepare fix with severity and file" do
    ast = Platform::DSL::Parser.parse('prepare fix for "N+1 query" severity "high" file "app/controllers/locations_controller.rb"')

    assert_equal :improvement, ast[:type]
    assert_equal :fix, ast[:improvement_type]
    assert_equal "high", ast[:severity]
    assert_equal "app/controllers/locations_controller.rb", ast[:target_file]
  end

  test "parses prepare feature command" do
    ast = Platform::DSL::Parser.parse('prepare feature "Add rating to locations"')

    assert_equal :improvement, ast[:type]
    assert_equal :feature, ast[:improvement_type]
    assert_equal "Add rating to locations", ast[:description]
  end

  test "parses prepare improvement command" do
    ast = Platform::DSL::Parser.parse('prepare improvement "Refactor authentication"')

    assert_equal :improvement, ast[:type]
    assert_equal :improvement, ast[:improvement_type]
    assert_equal "Refactor authentication", ast[:description]
  end

  # ============================================
  # Parser Tests - Prompt actions
  # ============================================

  test "parses apply prompt command" do
    ast = Platform::DSL::Parser.parse("apply prompt { id: 123 }")

    assert_equal :prompt_action, ast[:type]
    assert_equal :apply, ast[:action]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses reject prompt command" do
    ast = Platform::DSL::Parser.parse('reject prompt { id: 123 } reason "not needed"')

    assert_equal :prompt_action, ast[:type]
    assert_equal :reject, ast[:action]
    assert_equal 123, ast[:filters][:id]
    assert_equal "not needed", ast[:reason]
  end

  # ============================================
  # Execution Tests - Prompts queries
  # ============================================

  test "lists all prompts" do
    result = Platform::DSL.execute("prompts")

    assert_equal :list_prompts, result[:action]
    assert result[:count] >= 2
  end

  test "lists pending prompts" do
    result = Platform::DSL.execute('prompts { status: "pending" } | list')

    assert_equal :list_prompts, result[:action]
    assert result[:prompts].all? { |p| p[:status] == "pending" }
  end

  test "lists prompts by type" do
    result = Platform::DSL.execute('prompts { type: "fix" } | list')

    assert_equal :list_prompts, result[:action]
    assert result[:prompts].all? { |p| p[:type] == "fix" }
  end

  test "shows prompt details" do
    result = Platform::DSL.execute("prompts { id: #{@prompt.id} } | show")

    assert_equal :show_prompt, result[:action]
    assert_equal @prompt.id, result[:prompt][:id]
    assert_equal "fix", result[:prompt][:type]
    assert result[:prompt][:claude_prompt].present?
  end

  test "counts prompts" do
    result = Platform::DSL.execute("prompts | count")

    assert result[:total] >= 3
    assert result[:pending] >= 2
    assert_kind_of Hash, result[:by_type]
  end

  test "exports prompt" do
    result = Platform::DSL.execute("prompts { id: #{@prompt.id} } | export")

    assert_equal :export_prompt, result[:action]
    assert_equal @prompt.id, result[:prompt_id]
    assert result[:claude_prompt].present?
    assert result[:claude_prompt].include?("N+1")
  end

  test "rejects non-existent prompt" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("prompts { id: 999999 } | show")
    end

    assert_match(/nije pronađen/i, error.message)
  end

  # ============================================
  # Execution Tests - Improvement commands
  # ============================================

  test "prepares fix prompt" do
    result = Platform::DSL.execute('prepare fix for "Memory leak in BackgroundJob"')

    assert result[:success]
    assert_equal :prepare_prompt, result[:action]
    assert_equal "fix", result[:type]
    assert result[:prompt_id].present?

    prompt = PreparedPrompt.find(result[:prompt_id])
    assert_equal "fix", prompt.prompt_type
    assert_equal "pending", prompt.status
    assert prompt.content.include?("Memory leak")
  end

  test "prepares fix with severity" do
    result = Platform::DSL.execute('prepare fix for "Security vulnerability" severity "critical"')

    assert result[:success]
    assert_equal "critical", result[:severity]

    prompt = PreparedPrompt.find(result[:prompt_id])
    assert_equal "critical", prompt.severity
  end

  test "prepares fix with target file" do
    result = Platform::DSL.execute('prepare fix for "Bug in user model" file "app/models/user.rb"')

    assert result[:success]

    prompt = PreparedPrompt.find(result[:prompt_id])
    assert_equal "app/models/user.rb", prompt.target_file
  end

  test "prepares feature prompt" do
    result = Platform::DSL.execute('prepare feature "Add dark mode support"')

    assert result[:success]
    assert_equal "feature", result[:type]

    prompt = PreparedPrompt.find(result[:prompt_id])
    assert_equal "feature", prompt.prompt_type
  end

  test "prepares improvement prompt" do
    result = Platform::DSL.execute('prepare improvement "Simplify controller logic"')

    assert result[:success]
    assert_equal "improvement", result[:type]

    prompt = PreparedPrompt.find(result[:prompt_id])
    assert_equal "improvement", prompt.prompt_type
  end

  test "creates audit log for prepared prompt" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute('prepare fix for "Test issue"')
    end

    log = PlatformAuditLog.last
    assert_equal "create", log.action
    assert_equal "PreparedPrompt", log.record_type
    assert_equal "platform_dsl_improvement", log.triggered_by
  end

  # ============================================
  # Execution Tests - Prompt actions
  # ============================================

  test "applies prompt" do
    result = Platform::DSL.execute("apply prompt { id: #{@prompt.id} }")

    assert result[:success]
    assert_equal :apply_prompt, result[:action]

    @prompt.reload
    assert_equal "applied", @prompt.status
  end

  test "rejects prompt with reason" do
    result = Platform::DSL.execute("reject prompt { id: #{@feature_prompt.id} } reason \"not a priority\"")

    assert result[:success]
    assert_equal :reject_prompt, result[:action]
    assert_equal "not a priority", result[:reason]

    @feature_prompt.reload
    assert_equal "rejected", @feature_prompt.status
    assert_equal "not a priority", @feature_prompt.metadata["rejection_reason"]
  end

  test "rejects applying already applied prompt" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("apply prompt { id: #{@applied_prompt.id} }")
    end

    assert_match(/nije u pending/i, error.message)
  end

  test "rejects rejecting without reason" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("reject prompt { id: #{@prompt.id} } reason \"\"")
    end

    assert_match(/razlog/i, error.message)
  end

  test "creates audit log for applied prompt" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("apply prompt { id: #{@prompt.id} }")
    end

    log = PlatformAuditLog.last
    assert_equal "update", log.action
    assert_equal "PreparedPrompt", log.record_type
  end

  test "creates audit log for rejected prompt" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("reject prompt { id: #{@feature_prompt.id} } reason \"test\"")
    end

    log = PlatformAuditLog.last
    assert_equal "update", log.action
    assert_equal "rejected", log.change_data["status"]
  end
end

# PreparedPrompt model tests
class PreparedPromptTest < ActiveSupport::TestCase
  setup do
    @prompt = PreparedPrompt.create!(
      prompt_type: "fix",
      title: "Test Fix",
      content: "Test content",
      status: "pending",
      severity: "high"
    )
  end

  test "validates presence of required fields" do
    prompt = PreparedPrompt.new
    refute prompt.valid?

    assert prompt.errors[:prompt_type].present?
    assert prompt.errors[:title].present?
    assert prompt.errors[:content].present?
  end

  test "generates claude prompt" do
    claude_prompt = @prompt.to_claude_prompt

    assert claude_prompt.include?("Test Fix")
    assert claude_prompt.include?("Fix")
    assert claude_prompt.include?("High")
    assert claude_prompt.include?("Test content")
  end

  test "to_short_format returns correct fields" do
    format = @prompt.to_short_format

    assert_equal @prompt.id, format[:id]
    assert_equal "fix", format[:type]
    assert_equal "high", format[:severity]
    assert_equal "pending", format[:status]
  end

  test "to_full_format includes claude_prompt" do
    format = @prompt.to_full_format

    assert format[:claude_prompt].present?
    assert format[:content].present?
  end

  test "apply! changes status to applied" do
    @prompt.apply!

    assert_equal "applied", @prompt.status
    assert @prompt.metadata["applied_at"].present?
  end

  test "reject! changes status to rejected" do
    @prompt.reject!(reason: "Test reason")

    assert_equal "rejected", @prompt.status
    assert_equal "Test reason", @prompt.metadata["rejection_reason"]
  end

  test "scopes work correctly" do
    pending_count = PreparedPrompt.pending.count
    assert pending_count >= 1

    fixes_count = PreparedPrompt.fixes.count
    assert fixes_count >= 1
  end

  test "by_severity orders correctly" do
    PreparedPrompt.create!(prompt_type: "fix", title: "Low", content: "c", severity: "low")
    PreparedPrompt.create!(prompt_type: "fix", title: "Critical", content: "c", severity: "critical")

    prompts = PreparedPrompt.by_severity.to_a

    critical_idx = prompts.index { |p| p.severity == "critical" }
    low_idx = prompts.index { |p| p.severity == "low" }

    assert critical_idx < low_idx if critical_idx && low_idx
  end
end
