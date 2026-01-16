# frozen_string_literal: true

require "test_helper"

class Platform::DSL::IntrospectionTest < ActiveSupport::TestCase
  setup do
  end

  # ============================================
  # Code Introspection - Parser Tests
  # ============================================

  test "parses code command with read_file operation" do
    ast = Platform::DSL::Parser.parse('code { file: "app/models/location.rb" } | read_file')

    assert_equal :code_query, ast[:type]
    assert_equal "app/models/location.rb", ast[:filters][:file]
    assert_equal :read_file, ast[:operations].first[:name]
  end

  test "parses code search command" do
    ast = Platform::DSL::Parser.parse('code | search "def call"')

    assert_equal :code_query, ast[:type]
    assert_equal :search, ast[:operations].first[:name]
    assert_includes ast[:operations].first[:args], "def call"
  end

  test "parses code command without operations" do
    ast = Platform::DSL::Parser.parse("code")

    assert_equal :code_query, ast[:type]
  end

  test "parses code models command" do
    ast = Platform::DSL::Parser.parse("code | models")

    assert_equal :code_query, ast[:type]
    assert_equal :models, ast[:operations].first[:name]
  end

  test "parses code routes command" do
    ast = Platform::DSL::Parser.parse("code | routes")

    assert_equal :code_query, ast[:type]
    assert_equal :routes, ast[:operations].first[:name]
  end

  # ============================================
  # Logs Introspection - Parser Tests
  # ============================================

  test "parses logs errors command" do
    ast = Platform::DSL::Parser.parse('logs { last: "24h" } | errors')

    assert_equal :logs_query, ast[:type]
    assert_equal "24h", ast[:filters][:last]
    assert_equal :errors, ast[:operations].first[:name]
  end

  test "parses logs audit command" do
    ast = Platform::DSL::Parser.parse("logs | audit")

    assert_equal :logs_query, ast[:type]
    assert_equal :audit, ast[:operations].first[:name]
  end

  test "parses logs recent command" do
    ast = Platform::DSL::Parser.parse('logs { limit: 20 } | recent')

    assert_equal :logs_query, ast[:type]
    assert_equal 20, ast[:filters][:limit]
    assert_equal :recent, ast[:operations].first[:name]
  end

  test "parses logs dsl command" do
    ast = Platform::DSL::Parser.parse("logs | dsl")

    assert_equal :logs_query, ast[:type]
    assert_equal :dsl, ast[:operations].first[:name]
  end

  # ============================================
  # Infrastructure Introspection - Parser Tests
  # ============================================

  test "parses infrastructure queue_status command" do
    ast = Platform::DSL::Parser.parse("infrastructure | queue_status")

    assert_equal :infrastructure_query, ast[:type]
    assert_equal :queue_status, ast[:operations].first[:name]
  end

  test "parses infrastructure health command" do
    ast = Platform::DSL::Parser.parse("infrastructure | health")

    assert_equal :infrastructure_query, ast[:type]
    assert_equal :health, ast[:operations].first[:name]
  end

  test "parses infrastructure database command" do
    ast = Platform::DSL::Parser.parse("infrastructure | database")

    assert_equal :infrastructure_query, ast[:type]
    assert_equal :database, ast[:operations].first[:name]
  end

  test "parses infrastructure storage command" do
    ast = Platform::DSL::Parser.parse("infrastructure | storage")

    assert_equal :infrastructure_query, ast[:type]
    assert_equal :storage, ast[:operations].first[:name]
  end

  test "parses infrastructure without operations" do
    ast = Platform::DSL::Parser.parse("infrastructure")

    assert_equal :infrastructure_query, ast[:type]
  end

  # ============================================
  # Code Introspection - Execution Tests
  # ============================================

  test "executes code overview" do
    result = Platform::DSL.execute("code")

    assert_equal :code_overview, result[:action]
    assert result[:app].present?
    assert result[:app][:models] >= 1
    assert result[:app][:controllers] >= 1
  end

  test "executes code read_file" do
    result = Platform::DSL.execute('code { file: "Gemfile" } | read_file')

    assert_equal :read_file, result[:action]
    assert_equal "Gemfile", result[:path]
    assert result[:content].include?("source")
    assert result[:total_lines] > 0
  end

  test "executes code read_file with line range" do
    result = Platform::DSL.execute('code { file: "Gemfile", from: 1, to: 5 } | read_file')

    assert_equal :read_file, result[:action]
    assert_equal "1-5", result[:showing]
  end

  test "executes code search" do
    result = Platform::DSL.execute('code | search "class Location"')

    assert_equal :search_code, result[:action]
    assert_equal "class Location", result[:pattern]
    assert result[:matches] >= 1
    assert result[:results].any? { |r| r[:file].include?("location") }
  end

  test "code read_file rejects files outside project" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('code { file: "/etc/passwd" } | read_file')
    end

    assert_match(/izvan projekta/i, error.message)
  end

  test "code read_file rejects non-existent files" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('code { file: "nonexistent_file.rb" } | read_file')
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "executes code models" do
    result = Platform::DSL.execute("code | models")

    assert_equal :list_models, result[:action]
    assert result[:count] >= 1
    assert result[:models].any? { |m| m[:name] == "Location" }
  end

  test "executes code routes" do
    result = Platform::DSL.execute("code | routes")

    assert_equal :list_routes, result[:action]
    assert result[:count] >= 1
    assert result[:routes].is_a?(Array)
  end

  test "executes code structure" do
    result = Platform::DSL.execute('code { path: "app/models" } | structure')

    assert_equal :code_structure, result[:action]
    assert_equal "app/models", result[:path]
    assert result[:total_files] >= 1
  end

  # ============================================
  # Logs Introspection - Execution Tests
  # ============================================

  test "executes logs summary" do
    result = Platform::DSL.execute("logs")

    assert_equal :logs_summary, result[:action]
    assert result[:audit_logs].present?
    assert result[:audit_logs][:total].is_a?(Integer)
  end

  test "executes logs errors" do
    result = Platform::DSL.execute('logs { last: "24h" } | errors')

    assert_equal :show_errors, result[:action]
    assert_equal "24h", result[:time_range]
    assert result[:errors].is_a?(Array)
  end

  test "executes logs recent" do
    # Create an audit log first
    PlatformAuditLog.create!(
      action: "create",
      record_type: "Location",
      record_id: 1,
      change_data: {},
      triggered_by: "test"
    )

    result = Platform::DSL.execute("logs | recent")

    assert_equal :recent_logs, result[:action]
    assert result[:logs].is_a?(Array)
  end

  test "executes logs audit" do
    result = Platform::DSL.execute("logs | audit")

    assert_equal :audit_logs, result[:action]
    assert result[:by_action].is_a?(Hash)
  end

  test "executes logs audit with filters" do
    result = Platform::DSL.execute('logs { action: "create" } | audit')

    assert_equal :audit_logs, result[:action]
  end

  test "executes logs dsl" do
    # Create a DSL-triggered log
    PlatformAuditLog.create!(
      action: "create",
      record_type: "Location",
      record_id: 1,
      change_data: {},
      triggered_by: "platform_dsl_test"
    )

    result = Platform::DSL.execute("logs | dsl")

    assert_equal :dsl_logs, result[:action]
    assert result[:by_trigger].is_a?(Hash)
  end

  test "executes logs with time range filter" do
    result = Platform::DSL.execute('logs { last: "7d" }')

    assert_equal :logs_summary, result[:action]
    assert_equal "7d", result[:time_range]
  end

  # ============================================
  # Infrastructure Introspection - Execution Tests
  # ============================================

  test "executes infrastructure overview" do
    result = Platform::DSL.execute("infrastructure")

    assert_equal :infrastructure_overview, result[:action]
    assert_equal Rails.env, result[:environment]
    assert_equal RUBY_VERSION, result[:ruby]
  end

  test "executes infrastructure health" do
    result = Platform::DSL.execute("infrastructure | health")

    assert_equal :infrastructure_health, result[:action]
    assert result[:database].present?
    assert result[:api_keys].present?
  end

  test "executes infrastructure queue_status" do
    result = Platform::DSL.execute("infrastructure | queue_status")

    assert_equal :queue_status, result[:action]
    # May have error if SolidQueue is not set up, but should return valid result
    assert result[:jobs].present? || result[:error].present?
  end

  test "executes infrastructure database" do
    result = Platform::DSL.execute("infrastructure | database")

    assert_equal :database_status, result[:action]
    assert result[:adapter].present?
    assert result[:tables].is_a?(Integer)
  end

  test "executes infrastructure storage" do
    result = Platform::DSL.execute("infrastructure | storage")

    assert_equal :storage_status, result[:action]
    assert result[:service].present?
  end

  test "executes infrastructure cache" do
    result = Platform::DSL.execute("infrastructure | cache")

    assert_equal :cache_status, result[:action]
    assert result[:store].present?
  end

  test "executes infrastructure processes" do
    result = Platform::DSL.execute("infrastructure | processes")

    assert_equal :processes, result[:action]
    assert_equal RUBY_VERSION, result[:ruby_version]
    assert result[:pid].present?
  end

  # ============================================
  # Time Range Parsing Tests
  # ============================================

  test "parses hour time range" do
    result = Platform::DSL.execute('logs { last: "6h" }')

    assert_equal :logs_summary, result[:action]
    assert_equal "6h", result[:time_range]
  end

  test "parses day time range" do
    result = Platform::DSL.execute('logs { last: "3d" }')

    assert_equal :logs_summary, result[:action]
    assert_equal "3d", result[:time_range]
  end

  test "parses week time range" do
    result = Platform::DSL.execute('logs { last: "2w" }')

    assert_equal :logs_summary, result[:action]
    assert_equal "2w", result[:time_range]
  end
end
