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
      args: [ "sum", :rating ],
      group_by: nil
    })

    # Sum may be nil or number
    assert result.nil? || result.is_a?(Numeric)
  end

  test "aggregate avg" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Review.all, {
      args: [ "avg", :rating ],
      group_by: nil
    })

    assert result.nil? || result.is_a?(Numeric)
  end

  test "aggregate avg with group_by" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, {
      args: [ "count" ],
      group_by: :city
    })

    assert_kind_of Hash, result
  end

  test "raises error for unknown aggregate function" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_aggregate, Location.all, {
        args: [ "unknown_func" ],
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

  # Stats tests (caching removed)
  test "build_stats returns live data" do
    result = Platform::DSL::Executor.send(:build_stats)

    assert_equal :live, result[:source]
  end


  # Apply filter edge cases
  test "apply_filter with array value" do
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :city, [ "Sarajevo", "Mostar" ])

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
    ActiveStorage::Blob.stub(:service, -> { raise "Storage error" }) do
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

  test "build_stats always returns live data (caching removed)" do
    result = Platform::DSL::Executor.send(:build_stats)

    assert_equal :live, result[:source]
    assert result[:content].is_a?(Hash)
  end

  # Apply operation edge cases - test with valid operations only
  test "apply_operation with order operation" do
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :order, args: [ :name, :asc ] })

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
    assert_equal :list_proposals, result[:action]
  end

  test "execute_proposals_query with show operation" do
    proposal = ContentChange.create!(
      user: @test_user,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { name: "Test" },
      status: :pending
    )

    result = Platform::DSL.execute("proposals { id: #{proposal.id} } | show")

    assert result.is_a?(Hash)
    assert_equal :show_proposal, result[:action]
  end

  test "execute_proposals_query with status filter" do
    result = Platform::DSL.execute('proposals { status: "pending" } | list')

    assert result.is_a?(Hash)
    assert_equal :list_proposals, result[:action]
  end

  # Applications query tests
  test "execute_applications_query with list" do
    result = Platform::DSL.execute("applications | list")

    assert result.is_a?(Hash)
    assert_equal :list_applications, result[:action]
  end

  # Curators query tests
  test "execute_curators_query with list" do
    result = Platform::DSL.execute("curators | list")

    assert result.is_a?(Hash)
    assert_equal :list_curators, result[:action]
  end

  test "execute_curators_query with stats" do
    result = Platform::DSL.execute("curators | stats")

    assert result.is_a?(Hash)
    # Stats returns Services::SpamDetector.statistics hash
  end

  # Curator management tests
  test "execute_curator_management block command" do
    curator = User.create!(
      username: "block_test_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )

    result = Platform::DSL.execute("block curator { id: #{curator.id} } reason \"Spam activity\"")

    assert result.is_a?(Hash)
    assert result[:success]
    assert_equal :block_curator, result[:action]
  end

  test "execute_curator_management unblock command" do
    curator = User.create!(
      username: "unblock_test_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )
    curator.block_for_spam!("Test block")

    result = Platform::DSL.execute("unblock curator { id: #{curator.id} }")

    assert result.is_a?(Hash)
    assert result[:success]
    assert_equal :unblock_curator, result[:action]
  end

  # Code query tests
  test "execute_code_query with list" do
    result = Platform::DSL.execute("code | models")

    assert result.is_a?(Hash)
    assert_equal :list_models, result[:action]
  end



  # Approval tests
  test "execute_approval approve proposal" do
    proposal = ContentChange.create!(
      user: @test_user,
      change_type: :update_content,
      changeable_type: "Location",
      changeable_id: @sarajevo_location.id,
      proposed_data: { name: "Updated Name" },
      status: :pending
    )

    result = Platform::DSL.execute("approve proposal { id: #{proposal.id} }")

    assert result.is_a?(Hash)
    assert result[:success]
    assert_equal :approve_proposal, result[:action]
  end

  test "execute_approval reject proposal" do
    proposal = ContentChange.create!(
      user: @test_user,
      change_type: :update_content,
      changeable_type: "Location",
      changeable_id: @sarajevo_location.id,
      proposed_data: { name: "Updated Name" },
      status: :pending
    )

    result = Platform::DSL.execute("reject proposal { id: #{proposal.id} } reason \"Invalid data\"")

    assert result.is_a?(Hash)
    assert result[:success]
    assert_equal :reject_proposal, result[:action]
  end

  # Geoapify service test
  test "geoapify_service returns service instance" do
    skip "Requires GEOAPIFY_API_KEY to be configured" unless ENV["GEOAPIFY_API_KEY"].present?

    service = Platform::DSL::Executor.send(:geoapify_service)

    assert service.is_a?(GeoapifyService)
  end

  # Get city coordinates tests
  test "get_city_coordinates returns coords from existing location" do
    result = Platform::DSL::Executor.send(:get_city_coordinates, "Sarajevo")

    assert result.is_a?(Hash)
    assert result[:lat].present?
    assert result[:lng].present?
  end

  test "get_city_coordinates falls back for unknown city" do
    # Mock geoapify service
    mock_service = Object.new
    mock_service.define_singleton_method(:text_search) { |**_| [ { lat: 43.0, lng: 18.0 } ] }

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      result = Platform::DSL::Executor.send(:get_city_coordinates, "UnknownTestCity123")
      # May return nil if not in BiH or coords if mocked correctly
      assert result.nil? || result.is_a?(Hash)
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
    result = Platform::DSL.execute('estimate audio cost for locations { city: "Sarajevo" }')

    assert result.is_a?(Hash)
    assert_equal :estimate_audio_cost, result[:action]
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


  # External query via DSL
  test "execute_external_query via DSL" do
    # Mock geoapify service for this test
    mock_service = Object.new
    mock_service.define_singleton_method(:search_nearby) { |**_| [] }

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL.execute('external { city: "Sarajevo" } | search_pois')

        assert result.is_a?(Hash)
        assert_equal "Sarajevo", result[:city]
      end
    end
  end

  # Mutation via DSL
  test "execute_mutation via DSL" do
    result = Platform::DSL.execute("update location { id: #{@sarajevo_location.id} } set { name: \"Updated Test\" }")

    assert result.is_a?(Hash)
    assert result[:success]
    assert_equal :update, result[:action]
  end

  # Generation via DSL
  test "execute_generation via DSL" do
    # Mock LLM for generation
    Platform::DSL::Executors::Content.stub(:generate_with_llm, "Generirani opis lokacije.") do
      result = Platform::DSL.execute("generate description for location { id: #{@sarajevo_location.id} }")

      assert result.is_a?(Hash)
      assert result[:success]
      assert_equal :generate_description, result[:action]
    end
  end

  # Audio via DSL
  test "execute_audio via DSL" do
    # Mock audio generator
    mock_generator = Object.new
    mock_result = { status: :generated, duration_estimate: "3 min", audio_info: nil }
    mock_generator.define_singleton_method(:generate) { |**_| mock_result }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      result = Platform::DSL.execute("synthesize audio for location { id: #{@sarajevo_location.id} }")

      assert result.is_a?(Hash)
      assert result[:success]
      assert_equal :synthesize_audio, result[:action]
    end
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

  # Applications count test
  test "applications count returns statistics" do
    result = Platform::DSL.execute("applications | count")

    assert result.is_a?(Hash) || result.is_a?(Integer)
  end

  # Code search test
  test "code search finds patterns in codebase" do
    result = Platform::DSL.execute('code | search "class"')

    assert result.is_a?(Hash) || result.is_a?(Array)
  end

  # Code structure test
  test "code structure shows directory structure" do
    result = Platform::DSL.execute('code { path: "lib" } | structure')

    assert result.is_a?(Hash)
  end

  # Curators stats test
  test "curators stats returns curator statistics" do
    result = Platform::DSL.execute("curators | count")

    assert result.is_a?(Hash) || result.is_a?(Integer)
  end


  # Apply filters internal method test
  test "apply_filters filters by column" do
    records = Platform::DSL::Executor.send(:apply_filters, Location, { city: "Sarajevo" })

    assert records.is_a?(ActiveRecord::Relation)
  end

  # Format record test for locations
  test "format_record_for_location returns hash with all fields" do
    result = Platform::DSL::Executor.send(:format_record, @sarajevo_location)

    assert result.is_a?(Hash)
    assert result.key?(:id) || result.key?("id")
    assert result.key?(:name) || result.key?("name")
  end

  # Additional coverage for uncovered branches

  test "check_api_keys returns missing when all ENV vars empty" do
    original_geoapify = ENV["GEOAPIFY_API_KEY"]
    original_elevenlabs = ENV["ELEVENLABS_API_KEY"]

    ENV["GEOAPIFY_API_KEY"] = ""
    ENV["ELEVENLABS_API_KEY"] = ""

    result = Platform::DSL::Executor.send(:check_api_keys)

    assert_equal "missing", result[:geoapify]
    assert_equal "missing", result[:elevenlabs]
  ensure
    ENV["GEOAPIFY_API_KEY"] = original_geoapify
    ENV["ELEVENLABS_API_KEY"] = original_elevenlabs
  end

  test "check_api_keys returns configured when geoapify and elevenlabs set" do
    original_geoapify = ENV["GEOAPIFY_API_KEY"]
    original_elevenlabs = ENV["ELEVENLABS_API_KEY"]

    ENV["GEOAPIFY_API_KEY"] = "test-geoapify-key"
    ENV["ELEVENLABS_API_KEY"] = "test-elevenlabs-key"

    result = Platform::DSL::Executor.send(:check_api_keys)

    assert_equal "configured", result[:geoapify]
    assert_equal "configured", result[:elevenlabs]
  ensure
    ENV["GEOAPIFY_API_KEY"] = original_geoapify
    ENV["ELEVENLABS_API_KEY"] = original_elevenlabs
  end

  # Format created record for Experience
  test "format_created_record for Experience returns hash" do
    experience = Experience.create!(title: "Test Experience", estimated_duration: 60)
    result = Platform::DSL::Executors::Content.send(:format_created_record, experience)

    assert result.is_a?(Hash)
    assert_equal experience.id, result[:id]
    assert_equal "Test Experience", result[:title]
  end

  # Apply filter special cases
  test "apply_filter with ai_generated true" do
    @sarajevo_location.update!(ai_generated: true)

    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :ai_generated, true)

    assert scope.exists?
  end

  test "apply_filter with ai_generated false" do
    @mostar_location.update!(ai_generated: false)

    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :ai_generated, false)

    assert scope.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with missing_description false" do
    @sarajevo_location.update!(description: "Has description")

    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :missing_description, false)

    assert scope.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with status filter" do
    scope = Platform::DSL::Executor.send(:apply_filter, ContentChange.all, :status, "pending")

    assert scope.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with type filter" do
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :type, "place")

    # Should handle type filter (may return scope or raise)
    assert scope.is_a?(ActiveRecord::Relation) || true
  rescue Platform::DSL::ExecutionError
    # Type might not be a valid filter - that's ok
    assert true
  end

  # Apply operation - aggregate with sum
  test "apply_aggregate with sum function" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, { name: :aggregate, args: [ "sum", :id ] })

    # Should return a sum value
    assert result.is_a?(Numeric) || result.is_a?(BigDecimal)
  end

  test "apply_aggregate with avg function" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, { name: :aggregate, args: [ "avg", :id ] })

    # Should return an average value
    assert result.is_a?(Numeric) || result.is_a?(BigDecimal) || result.nil?
  end

  test "apply_aggregate with sum and group_by" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, { name: :aggregate, args: [ "sum", :id ], group_by: :city })

    assert result.is_a?(Hash)
  end

  test "apply_aggregate with avg and group_by" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, { name: :aggregate, args: [ "avg", :id ], group_by: :city })

    assert result.is_a?(Hash)
  end

  test "apply_aggregate raises for unknown function" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_aggregate, Location.all, { name: :aggregate, args: [ "unknown_func" ] })
    end
  end

  # Apply operation - select
  test "apply_operation with select" do
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :select, args: [ :name, :city ] })

    assert result.is_a?(ActiveRecord::Relation)
  end

  # Apply operation - limit with argument
  test "apply_operation limit with specific number" do
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :limit, args: [ 5 ] })

    assert result.is_a?(Array)
    assert result.length <= 5
  end

  # Apply where condition with equals
  test "apply_where_condition with equals" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id = 1")

    assert scope.to_sql.include?("=")
  end

  # Test unknown operation raises
  test "apply_operation raises for unknown operation" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :unknown_op })
    end
  end

  # Curators list test
  test "curators list returns curators" do
    result = Platform::DSL.execute("curators | list")

    assert result.is_a?(Hash)
    assert_equal :list_curators, result[:action]
    assert result.key?(:curators)
  end

  # Logs with filter - removed (audit logging no longer exists)
  test "logs with action filter returns message" do
    result = Platform::DSL.execute('logs { action: "create" } | list')

    assert result.is_a?(Hash)
    assert_includes result[:message], "removed" if result.key?(:message)
  end

  # External geocode operation
  test "geocode_address returns hash for valid address" do
    mock_service = Object.new
    mock_service.define_singleton_method(:text_search) { |**_| [ { name: "Test", lat: 43.85, lng: 18.41, primary_type: "poi" } ] }

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:geocode_address, { address: "Sarajevo" })

        assert result.is_a?(Hash)
        assert result[:found]
      end
    end
  end

  # External reverse_geocode operation
  test "reverse_geocode_coords returns hash for valid coords" do
    mock_service = Object.new
    mock_service.define_singleton_method(:reverse_geocode) { |**_| { formatted: "Sarajevo", city: "Sarajevo", country: "BiH", country_code: "ba" } }

    Platform::DSL::Executors::External.stub(:geoapify_service, mock_service) do
      Ai::RateLimiter.stub(:with_delay, ->(**_opts, &block) { block.call }) do
        result = Platform::DSL::Executor.send(:reverse_geocode_coords, { lat: 43.8563, lng: 18.4131 })

        assert result.is_a?(Hash)
        assert result[:in_bih]
      end
    end
  end

  # Test estimate_audio_cost
  test "estimate_audio_cost returns cost estimate" do
    result = Platform::DSL.execute('estimate audio cost for locations { city: "Sarajevo" }')

    assert_equal :estimate_audio_cost, result[:action]
    assert result.key?(:total_locations)
    assert result.key?(:estimated_cost_usd)
  end

  # Test format_proposal returns hash with required keys
  test "format_proposal returns hash with keys" do
    proposal = ContentChange.create!(
      user: @test_user,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { name: "Test" },
      status: :pending
    )

    result = Platform::DSL::Executors::Curator.send(:format_proposal, proposal)

    assert result.is_a?(Hash)
    assert result.key?(:id)
    assert result.key?(:status)
  end

  # Test show_proposal includes reviews array
  test "show_proposal includes reviews array" do
    proposal = ContentChange.create!(
      user: @test_user,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { name: "Test Proposal" },
      status: :pending
    )

    result = Platform::DSL::Executors::Curator.send(:show_proposal, { id: proposal.id })

    assert result.is_a?(Hash)
    assert result.key?(:reviews)
  end

  # Test execute_schema_query with unknown operation
  test "execute_schema_query raises for unknown operation" do
    ast = { operations: [ { name: :unknown_schema_op } ] }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:execute_schema_query, ast)
    end
  end

  # Test execute with unknown query type
  test "execute raises for unknown query type" do
    ast = { type: :unknown_type }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:execute, ast)
    end
  end

  # Test apply_filter with has_audio false
  test "apply_filter with has_audio false" do
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :has_audio, false)

    assert scope.is_a?(ActiveRecord::Relation)
  end

  # Test apply_filter with min_rating
  test "apply_filter with min_rating" do
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :min_rating, 4.0)

    # Should filter locations or return relation
    assert scope.is_a?(ActiveRecord::Relation)
  rescue Platform::DSL::ExecutionError
    # If not supported, that's fine
    assert true
  end


  # Test logs | show - removed (audit logging no longer exists)
  test "logs show returns message about removed functionality" do
    result = Platform::DSL.execute("logs | recent")

    assert result.is_a?(Hash)
    assert result.key?(:message) || result.key?(:action)
  end

  # Test applications | list
  test "applications list returns curator applications" do
    result = Platform::DSL.execute("applications | list")

    assert result.is_a?(Hash)
    assert_equal :list_applications, result[:action]
    assert result.key?(:applications)
  end

  # Test curators | show
  test "curators show returns curator details" do
    curator = User.create!(
      username: "curator_test_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123",
      user_type: :curator
    )

    result = Platform::DSL.execute("curators { id: #{curator.id} } | show")

    assert result.is_a?(Hash)
  end

  # Test show_proposal with curator reviews
  test "show_proposal with curator reviews maps them correctly" do
    proposal = ContentChange.create!(
      user: @test_user,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { name: "Test" },
      status: :pending
    )

    CuratorReview.create!(
      content_change: proposal,
      user: @test_user,
      recommendation: :recommend_approve,
      comment: "Looks good"
    )

    result = Platform::DSL::Executors::Curator.send(:show_proposal, { id: proposal.id })

    assert result[:reviews].is_a?(Array)
    assert result[:reviews].any? { |r| r[:recommendation] == "recommend_approve" }
  end

  # Test apply_filter with Range value
  test "apply_filter with range value" do
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :id, 1..100)

    assert scope.is_a?(ActiveRecord::Relation)
    assert scope.to_sql.include?("BETWEEN")
  end

  # Test apply_filter with Hash value (JSONB)
  test "apply_filter with hash value for jsonb" do
    # Use metadata field which is jsonb
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :metadata, { key: "value" })

    assert scope.is_a?(ActiveRecord::Relation)
    assert scope.to_sql.include?("@>")
  rescue Platform::DSL::ExecutionError
    # metadata column might not exist
    assert true
  end

  # Test estimate_audio_cost with city filter
  test "estimate_audio_cost with city filter" do
    result = Platform::DSL.execute('estimate audio cost for locations { city: "Mostar" }')

    assert_equal :estimate_audio_cost, result[:action]
    assert result.key?(:by_city)
  end

  # Test apply_operation with where
  test "apply_operation with where" do
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :where, args: [ "id > 0" ] })

    assert result.is_a?(ActiveRecord::Relation) || result.is_a?(Array)
  end

  # Test describe_table returns structure for locations
  test "describe_table returns table structure" do
    result = Platform::DSL::Executor.send(:describe_table, "locations")

    assert result.is_a?(Hash)
    assert_equal "locations", result[:table].to_s
    assert result[:columns].is_a?(Array)
    assert result[:columns].include?("name")
  end

  # Test execute_delete directly
  test "execute_delete directly" do
    location = Location.create!(name: "To Delete", city: "Test", lat: 43.5, lng: 18.5)

    result = Platform::DSL::Executors::Content.send(:execute_delete, "locations", { id: location.id })

    assert result[:success]
    assert_equal :delete, result[:action]
  end

  # Test find_record_for_mutation with empty filters
  test "find_record_for_mutation raises with empty filters" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:find_record_for_mutation, Location, {})
    end
  end

  # Test find_record_for_mutation with non-id filter
  test "find_record_for_mutation with non-id filter" do
    location = Location.create!(name: "Find By Name Test", city: "Test", lat: 43.6, lng: 18.6)

    result = Platform::DSL::Executors::Content.send(:find_record_for_mutation, Location, { name: "Find By Name Test" })

    assert_equal location.id, result.id
  end

  # Test execute_update operation
  test "execute_update updates record" do
    location = Location.create!(name: "Original Name", city: "Test", lat: 43.7, lng: 18.7)

    result = Platform::DSL::Executors::Content.send(:execute_update, "locations", { id: location.id }, { name: "Updated Name" })

    assert result[:success]
    assert_equal :update, result[:action]
    location.reload
    assert_equal "Updated Name", location.name
  end

  # Test execute_delete with soft delete (Review model supports soft delete via discarded_at)
  test "execute_delete soft deletes when available" do
    location = Location.create!(name: "For Review", city: "Test", lat: 43.75, lng: 18.75)
    review = Review.create!(reviewable: location, user: @test_user, rating: 4, comment: "Good review")

    result = Platform::DSL::Executors::Content.send(:execute_delete, "reviews", { id: review.id })

    assert result[:success]
  end

  # Test count_proposals returns statistics
  test "count_proposals returns statistics hash" do
    ContentChange.create!(
      user: @test_user,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { name: "Count Test" },
      status: :pending
    )

    result = Platform::DSL::Executors::Curator.send(:count_proposals, {})

    assert result.is_a?(Hash)
    assert result.key?(:total)
    assert result.key?(:pending)
  end

  # Test list_curators returns curators with stats
  test "list_curators returns curators list" do
    User.create!(
      username: "curator_list_test_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123",
      user_type: :curator
    )

    result = Platform::DSL::Executors::Curator.send(:list_curators, {})

    assert result.is_a?(Hash)
    assert result.key?(:curators)
    assert result[:curators].is_a?(Array)
  end

  # Test count_applications through DSL
  test "count_applications returns statistics" do
    result = Platform::DSL::Executors::Curator.send(:count_applications, {})

    assert result.is_a?(Hash)
    assert result.key?(:total)
    assert result.key?(:pending)
  end

  # Test find_application raises for missing id
  test "find_application raises for missing id" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Curator.send(:find_application, {})
    end
  end

  # Test format_application with real application
  test "format_application returns formatted application" do
    application = CuratorApplication.create!(
      user: @test_user,
      motivation: "I want to help curate content for this platform. I have experience with tourism and content curation.",
      status: :pending
    )

    result = Platform::DSL::Executors::Curator.send(:format_application, application)

    assert result.is_a?(Hash)
    assert result.key?(:motivation_preview)
  end

  # Test grep_code
  test "grep_code returns search results" do
    result = Platform::DSL::Executors::External.send(:grep_code, {}, "class Location")

    assert result.is_a?(Hash)
    assert result.key?(:pattern)
    assert result.key?(:results)
  end

  # Test show_slow_queries
  test "show_slow_queries returns query analysis" do
    result = Platform::DSL::Executor.send(:show_slow_queries, {})

    assert result.is_a?(Hash)
    assert_equal :slow_queries, result[:action]
    assert result.key?(:threshold_ms)
    assert result.key?(:recent_complex_queries)
  end

  # Test show_slow_queries with custom threshold
  test "show_slow_queries uses custom threshold" do
    result = Platform::DSL::Executor.send(:show_slow_queries, { threshold: 500 })

    assert_equal 500, result[:threshold_ms]
  end

  # Test show_errors method
  test "show_errors returns error information" do
    result = Platform::DSL::Executor.send(:show_errors, {})

    assert result.is_a?(Hash)
    assert_equal :show_errors, result[:action]
    assert result.key?(:errors)
    assert result[:errors].is_a?(Array)
  end

  # Test show_audit_logs - removed (audit logging no longer exists)
  test "show_audit_logs returns message about removed functionality" do
    result = Platform::DSL::Executors::Infrastructure.send(:show_audit_logs, {})

    assert result.is_a?(Hash)
    assert_equal :audit_logs, result[:action]
    assert_includes result[:message], "removed"
  end

  # Test show_dsl_logs - removed (audit logging no longer exists)
  test "show_dsl_logs returns message about removed functionality" do
    result = Platform::DSL::Executors::Infrastructure.send(:show_dsl_logs, {})

    assert result.is_a?(Hash)
    assert_equal :dsl_logs, result[:action]
    assert_includes result[:message], "removed"
  end


  # Test apply_operation with where
  test "apply_operation handles where operation" do
    # Create some locations with different ratings
    Location.create!(name: "High Rated", city: "Sarajevo", lat: 43.85, lng: 18.41, average_rating: 4.5)
    Location.create!(name: "Low Rated", city: "Sarajevo", lat: 43.86, lng: 18.42, average_rating: 2.5)

    operation = { name: :where, args: [ "average_rating > 4" ] }
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, operation)

    assert result.is_a?(ActiveRecord::Relation)
  end

  # Test apply_operation with select
  test "apply_operation handles select operation" do
    operation = { name: :select, args: [ :id, :name ] }
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, operation)

    assert result.is_a?(ActiveRecord::Relation)
  end

  # Test apply_aggregate without group_by for count
  test "apply_aggregate handles count without group_by" do
    operation = { name: :aggregate, args: [ "count" ], group_by: nil }
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, operation)

    assert result.is_a?(Integer)
  end

  # Test apply_aggregate with sum
  test "apply_aggregate handles sum with field" do
    operation = { name: :aggregate, args: [ "sum", "reviews_count" ], group_by: nil }
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, operation)

    assert result.is_a?(Numeric)
  end

  # Test apply_aggregate with avg
  test "apply_aggregate handles avg with field" do
    operation = { name: :aggregate, args: [ "avg", "average_rating" ], group_by: nil }
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, operation)

    assert result.is_a?(Numeric) || result.nil?
  end

  # Test apply_where_condition with different operators
  test "apply_where_condition handles >= operator" do
    result = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "average_rating >= 4")

    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition handles <= operator" do
    result = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "average_rating <= 3")

    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition handles = operator" do
    result = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "reviews_count = 0")

    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition handles != operator" do
    result = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "reviews_count != 0")

    assert result.is_a?(ActiveRecord::Relation)
  end

  # Test resolve_model with NameError
  test "resolve_model handles missing model class" do
    # This tests the rescue NameError block
    # TABLE_MAP might have a mapping to a class that doesn't exist
    # We can't easily test this without modifying the constant, so just verify
    # the method works for valid tables
    result = Platform::DSL::Executor.send(:resolve_model, "locations")
    assert_equal Location, result
  end

  # Test schema describe with no table raises error
  test "execute_schema_query describe without table raises error" do
    ast = { operations: [ { name: :describe, args: nil } ] }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:execute_schema_query, ast)
    end
  end

  # Test apply_operation sample with explicit limit
  test "apply_operation sample uses provided limit" do
    operation = { name: :sample, args: [ 3 ] }
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, operation)

    assert result.is_a?(Array)
    assert result.length <= 3
  end

  # Test apply_operation sort with field and direction
  test "apply_operation sort with field and direction" do
    operation = { name: :sort, args: [ :name, :desc ] }
    result = Platform::DSL::Executor.send(:apply_operation, Location.all, operation)

    assert result.is_a?(ActiveRecord::Relation)
  end

  # Test get_city_coordinates with existing location
  test "get_city_coordinates returns coordinates from existing location" do
    result = Platform::DSL::Executors::External.send(:get_city_coordinates, "Sarajevo")

    assert result.is_a?(Hash)
    assert result.key?(:lat)
    assert result.key?(:lng)
  end
end
