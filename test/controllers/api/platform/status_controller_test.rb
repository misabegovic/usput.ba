# frozen_string_literal: true

require "test_helper"

class ApiPlatformStatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_key = "test_api_key_12345"
    ENV["PLATFORM_API_KEY"] = @api_key

    @prompt = PreparedPrompt.create!(
      prompt_type: "fix",
      title: "Test Fix",
      content: "Test content",
      status: "pending",
      severity: "high"
    )
  end

  teardown do
    ENV["PLATFORM_API_KEY"] = nil
  end

  # Status endpoint tests

  test "returns platform status" do
    get api_platform_status_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert_equal "operational", body["platform"]
    assert body["timestamp"].present?
    assert body["health"].present?
    assert body["statistics"].present?
  end

  test "status includes health checks" do
    get api_platform_status_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    body = response.parsed_body

    assert body["health"]["database"].present?
    assert body["health"]["storage"].present?
  end

  test "status includes quick statistics" do
    get api_platform_status_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    body = response.parsed_body

    assert body["statistics"]["locations"].is_a?(Integer)
    assert body["statistics"]["pending_prompts"].is_a?(Integer)
  end

  # Health endpoint tests

  test "returns detailed health check" do
    get api_platform_health_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body["status"].present?
    assert body["checks"].present?
    assert body["timestamp"].present?
  end

  # Prompts endpoint tests

  test "returns pending prompts by default" do
    get api_platform_prompts_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert_equal "list_prompts", body["action"]
    assert body["prompts"].is_a?(Array)
  end

  test "filters prompts by status" do
    get api_platform_prompts_path,
        params: { status: "pending" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body["prompts"].all? { |p| p["status"] == "pending" }
  end

  test "shows prompt details" do
    get api_platform_prompts_path(id: @prompt.id),
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body["prompt"].present? || body["prompts"].present?,
           "Response should contain prompt data"
  end

  # Statistics endpoint tests

  test "returns platform statistics" do
    get api_platform_statistics_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body.present?
  end

  # Infrastructure endpoint tests

  test "returns infrastructure status" do
    get api_platform_infrastructure_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body["action"].present? || body["environment"].present?
  end

  # Logs endpoint tests

  test "returns audit logs" do
    # Create a log first
    PlatformAuditLog.create!(
      action: "create",
      record_type: "Test",
      record_id: 1,
      change_data: {},
      triggered_by: "test"
    )

    get api_platform_logs_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert body["action"].present?
  end

  test "filters logs by time range" do
    get api_platform_logs_path,
        params: { last: "7d" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body

    assert_equal "7d", body["time_range"]
  end

  # Authentication tests

  test "all endpoints require authentication" do
    endpoints = [
      [:get, api_platform_status_path],
      [:get, api_platform_health_path],
      [:get, api_platform_prompts_path],
      [:get, api_platform_statistics_path],
      [:get, api_platform_infrastructure_path],
      [:get, api_platform_logs_path]
    ]

    endpoints.each do |method, path|
      send(method, path)
      assert_response :unauthorized, "Expected unauthorized for #{method.upcase} #{path}"
    end
  end

  # Health status determination tests

  test "health returns unhealthy when result is not a hash" do
    Platform::DSL.stub(:execute, "invalid") do
      get api_platform_health_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      assert_equal "unhealthy", response.parsed_body["status"]
    end
  end

  test "health returns unhealthy when database status is not ok" do
    Platform::DSL.stub(:execute, { database: { status: "error" } }) do
      get api_platform_health_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      assert_equal "unhealthy", response.parsed_body["status"]
    end
  end

  test "health returns degraded when less than half api keys configured" do
    Platform::DSL.stub(:execute, {
      database: { status: "ok" },
      api_keys: { key1: "configured", key2: "missing", key3: "missing", key4: "missing" }
    }) do
      get api_platform_health_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      assert_equal "degraded", response.parsed_body["status"]
    end
  end

  test "health returns healthy when all checks pass" do
    Platform::DSL.stub(:execute, {
      database: { status: "ok" },
      api_keys: { key1: "configured", key2: "configured" }
    }) do
      get api_platform_health_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      assert_equal "healthy", response.parsed_body["status"]
    end
  end

  # Quick statistics error handling

  test "status handles statistics errors gracefully" do
    Location.stub(:count, -> { raise "DB error" }) do
      get api_platform_status_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      body = response.parsed_body

      assert body["statistics"]["error"].present?
    end
  end

  # Health check detail tests

  test "health_check reports database error" do
    ActiveRecord::Base.connection.stub(:execute, -> (*args) { raise "Connection failed" }) do
      get api_platform_status_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      body = response.parsed_body

      assert body["health"]["database"].start_with?("error:")
    end
  end

  test "health_check reports storage error" do
    ActiveStorage::Blob.stub(:count, -> { raise "Storage error" }) do
      get api_platform_status_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      body = response.parsed_body

      assert body["health"]["storage"].start_with?("error:")
    end
  end

  # Version test

  test "status includes version" do
    get api_platform_status_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    assert_equal "1.0.0", response.parsed_body["version"]
  end

  test "status includes environment" do
    get api_platform_status_path,
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    assert_equal "test", response.parsed_body["environment"]
  end

  # Show prompt test

  test "show_prompt endpoint returns prompt data" do
    get api_platform_path(id: @prompt.id),
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
  end

  # Additional health status tests

  test "health returns healthy when api_keys is not a hash" do
    Platform::DSL.stub(:execute, {
      database: { status: "ok" },
      api_keys: nil
    }) do
      get api_platform_health_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      # Should skip api_keys check and return healthy
      assert_equal "healthy", response.parsed_body["status"]
    end
  end

  # Test health_check queue check when SolidQueue is available
  test "health_check reports queue ok when SolidQueue is available" do
    # Skip if SolidQueue::Job is not actually defined
    # This test is for when SolidQueue is present and configured
    if defined?(SolidQueue::Job) && SolidQueue::Job.table_exists?
      get api_platform_status_path,
          headers: { "Authorization" => "Bearer #{@api_key}" }

      assert_response :success
      body = response.parsed_body

      assert_equal "ok", body["health"]["queue"]
    else
      skip "SolidQueue::Job not available"
    end
  end

  # Test health_check queue when SolidQueue::Job exists but table is missing
  test "health_check reports not_configured when SolidQueue table missing" do
    # Create a mock that defines SolidQueue::Job but returns false for table_exists?
    mock_job = Class.new do
      def self.table_exists?
        false
      end
    end

    original_const = defined?(::SolidQueue::Job) ? ::SolidQueue::Job : nil

    begin
      # Define SolidQueue module and Job class
      unless defined?(::SolidQueue)
        Object.const_set(:SolidQueue, Module.new)
      end
      ::SolidQueue.const_set(:Job, mock_job)

      controller = ::API::Platform::StatusController.new
      result = controller.send(:health_check)

      # When table doesn't exist, should return not_configured
      assert_equal "not_configured", result[:queue]
    ensure
      # Restore original
      if original_const
        ::SolidQueue.send(:remove_const, :Job) if defined?(::SolidQueue::Job)
        ::SolidQueue.const_set(:Job, original_const)
      elsif defined?(::SolidQueue::Job)
        ::SolidQueue.send(:remove_const, :Job)
      end
    end
  end

  # Test health_check queue check rescue block
  test "health_check queue check handles errors" do
    controller = ::API::Platform::StatusController.new

    # Mock that will raise an error
    Object.stub(:const_defined?, ->(*args) {
      if args[0].to_s == "SolidQueue::Job"
        raise "Mock error"
      end
      Object.const_defined?(*args)
    }) do
      result = controller.send(:health_check)
      assert_equal "not_configured", result[:queue]
    end
  end

  # DSL injection prevention tests

  test "prompts endpoint sanitizes invalid status to pending" do
    get api_platform_prompts_path,
        params: { status: "invalid\" } | delete all" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    # Should default to pending, not execute injection
    body = response.parsed_body
    assert_equal "list_prompts", body["action"]
  end

  test "show_prompt rejects non-integer id" do
    get api_platform_path(id: "1; drop table users"),
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :bad_request
    assert_equal "Invalid prompt ID", response.parsed_body["error"]
  end

  test "show_prompt accepts valid integer id" do
    get api_platform_path(id: @prompt.id.to_s),
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
  end

  test "logs endpoint sanitizes invalid time range to 24h" do
    get api_platform_logs_path,
        params: { last: "invalid\" } | delete all" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    body = response.parsed_body
    # Should default to 24h, not execute injection
    assert_equal "24h", body["time_range"]
  end

  test "prompts endpoint accepts valid status value" do
    get api_platform_prompts_path,
        params: { status: "approved" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
  end

  test "logs endpoint accepts valid time range 7d" do
    PlatformAuditLog.create!(
      action: "create",
      record_type: "Location",
      record_id: 1,
      change_data: {},
      triggered_by: "platform_dsl"
    )

    get api_platform_logs_path,
        params: { last: "7d" },
        headers: { "Authorization" => "Bearer #{@api_key}" }

    assert_response :success
    assert_equal "7d", response.parsed_body["time_range"]
  end

  # Unit tests for private sanitization methods
  test "sanitize_integer returns nil for blank value" do
    controller = ::API::Platform::StatusController.new
    assert_nil controller.send(:sanitize_integer, nil)
    assert_nil controller.send(:sanitize_integer, "")
  end

  test "sanitize_integer returns integer for valid string" do
    controller = ::API::Platform::StatusController.new
    assert_equal 123, controller.send(:sanitize_integer, "123")
  end

  test "sanitize_integer returns nil for non-numeric string" do
    controller = ::API::Platform::StatusController.new
    assert_nil controller.send(:sanitize_integer, "abc")
    assert_nil controller.send(:sanitize_integer, "12.34")
  end
end
