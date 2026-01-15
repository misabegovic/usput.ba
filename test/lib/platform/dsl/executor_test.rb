# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ExecutorTest < ActiveSupport::TestCase
  setup do
    # Create test locations - will be rolled back automatically by Rails test transactions
    @sarajevo_location = Location.create!(
      name: "Test Location Sarajevo",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
    @mostar_location = Location.create!(
      name: "Test Location Mostar",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    )
    # Create a test user for content changes
    @test_user = User.create!(
      username: "test_user_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # No teardown needed - Rails transactions handle cleanup

  # Schema queries
  test "executes schema stats" do
    result = Platform::DSL.execute("schema | stats")

    assert_kind_of Hash, result
    assert result[:content].key?(:locations)
    assert result[:content].key?(:experiences)
    assert result.key?(:by_city)
    assert result.key?(:coverage)
    assert result.key?(:users)
  end

  test "executes schema describe" do
    result = Platform::DSL.execute("schema | describe locations")

    assert_equal "locations", result[:table].to_s
    assert_includes result[:columns], "name"
    assert_includes result[:columns], "city"
    assert result[:count] >= 2
  end

  test "executes schema health" do
    result = Platform::DSL.execute("schema | health")

    assert_kind_of Hash, result
    assert result.key?(:database)
    assert result.key?(:api_keys)
  end

  # Table queries
  test "executes count query" do
    result = Platform::DSL.execute("locations | count")

    assert_kind_of Integer, result
    assert result >= 2
  end

  test "executes count with filter" do
    result = Platform::DSL.execute('locations { city: "Sarajevo" } | count')

    assert_kind_of Integer, result
    assert result >= 1
  end

  test "executes sample query" do
    result = Platform::DSL.execute("locations | sample 2")

    assert_kind_of Array, result
    assert result.length <= 2
    assert result.first.key?(:id)
    assert result.first.key?(:name)
    assert result.first.key?(:city)
  end

  test "executes limit query" do
    result = Platform::DSL.execute("locations | limit 1")

    assert_kind_of Array, result
    assert_equal 1, result.length
  end

  test "executes aggregate count by city" do
    result = Platform::DSL.execute("locations | aggregate count() by city")

    assert_kind_of Hash, result
    assert result.key?("Sarajevo") || result.key?("Mostar")
  end

  # Filter variations
  test "filters by exact city match" do
    result = Platform::DSL.execute('locations { city: "Mostar" } | count')

    assert_kind_of Integer, result
    assert result >= 1
  end

  # Error handling
  test "raises ExecutionError for unknown table" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("unknown_table | count")
    end
  end

  test "raises ParseError for invalid DSL" do
    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL.execute("invalid $$$ query")
    end
  end

  # Additional filter tests
  test "filters by has_audio true" do
    result = Platform::DSL.execute("locations { has_audio: true } | count")

    assert_kind_of Integer, result
  end

  test "filters by has_audio false" do
    result = Platform::DSL.execute("locations { has_audio: false } | count")

    assert_kind_of Integer, result
  end

  test "filters by missing_description true" do
    result = Platform::DSL.execute("locations { missing_description: true } | count")

    assert_kind_of Integer, result
  end

  test "filters by missing_description false" do
    result = Platform::DSL.execute("locations { missing_description: false } | count")

    assert_kind_of Integer, result
  end

  test "filters by ai_generated true" do
    result = Platform::DSL.execute("locations { ai_generated: true } | count")

    assert_kind_of Integer, result
  end

  test "filters by ai_generated false" do
    result = Platform::DSL.execute("locations { ai_generated: false } | count")

    assert_kind_of Integer, result
  end

  # Operation tests
  test "executes order by name asc" do
    result = Platform::DSL.execute("locations | order name asc | limit 5")

    assert_kind_of Array, result
  end

  test "executes sort by id" do
    result = Platform::DSL.execute("locations | sort id | limit 2")

    assert_kind_of Array, result
  end

  test "executes show operation" do
    result = Platform::DSL.execute("locations | show")

    assert_kind_of Array, result
    assert result.first.key?(:id)
  end

  test "raises error for unknown operation" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :unknown_op })
    end
  end

  # Aggregate tests
  test "aggregate sum" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Review.all, {
      args: ["sum", :rating],
      group_by: nil
    })

    # Sum may be nil or number
    assert result.nil? || result.is_a?(Numeric)
  end

  test "aggregate avg" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Review.all, {
      args: ["avg", :rating],
      group_by: nil
    })

    assert result.nil? || result.is_a?(Numeric)
  end

  test "aggregate avg with group_by" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, {
      args: ["count"],
      group_by: :city
    })

    assert_kind_of Hash, result
  end

  test "raises error for unknown aggregate function" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_aggregate, Location.all, {
        args: ["unknown_func"],
        group_by: nil
      })
    end
  end

  # Format record tests
  test "format_record for Location" do
    result = Platform::DSL::Executor.send(:format_record, @sarajevo_location)

    assert_equal @sarajevo_location.id, result[:id]
    assert_equal @sarajevo_location.name, result[:name]
    assert_equal @sarajevo_location.city, result[:city]
  end

  test "format_record for Experience" do
    experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 60
    )

    result = Platform::DSL::Executor.send(:format_record, experience)

    assert_equal experience.id, result[:id]
    assert_equal "Test Experience", result[:title]
  end

  test "format_record for Plan" do
    plan = Plan.create!(title: "Test Plan")

    result = Platform::DSL::Executor.send(:format_record, plan)

    assert_equal plan.id, result[:id]
    assert_equal "Test Plan", result[:title]
  end

  test "format_record for User" do
    user = User.create!(username: "testuser_#{SecureRandom.hex(4)}", password: "password123")

    result = Platform::DSL::Executor.send(:format_record, user)

    assert_equal user.id, result[:id]
    assert_equal user.username, result[:username]
  end

  test "format_record for unknown model" do
    # Use a simple object with attributes method
    record = Object.new
    record.define_singleton_method(:attributes) { { "id" => 1, "name" => "Test", "other" => "value" } }

    result = Platform::DSL::Executor.send(:format_record, record)

    assert_equal 1, result["id"]
    assert_equal "Test", result["name"]
  end

  # Check methods tests
  test "check_api_keys returns status for each key" do
    result = Platform::DSL::Executor.send(:check_api_keys)

    assert result.key?(:anthropic)
    assert result.key?(:geoapify)
    assert result.key?(:elevenlabs)
  end

  test "check_database_health returns ok" do
    result = Platform::DSL::Executor.send(:check_database_health)

    assert_equal "ok", result[:status]
  end

  test "check_storage_health returns service name" do
    result = Platform::DSL::Executor.send(:check_storage_health)

    assert result.key?(:service) || result.key?(:status)
  end

  # Cached stats tests
  test "build_stats returns directly when no cache" do
    PlatformStatistic.where(key: "layer_zero").delete_all

    result = Platform::DSL::Executor.send(:build_stats)

    assert_equal :live, result[:source]
  end

  test "format_cached_stats formats data correctly" do
    data = {
      "stats" => { "locations" => 100, "users" => 50, "curators" => 5 },
      "by_city" => { "Sarajevo" => 30 },
      "coverage" => { "cities" => 10 },
      "computed_at" => "2024-01-01T00:00:00Z"
    }

    result = Platform::DSL::Executor.send(:format_cached_stats, data)

    assert_equal :cached, result[:source]
    assert_equal 100, result[:content]["locations"]
    assert_equal 50, result[:users][:total]
  end

  test "format_cached_stats handles symbol keys" do
    data = {
      stats: { locations: 100, users: 50, curators: 5 },
      by_city: { "Sarajevo" => 30 },
      coverage: { cities: 10 },
      computed_at: "2024-01-01T00:00:00Z"
    }

    result = Platform::DSL::Executor.send(:format_cached_stats, data)

    assert_equal :cached, result[:source]
  end

  # Apply filter edge cases
  test "apply_filter with array value" do
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :city, ["Sarajevo", "Mostar"])

    assert scope.to_sql.include?("IN")
  end

  test "apply_filter raises for unknown column" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_filter, Location.all, :nonexistent_column, "value")
    end
  end

  # Table queries
  test "executes users query" do
    result = Platform::DSL.execute("users | count")

    assert_kind_of Integer, result
  end

  test "executes reviews query" do
    result = Platform::DSL.execute("reviews | count")

    assert_kind_of Integer, result
  end

  # Where condition tests
  test "apply_where_condition with greater than" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id > 0")

    assert scope.to_sql.include?(">")
  end

  test "apply_where_condition with less than" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id < 999999")

    assert scope.to_sql.include?("<")
  end

  test "apply_where_condition with equal" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id = 1")

    # Just verify it doesn't raise
    assert scope.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with invalid condition returns scope" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "invalid condition")

    assert_equal Location.all.to_sql, scope.to_sql
  end

  # Apply operations with nil
  test "apply_operations with nil returns limited records" do
    result = Platform::DSL::Executor.send(:apply_operations, Location.all, nil)

    assert result.length <= 100
  end

  test "apply_operations with empty array returns limited records" do
    result = Platform::DSL::Executor.send(:apply_operations, Location.all, [])

    assert result.length <= 100
  end

  # Additional coverage tests

  test "check_api_keys returns missing when ENV not set" do
    original_anthropic = ENV["ANTHROPIC_API_KEY"]
    original_geoapify = ENV["GEOAPIFY_API_KEY"]
    original_elevenlabs = ENV["ELEVENLABS_API_KEY"]

    ENV["ANTHROPIC_API_KEY"] = nil
    ENV["GEOAPIFY_API_KEY"] = nil
    ENV["ELEVENLABS_API_KEY"] = nil

    result = Platform::DSL::Executor.send(:check_api_keys)

    assert_equal "missing", result[:anthropic]
    assert_equal "missing", result[:geoapify]
    assert_equal "missing", result[:elevenlabs]
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_anthropic
    ENV["GEOAPIFY_API_KEY"] = original_geoapify
    ENV["ELEVENLABS_API_KEY"] = original_elevenlabs
  end

  test "check_api_keys returns configured when ENV set" do
    original_anthropic = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"

    result = Platform::DSL::Executor.send(:check_api_keys)

    assert_equal "configured", result[:anthropic]
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_anthropic
  end

  test "check_storage_health handles errors" do
    ActiveStorage::Blob.stub(:service, ->{ raise "Storage error" }) do
      result = Platform::DSL::Executor.send(:check_storage_health)

      assert_equal "error", result[:status]
    end
  end

  test "check_database_health handles errors" do
    ActiveRecord::Base.connection.stub(:execute, ->(_) { raise "DB error" }) do
      result = Platform::DSL::Executor.send(:check_database_health)

      assert_equal "error", result[:status]
    end
  end

  test "check_queue_health handles errors" do
    SolidQueue::Job.stub(:where, ->(_) { raise "Queue error" }) do
      result = Platform::DSL::Executor.send(:check_queue_health)

      assert_equal "error", result[:status]
    end
  end

  test "resolve_model raises for unknown table" do
    # Test with a table that's not in the mapping
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:resolve_model, "unknown_nonexistent_table")
    end
  end

  test "build_stats uses cached data when available" do
    # Create a fresh cached stat
    PlatformStatistic.find_or_create_by!(key: "layer_zero").update!(
      value: {
        "stats" => { "locations" => 999 },
        "by_city" => {},
        "coverage" => {},
        "computed_at" => Time.current.iso8601
      },
      computed_at: 1.minute.ago
    )

    result = Platform::DSL::Executor.send(:build_stats)

    assert_equal :cached, result[:source]
  end

  # Apply operation edge cases - test with valid operations only
  test "apply_operation with order operation" do
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :order, args: [:name, :asc] })

    # Should return an ActiveRecord relation
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_operation with show returns array" do
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :show })

    assert result.is_a?(Array)
  end

  # Where condition edge cases
  test "apply_where_condition with not equal" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id != 999999")

    assert scope.to_sql.include?("!=") || scope.to_sql.include?("<>")
  end

  test "apply_where_condition with greater than or equal" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id >= 1")

    assert scope.to_sql.include?(">=")
  end

  test "apply_where_condition with less than or equal" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id <= 999999")

    assert scope.to_sql.include?("<=")
  end

  test "apply_where_condition with decimal value" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "lat > 43.5")

    assert scope.to_sql.include?(">")
  end

  # Infrastructure query
  test "execute_infrastructure_query" do
    result = Platform::DSL.execute("infrastructure | health")

    assert result.is_a?(Hash)
    assert result.key?(:database) || result.key?(:status)
  end

  # Format record edge cases
  test "format_record for Review falls back to attributes" do
    user = User.create!(username: "review_test_#{SecureRandom.hex(4)}", password: "password123")
    review = Review.create!(
      reviewable: @sarajevo_location,
      user: user,
      rating: 5
    )

    result = Platform::DSL::Executor.send(:format_record, review)

    # Falls back to attributes.slice which returns string keys
    assert_equal review.id, result["id"]
    assert result.is_a?(Hash)
  end

  test "format_record for AudioTour falls back to attributes" do
    audio_tour = AudioTour.create!(
      location: @sarajevo_location,
      locale: "bs",
      script: "Test script"
    )

    result = Platform::DSL::Executor.send(:format_record, audio_tour)

    # Falls back to attributes.slice which returns string keys
    assert_equal audio_tour.id, result["id"]
    assert result.is_a?(Hash)
  end

  # Execute type routing
  test "execute routes proposals_query correctly" do
    result = Platform::DSL.execute("proposals | count")

    assert result.is_a?(Hash) || result.is_a?(Integer)
  end

  test "execute routes curators_query correctly" do
    result = Platform::DSL.execute("curators | count")

    assert result.is_a?(Hash) || result.is_a?(Integer)
  end

  test "execute routes logs_query correctly" do
    result = Platform::DSL.execute("logs | list")

    assert result.is_a?(Hash) || result.is_a?(Array)
  end

  # Proposals query tests
  test "execute_proposals_query with list operation" do
    result = Platform::DSL.execute("proposals | list")

    assert result.is_a?(Hash)
    assert result[:action] == :list_proposals
  end

  test "execute_proposals_query with show operation" do
    content_change = ContentChange.create!(
      changeable_type: "Location",
      changeable_id: @sarajevo_location.id,
      change_type: :update_content,
      proposed_data: { name: "New Name" },
      user: @test_user
    )

    result = Platform::DSL.execute("proposals { id: #{content_change.id} } | show")

    assert result.is_a?(Hash)
  end

  test "execute_proposals_query with status filter" do
    result = Platform::DSL.execute('proposals { status: "pending" } | count')

    assert result.is_a?(Hash) || result.is_a?(Integer)
  end

  # Applications query tests
  test "execute_applications_query with list" do
    result = Platform::DSL.execute("applications | list")

    assert result.is_a?(Hash)
    assert result[:action] == :list_applications
  end

  # Curators query tests
  test "execute_curators_query with list" do
    result = Platform::DSL.execute("curators | list")

    assert result.is_a?(Hash)
    assert result[:action] == :list_curators
  end

  test "execute_curators_query with stats" do
    result = Platform::DSL.execute("curators | stats")

    assert result.is_a?(Hash)
  end

  # Curator management tests
  test "execute_curator_management block command" do
    curator = User.create!(
      username: "curator_mgmt_test_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123",
      user_type: :curator
    )

    result = Platform::DSL.execute("block curator { id: #{curator.id} } reason \"Test block\"")

    assert result.is_a?(Hash)
    assert_equal :block_curator, result[:action]

    curator.reload
    assert curator.spam_blocked?
  end

  test "execute_curator_management unblock command" do
    curator = User.create!(
      username: "curator_unblock_test_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123",
      user_type: :curator,
      spam_blocked_at: 1.hour.ago,
      spam_blocked_until: 1.day.from_now
    )

    result = Platform::DSL.execute("unblock curator { id: #{curator.id} }")

    assert result.is_a?(Hash)
    assert_equal :unblock_curator, result[:action]

    curator.reload
    refute curator.spam_blocked?
  end

  # Code query tests
  test "execute_code_query with list" do
    result = Platform::DSL.execute("code | list")

    assert result.is_a?(Hash)
  end

  # Prompts query tests
  test "execute_prompts_query with show" do
    prompt = PreparedPrompt.create!(
      title: "Test Prompt",
      content: "Test content",
      prompt_type: :fix
    )

    result = Platform::DSL.execute("prompts { id: #{prompt.id} } | show")

    assert result.is_a?(Hash)
    assert_equal :show_prompt, result[:action]
  end

  # Improvement tests
  test "execute_improvement with prepare fix" do
    result = Platform::DSL.execute('prepare fix for "Test fix description"')

    assert result.is_a?(Hash)
    assert_equal :prepare_prompt, result[:action]
    assert_equal "fix", result[:type]
  end

  test "execute_improvement with prepare feature" do
    result = Platform::DSL.execute('prepare feature "Test feature description"')

    assert result.is_a?(Hash)
    assert_equal :prepare_prompt, result[:action]
    assert_equal "feature", result[:type]
  end

  # Prompt action tests (note: only apply and reject are supported)
  test "execute_prompt_action with apply" do
    prompt = PreparedPrompt.create!(
      title: "Apply Test",
      content: "Test content",
      prompt_type: :fix,
      status: :in_progress
    )

    result = Platform::DSL.execute("apply prompt { id: #{prompt.id} }")

    assert result.is_a?(Hash)
    assert_equal :apply_prompt, result[:action]
  end

  test "execute_prompt_action with reject" do
    prompt = PreparedPrompt.create!(
      title: "Reject Test",
      content: "Test content",
      prompt_type: :fix,
      status: :pending
    )

    result = Platform::DSL.execute("reject prompt { id: #{prompt.id} } reason \"Not needed\"")

    assert result.is_a?(Hash)
    assert_equal :reject_prompt, result[:action]
  end

  # Approval tests
  test "execute_approval approve proposal" do
    content_change = ContentChange.create!(
      changeable_type: "Location",
      changeable_id: @sarajevo_location.id,
      change_type: :update_content,
      proposed_data: { name: "New Name" },
      status: :pending,
      user: @test_user
    )

    result = Platform::DSL.execute("approve proposal { id: #{content_change.id} }")

    assert result.is_a?(Hash)
    assert_equal :approve_proposal, result[:action]
  end

  test "execute_approval reject proposal" do
    content_change = ContentChange.create!(
      changeable_type: "Location",
      changeable_id: @sarajevo_location.id,
      change_type: :update_content,
      proposed_data: { name: "New Name" },
      status: :pending,
      user: @test_user
    )

    result = Platform::DSL.execute("reject proposal { id: #{content_change.id} } reason \"Invalid\"")

    assert result.is_a?(Hash)
    assert_equal :reject_proposal, result[:action]
  end

  # Geoapify service test
  test "geoapify_service returns service instance" do
    # This test just verifies the method exists and returns something
    # The actual service may fail without API key
    if ENV["GEOAPIFY_API_KEY"].present?
      service = Platform::DSL::Executor.send(:geoapify_service)
      assert service.is_a?(GeoapifyService)
    end
  end

  # Get city coordinates tests
  test "get_city_coordinates returns coords from existing location" do
    result = Platform::DSL::Executor.send(:get_city_coordinates, "Sarajevo")

    assert result.is_a?(Hash)
    assert result.key?(:lat)
    assert result.key?(:lng)
  end

  test "get_city_coordinates falls back for unknown city" do
    # Mock GeoapifyService to avoid API call
    mock_service = Object.new
    mock_service.define_singleton_method(:text_search) do |**_args|
      # Return result inside BiH boundary
      [{ lat: 43.85, lng: 18.41, name: "TestCity" }]
    end

    GeoapifyService.stub(:new, mock_service) do
      result = Platform::DSL::Executor.send(:get_city_coordinates, "NonExistentCity12345")

      # Should return coords from the mock
      assert result.is_a?(Hash)
      assert result.key?(:lat)
      assert result.key?(:lng)
    end
  end

  # API keys check test (internal method)
  test "check_api_keys returns status for all keys" do
    result = Platform::DSL::Executor.send(:check_api_keys)

    assert result.is_a?(Hash)
    assert result.key?(:anthropic)
    assert result.key?(:geoapify)
    assert result.key?(:elevenlabs)
    assert_includes %w[configured missing], result[:anthropic]
  end

  # Check queue health test (internal method)
  test "check_queue_health returns queue statistics" do
    result = Platform::DSL::Executor.send(:check_queue_health)

    assert result.is_a?(Hash)
    # Returns pending/failed or status/message on error
    assert result.key?(:pending) || result.key?(:status)
  end

  # Format record fallback test (for record without specific format method)
  test "format_record uses fallback for unknown record types" do
    record = AudioTour.create!(
      location: @sarajevo_location,
      locale: "bs",
      script: "Test script"
    )

    result = Platform::DSL::Executor.send(:format_record, record)

    assert result.is_a?(Hash)
    assert result.key?("id") || result.key?(:id)
  end

  # Estimate audio cost internal method test
  test "estimate_audio_cost internal method" do
    ast = { table: "locations", filters: { city: "Sarajevo" } }
    result = Platform::DSL::Executor.send(:estimate_audio_cost, ast)

    assert result.is_a?(Hash)
    assert result.key?(:total_locations)
    assert result.key?(:estimated_cost_usd)
  end

  # Logs query via DSL
  test "execute_logs_query via DSL" do
    result = Platform::DSL.execute("logs | recent")

    assert result.is_a?(Hash) || result.is_a?(Array)
  end

  # Infrastructure query via DSL
  test "execute_infrastructure_query via DSL" do
    result = Platform::DSL.execute("infrastructure | health")

    assert result.is_a?(Hash)
  end

  # Summaries query via DSL with valid syntax
  test "execute_summaries_query via DSL" do
    result = Platform::DSL.execute("summaries { dimension: \"city\" } | list")

    assert result.is_a?(Hash) || result.is_a?(Array)
  end

  # Schema describe for different tables
  test "schema describe shows table structure for experiences" do
    result = Platform::DSL.execute("schema | describe experiences")

    assert result.is_a?(Hash)
    assert_equal "experiences", result[:table].to_s
    assert result[:columns].any?
  end

  # Count with filters
  test "count with city filter returns integer" do
    result = Platform::DSL.execute('locations { city: "Sarajevo" } | count')

    assert result.is_a?(Integer)
  end

  # Show single record - returns array of formatted records
  test "show returns formatted location record" do
    result = Platform::DSL.execute("locations { id: #{@sarajevo_location.id} } | show")

    # Show returns array of formatted records for table queries
    assert result.is_a?(Array)
    assert result.size >= 1
  end

  # Sample operation test
  test "sample returns limited records" do
    result = Platform::DSL.execute("locations | sample 1")

    assert result.is_a?(Array)
    assert result.size <= 1
  end

  # Build stats directly test (tests specific internal method)
  test "build_stats_directly returns complete schema stats" do
    result = Platform::DSL::Executor.send(:build_stats_directly)

    assert result.is_a?(Hash)
    assert result[:content].key?(:locations) || result[:content].key?("locations")
  end
end
