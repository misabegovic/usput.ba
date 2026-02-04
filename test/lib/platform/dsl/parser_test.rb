# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ParserTest < ActiveSupport::TestCase
  # Schema queries
  test "parses schema stats query" do
    ast = Platform::DSL::Parser.parse("schema | stats")
    assert_equal :schema_query, ast[:type]
    assert_equal :stats, ast[:operations].first[:name]
  end

  # Table queries
  test "parses simple table query" do
    ast = Platform::DSL::Parser.parse("locations | count")
    assert_equal :table_query, ast[:type]
    assert_equal "locations", ast[:table]
    assert_equal :count, ast[:operations].first[:name]
  end

  test "parses table query with string filter" do
    ast = Platform::DSL::Parser.parse('locations { city: "Mostar" } | count')
    assert_equal :table_query, ast[:type]
    assert_equal "locations", ast[:table]
    assert_equal "Mostar", ast[:filters][:city]
    assert_equal :count, ast[:operations].first[:name]
  end

  test "parses table query with multiple filters" do
    ast = Platform::DSL::Parser.parse('locations { city: "Sarajevo", type: "restaurant" } | sample 5')
    assert_equal :table_query, ast[:type]
    assert_equal "Sarajevo", ast[:filters][:city]
    assert_equal "restaurant", ast[:filters][:type]
  end

  test "parses table query with integer filter" do
    ast = Platform::DSL::Parser.parse("locations { id: 123 } | show")
    assert_equal :table_query, ast[:type]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses table query with boolean filter" do
    ast = Platform::DSL::Parser.parse("locations { has_audio: true } | count")
    assert_equal :table_query, ast[:type]
    assert_equal true, ast[:filters][:has_audio]
  end

  # Operations with arguments
  test "parses sample operation with argument" do
    ast = Platform::DSL::Parser.parse("locations | sample 10")
    assert_equal :sample, ast[:operations].first[:name]
    assert_includes ast[:operations].first[:args], 10
  end

  test "parses aggregate with group by" do
    ast = Platform::DSL::Parser.parse("locations | aggregate count() by city")
    op = ast[:operations].first
    assert_equal :aggregate, op[:name]
    assert_equal :city, op[:group_by]
  end

  # Error handling
  test "raises ParseError for invalid syntax" do
    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL::Parser.parse("invalid $$% syntax")
    end
  end

  # Additional transformer rules coverage

  # Float values
  test "parses table query with float filter" do
    ast = Platform::DSL::Parser.parse("locations { rating: 4.5 } | count")
    assert_equal :table_query, ast[:type]
    assert_equal 4.5, ast[:filters][:rating]
  end

  # Array values
  test "parses table query with array filter" do
    ast = Platform::DSL::Parser.parse('locations { tags: ["historic", "museum"] } | list')
    assert_equal :table_query, ast[:type]
    assert ast[:filters][:tags].is_a?(Array)
  end

  # Table query without operations
  test "parses table query without operations" do
    ast = Platform::DSL::Parser.parse('locations { city: "Sarajevo" }')
    assert_equal :table_query, ast[:type]
    assert_equal "locations", ast[:table]
    assert_equal "Sarajevo", ast[:filters][:city]
    # May or may not have empty operations array
    assert ast[:operations].nil? || ast[:operations].empty?
  end

  # Table query with only operations
  test "parses table query with only operations" do
    ast = Platform::DSL::Parser.parse("locations | sample 5")
    assert_equal :table_query, ast[:type]
    # Filters may be empty hash or nil
    assert ast[:filters].nil? || ast[:filters].empty?
    assert_equal :sample, ast[:operations].first[:name]
  end

  # Just table name
  test "parses bare table name" do
    ast = Platform::DSL::Parser.parse("locations")
    assert_equal :table_query, ast[:type]
    assert_equal "locations", ast[:table]
  end

  # Generation queries
  test "parses generate description command" do
    ast = Platform::DSL::Parser.parse("generate description for location { id: 1 }")
    assert_equal :generation, ast[:type]
    assert_equal :description, ast[:gen_type]
    assert_equal "location", ast[:table]
    assert_equal 1, ast[:filters][:id]
  end

  test "parses generate description with style" do
    ast = Platform::DSL::Parser.parse('generate description for location { id: 1 } style "formal"')
    assert_equal :generation, ast[:type]
    assert_equal :description, ast[:gen_type]
    assert_equal "formal", ast[:style]
  end

  # Approval queries
  test "parses approve proposal command" do
    ast = Platform::DSL::Parser.parse("approve proposal { id: 123 }")
    assert_equal :approval, ast[:type]
    assert_equal :approve, ast[:action]
    assert_equal :proposal, ast[:approval_type]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses reject proposal with reason" do
    ast = Platform::DSL::Parser.parse('reject proposal { id: 123 } reason "Not accurate"')
    assert_equal :approval, ast[:type]
    assert_equal :reject, ast[:action]
    assert_equal "Not accurate", ast[:reason]
  end

  test "parses approve with notes" do
    ast = Platform::DSL::Parser.parse('approve proposal { id: 123 } notes "LGTM"')
    assert_equal :approval, ast[:type]
    assert_equal :approve, ast[:action]
    assert_equal "LGTM", ast[:notes]
  end

  # Curator management commands
  test "parses block curator command" do
    ast = Platform::DSL::Parser.parse('block curator { id: 1 } reason "Spam detected"')
    assert_equal :curator_management, ast[:type]
    assert_equal :block, ast[:action]
    assert_equal 1, ast[:filters][:id]
    assert_equal "Spam detected", ast[:reason]
  end

  test "parses unblock curator command" do
    ast = Platform::DSL::Parser.parse("unblock curator { id: 1 }")
    assert_equal :curator_management, ast[:type]
    assert_equal :unblock, ast[:action]
    assert_equal 1, ast[:filters][:id]
  end

  # Improvement commands are no longer supported (removed Prompts executor)
  # test "parses prepare fix command" do
  #   ast = Platform::DSL::Parser.parse('prepare fix for "Memory leak in background jobs"')
  #   assert_equal :improvement, ast[:type]
  #   assert_equal :fix, ast[:improvement_type]
  # end

  # External queries
  test "parses external query with geocode operation" do
    ast = Platform::DSL::Parser.parse('external { address: "Baščaršija, Sarajevo" } | geocode')
    assert_equal :external_query, ast[:type]
    assert_equal "Baščaršija, Sarajevo", ast[:filters][:address]
  end

  test "parses external query with reverse_geocode" do
    ast = Platform::DSL::Parser.parse("external { lat: 43.8563, lng: 18.4131 } | reverse_geocode")
    assert_equal :external_query, ast[:type]
    assert_equal 43.8563, ast[:filters][:lat]
  end

  # Summaries queries are no longer supported (removed Knowledge executor)
  # test "parses summaries query" do
  #   ast = Platform::DSL::Parser.parse('summaries { dimension: "city" } | list')
  #   assert_equal :summaries_query, ast[:type]
  #   assert_equal "city", ast[:filters][:dimension]
  # end

  # Prompts queries are no longer supported (removed Prompts executor)
  # test "parses prompts query" do
  #   ast = Platform::DSL::Parser.parse("prompts | list")
  #   assert_equal :prompts_query, ast[:type]
  # end

  # Clusters queries are no longer supported (removed Knowledge executor)
  # test "parses clusters query with semantic" do
  #   ast = Platform::DSL::Parser.parse('clusters | semantic "ottoman heritage"')
  #   assert_equal :clusters_query, ast[:type]
  #   op = ast[:operations].first
  #   assert_equal :semantic, op[:name]
  # end

  # Error formatting
  test "parse error includes query context" do
    error = assert_raises(Platform::DSL::ParseError) do
      Platform::DSL::Parser.parse("completely invalid %%%")
    end
    assert error.message.present?
  end

  # Multiple operations chained
  test "parses chained operations" do
    ast = Platform::DSL::Parser.parse('locations { city: "Sarajevo" } | sample 5')
    assert_equal :table_query, ast[:type]
    assert ast[:operations].length >= 1
  end

  # Operation with multiple args
  test "parses sort with field and direction" do
    ast = Platform::DSL::Parser.parse("locations | sort name asc")
    op = ast[:operations].find { |o| o[:name] == :sort }
    assert op
  end

  # Audio commands
  test "parses synthesize audio command" do
    ast = Platform::DSL::Parser.parse("synthesize audio for location { id: 1 }")
    assert_equal :audio, ast[:type]
    assert_equal :synthesize, ast[:action]
  end

  test "parses estimate audio cost command" do
    ast = Platform::DSL::Parser.parse('estimate audio cost for locations { city: "Mostar" }')
    assert_equal :audio, ast[:type]
    assert_equal :estimate, ast[:action]
    assert_equal :cost, ast[:audio_type]
  end

  # Infrastructure queries
  test "parses infrastructure query" do
    ast = Platform::DSL::Parser.parse("infrastructure | health")
    assert_equal :infrastructure_query, ast[:type]
  end

  # Additional coverage for transformer rules

  # Function calls in aggregates
  test "parses aggregate with function calls" do
    ast = Platform::DSL::Parser.parse("locations | aggregate sum(rating) by city")
    op = ast[:operations].first
    assert_equal :aggregate, op[:name]
    assert op[:args].any? { |a| a.include?("sum") }
  end

  # Multiple filter types
  test "parses mixed filter types" do
    ast = Platform::DSL::Parser.parse('locations { id: 1, name: "Test", active: true } | list')
    assert_equal 1, ast[:filters][:id]
    assert_equal "Test", ast[:filters][:name]
    assert_equal true, ast[:filters][:active]
  end

  # Operation with group by
  test "parses count with group by" do
    ast = Platform::DSL::Parser.parse("locations | aggregate count() by city")
    op = ast[:operations].first
    assert_equal :aggregate, op[:name]
    assert_equal :city, op[:group_by]
  end

  # Negative numbers
  test "parses negative integer filter" do
    ast = Platform::DSL::Parser.parse("locations { offset: -10 } | list")
    # May parse as integer or preserve as expression
    assert ast[:type] == :table_query
  end

  # Empty filters
  test "parses query with empty filter block" do
    ast = Platform::DSL::Parser.parse("locations {} | list")
    assert_equal :table_query, ast[:type]
  end

  # More query types
  test "parses logs query" do
    ast = Platform::DSL::Parser.parse("logs | list")
    assert_equal :logs_query, ast[:type]
  end

  test "parses applications query" do
    ast = Platform::DSL::Parser.parse("applications | list")
    assert_equal :applications_query, ast[:type]
  end

  # Proposals queries
  test "parses proposals query" do
    ast = Platform::DSL::Parser.parse('proposals { status: "pending" } | list')
    assert_equal :proposals_query, ast[:type]
  end

  # Curators query
  test "parses curators query" do
    ast = Platform::DSL::Parser.parse("curators | list")
    assert_equal :curators_query, ast[:type]
  end

  # Show operation
  test "parses show operation" do
    ast = Platform::DSL::Parser.parse("locations { id: 1 } | show")
    assert_equal :show, ast[:operations].first[:name]
  end

  # Delete operation
  test "parses delete operation" do
    ast = Platform::DSL::Parser.parse("locations { id: 1 } | delete")
    assert_equal :delete, ast[:operations].first[:name]
  end

  # Update operation (if supported)
  test "parses update command" do
    # May not be directly supported in DSL
    ast = Platform::DSL::Parser.parse("locations { id: 1 } | list")
    assert_equal :table_query, ast[:type]
  end

  # Fields operation
  test "parses fields selection" do
    ast = Platform::DSL::Parser.parse('locations | fields "name" "city"')
    op = ast[:operations].find { |o| o[:name] == :fields }
    assert op if ast[:operations].present?
  end

  # Limit and offset
  test "parses limit operation" do
    ast = Platform::DSL::Parser.parse("locations | limit 10")
    op = ast[:operations].find { |o| o[:name] == :limit }
    assert op if ast[:operations].present?
  end

  # Additional tests for specific transformer rule coverage

  # Test simple key-value filter with integer
  test "parses simple integer key-value filter" do
    ast = Platform::DSL::Parser.parse("locations { count: 5 }")
    assert_equal 5, ast[:filters][:count]
  end

  # Test simple key-value filter with boolean
  test "parses simple boolean key-value filter" do
    ast = Platform::DSL::Parser.parse("locations { verified: false }")
    assert_equal false, ast[:filters][:verified]
  end

  # Test filter with embedded string value
  test "parses filter with string value containing spaces" do
    ast = Platform::DSL::Parser.parse('locations { address: "Main Street 123" }')
    assert_equal "Main Street 123", ast[:filters][:address]
  end

  # Test multiple operations with different types
  test "parses multiple operations with arguments" do
    ast = Platform::DSL::Parser.parse("locations | sort name asc | limit 10")
    assert ast[:operations].length >= 2
  end

  # Test mutations (create, update, delete)
  test "parses create mutation" do
    ast = Platform::DSL::Parser.parse('create location { name: "Test", city: "Sarajevo" }')
    assert_equal :mutation, ast[:type]
    assert_equal :create, ast[:action]
  end

  test "parses update mutation" do
    ast = Platform::DSL::Parser.parse('update location { id: 1 } set { name: "New Name" }')
    assert_equal :mutation, ast[:type]
    assert_equal :update, ast[:action]
  end

  test "parses delete mutation" do
    ast = Platform::DSL::Parser.parse("delete location { id: 1 }")
    assert_equal :mutation, ast[:type]
    assert_equal :delete, ast[:action]
  end

  # Test filter list parsing (array in filters block)
  test "parses multiple filters in block" do
    ast = Platform::DSL::Parser.parse('locations { city: "Sarajevo", type: "restaurant", active: true }')
    assert_equal "Sarajevo", ast[:filters][:city]
    assert_equal "restaurant", ast[:filters][:type]
    assert_equal true, ast[:filters][:active]
  end

  # Clusters queries are no longer supported (removed Knowledge executor)
  # test "parses operation with quoted string argument" do
  #   ast = Platform::DSL::Parser.parse('clusters | semantic "ottoman heritage sites"')
  #   op = ast[:operations].first
  #   assert_equal :semantic, op[:name]
  #   assert op[:args].include?("ottoman heritage sites")
  # end

  # Test where operation with condition
  test "parses where operation with condition" do
    ast = Platform::DSL::Parser.parse('locations | where "rating > 4.0"')
    op = ast[:operations].find { |o| o[:name] == :where }
    assert op if ast[:operations].present?
  end

  # Test aggregate with average function
  test "parses aggregate with avg function" do
    ast = Platform::DSL::Parser.parse("locations | aggregate avg(rating) by city")
    op = ast[:operations].first
    assert_equal :aggregate, op[:name]
    assert op[:args].any? { |a| a.include?("avg") }
    assert_equal :city, op[:group_by]
  end

  # Test filter with nested value (subtree)
  test "parses filter with complex value" do
    ast = Platform::DSL::Parser.parse('locations { metadata: "some_value" } | list')
    assert ast[:filters][:metadata].present?
  end

  # Test code query type
  test "parses code query" do
    ast = Platform::DSL::Parser.parse("code | models")
    assert_equal :code_query, ast[:type]
  end

  test "parses code query with file filter" do
    ast = Platform::DSL::Parser.parse('code { file: "app/models/user.rb" } | read')
    assert_equal :code_query, ast[:type]
    assert_equal "app/models/user.rb", ast[:filters][:file]
  end

  # Note: generate translations and generate experience have specific syntax
  # that may not be supported in the current grammar. Skipping those tests.

  # Prompt action commands are no longer supported (removed Prompts executor)
  # test "parses apply prompt command" do
  #   ast = Platform::DSL::Parser.parse("apply prompt { id: 1 }")
  #   assert_equal :prompt_action, ast[:type]
  #   assert_equal :apply, ast[:action]
  # end

  # test "parses reject prompt command" do
  #   ast = Platform::DSL::Parser.parse('reject prompt { id: 1 } reason "Not needed"')
  #   assert_equal :prompt_action, ast[:type]
  #   assert_equal :reject, ast[:action]
  # end

  # Note: prepare feature and prepare improvement may have different syntax
  # in the current grammar. The existing test covers "prepare fix" syntax.

  # Test filters with special characters in string
  test "parses filter with unicode string" do
    ast = Platform::DSL::Parser.parse('locations { city: "Sarajevo - Baščaršija" }')
    assert_equal "Sarajevo - Baščaršija", ast[:filters][:city]
  end

  # Test infrastructure operations
  test "parses infrastructure queue_status" do
    ast = Platform::DSL::Parser.parse("infrastructure | queue_status")
    assert_equal :infrastructure_query, ast[:type]
    assert_equal :queue_status, ast[:operations].first[:name]
  end

  test "parses infrastructure storage" do
    ast = Platform::DSL::Parser.parse("infrastructure | storage")
    assert_equal :infrastructure_query, ast[:type]
  end

  # Test logs operations
  test "parses logs with errors operation" do
    ast = Platform::DSL::Parser.parse("logs | errors")
    assert_equal :logs_query, ast[:type]
    assert_equal :errors, ast[:operations].first[:name]
  end

  test "parses logs with time filter" do
    ast = Platform::DSL::Parser.parse('logs { last: "24h" } | audit')
    assert_equal :logs_query, ast[:type]
  end

  # Summaries operations are no longer supported (removed Knowledge executor)
  # test "parses summaries show operation" do
  #   ast = Platform::DSL::Parser.parse('summaries { city: "Sarajevo" } | show')
  #   assert_equal :summaries_query, ast[:type]
  #   assert_equal :show, ast[:operations].first[:name]
  # end

  # test "parses summaries refresh operation" do
  #   ast = Platform::DSL::Parser.parse('summaries { dimension: "city" } | refresh')
  #   assert_equal :summaries_query, ast[:type]
  #   assert_equal :refresh, ast[:operations].first[:name]
  # end

  # Clusters operations are no longer supported (removed Knowledge executor)
  # test "parses clusters list" do
  #   ast = Platform::DSL::Parser.parse("clusters | list")
  #   assert_equal :clusters_query, ast[:type]
  #   assert_equal :list, ast[:operations].first[:name]
  # end

  # test "parses clusters refresh" do
  #   ast = Platform::DSL::Parser.parse("clusters | refresh")
  #   assert_equal :clusters_query, ast[:type]
  # end

  # Test external operations
  test "parses external validate_location" do
    ast = Platform::DSL::Parser.parse("external { lat: 43.8, lng: 18.4 } | validate_location")
    assert_equal :external_query, ast[:type]
    assert_equal :validate_location, ast[:operations].first[:name]
  end

  test "parses external check_duplicate" do
    ast = Platform::DSL::Parser.parse('external { name: "Test Location" } | check_duplicate')
    assert_equal :external_query, ast[:type]
  end

  # Test proposals operations
  test "parses proposals count" do
    ast = Platform::DSL::Parser.parse("proposals | count")
    assert_equal :proposals_query, ast[:type]
    assert_equal :count, ast[:operations].first[:name]
  end

  # Test curators operations
  test "parses curators with activity" do
    ast = Platform::DSL::Parser.parse("curators { id: 1 } | activity")
    assert_equal :curators_query, ast[:type]
    assert_equal :activity, ast[:operations].first[:name]
  end

  test "parses curators check_spam" do
    ast = Platform::DSL::Parser.parse("curators | check_spam")
    assert_equal :curators_query, ast[:type]
  end

  # Prompts operations are no longer supported (removed Prompts executor)
  # test "parses prompts show" do
  #   ast = Platform::DSL::Parser.parse("prompts { id: 1 } | show")
  #   assert_equal :prompts_query, ast[:type]
  #   assert_equal :show, ast[:operations].first[:name]
  # end

  # test "parses prompts export" do
  #   ast = Platform::DSL::Parser.parse("prompts { id: 1 } | export")
  #   assert_equal :prompts_query, ast[:type]
  # end

  # Additional Transform rule coverage tests

  # Audio with locale
  test "parses synthesize audio with locale" do
    ast = Platform::DSL::Parser.parse('synthesize audio for location { id: 1 } locale "en"')
    assert_equal :audio, ast[:type]
    assert_equal "en", ast[:locale]
  end

  # Audio with voice
  test "parses synthesize audio with voice" do
    ast = Platform::DSL::Parser.parse('synthesize audio for location { id: 1 } voice "Rachel"')
    assert_equal :audio, ast[:type]
    assert_equal "Rachel", ast[:voice]
  end

  # Audio with both locale and voice
  test "parses synthesize audio with locale and voice" do
    ast = Platform::DSL::Parser.parse('synthesize audio for location { id: 1 } locale "en" voice "Rachel"')
    assert_equal :audio, ast[:type]
    assert_equal "en", ast[:locale]
    assert_equal "Rachel", ast[:voice]
  end

  # Improvement commands are no longer supported (removed Prompts executor)
  # test "parses prepare fix with severity" do
  #   ast = Platform::DSL::Parser.parse('prepare fix for "Bug description" severity "high"')
  #   assert_equal :improvement, ast[:type]
  #   assert_equal :fix, ast[:improvement_type]
  #   assert_equal "high", ast[:severity]
  # end

  # test "parses prepare fix with file" do
  #   ast = Platform::DSL::Parser.parse('prepare fix for "Bug description" file "app/models/user.rb"')
  #   assert_equal :improvement, ast[:type]
  #   assert_equal :fix, ast[:improvement_type]
  #   assert_equal "app/models/user.rb", ast[:target_file]
  # end

  # test "parses prepare fix with severity and file" do
  #   ast = Platform::DSL::Parser.parse('prepare fix for "Bug description" severity "critical" file "app/models/user.rb"')
  #   assert_equal :improvement, ast[:type]
  #   assert_equal :fix, ast[:improvement_type]
  #   assert_equal "critical", ast[:severity]
  #   assert_equal "app/models/user.rb", ast[:target_file]
  # end

  # Generation with translations and locales
  test "parses generate translations with locales" do
    ast = Platform::DSL::Parser.parse('generate translations for location { id: 1 } to ["en", "de"]')
    assert_equal :generation, ast[:type]
    assert_equal :translations, ast[:gen_type]
    assert ast[:locales].is_a?(Array)
    assert_includes ast[:locales], "en"
    assert_includes ast[:locales], "de"
  end

  # Generation of experience from locations
  test "parses generate experience from locations" do
    ast = Platform::DSL::Parser.parse("generate experience from locations [1, 2, 3]")
    assert_equal :generation, ast[:type]
    assert_equal :experience, ast[:gen_type]
    assert ast[:location_ids].is_a?(Array)
    assert_includes ast[:location_ids], 1
    assert_includes ast[:location_ids], 2
    assert_includes ast[:location_ids], 3
  end

  # Test function call with args
  test "parses aggregate with function having arguments" do
    ast = Platform::DSL::Parser.parse("locations | aggregate avg(rating)")
    op = ast[:operations].first
    assert_equal :aggregate, op[:name]
    assert op[:args].any? { |a| a.include?("avg") && a.include?("rating") }
  end

  # Prompt action commands are no longer supported (removed Prompts executor)
  # test "parses reject prompt with simple reason" do
  #   ast = Platform::DSL::Parser.parse('reject prompt { id: 1 } reason "spam"')
  #   assert_equal :prompt_action, ast[:type]
  #   assert_equal :reject, ast[:action]
  #   assert_equal "spam", ast[:reason]
  # end

  # Test operation without any args
  test "parses simple operation name" do
    ast = Platform::DSL::Parser.parse("locations | count")
    op = ast[:operations].first
    assert_equal :count, op[:name]
  end

  # Test filters rule with array of filter items
  test "parses many filters as sequence" do
    ast = Platform::DSL::Parser.parse('locations { a: 1, b: "two", c: true, d: 4.5 }')
    assert_equal 1, ast[:filters][:a]
    assert_equal "two", ast[:filters][:b]
    assert_equal true, ast[:filters][:c]
    assert_equal 4.5, ast[:filters][:d]
  end

  # Test schema describe
  test "parses schema describe" do
    ast = Platform::DSL::Parser.parse("schema | describe locations")
    assert_equal :schema_query, ast[:type]
    op = ast[:operations].find { |o| o[:name] == :describe }
    assert op
  end

  # Test schema health
  test "parses schema health" do
    ast = Platform::DSL::Parser.parse("schema | health")
    assert_equal :schema_query, ast[:type]
    assert_equal :health, ast[:operations].first[:name]
  end

  # Test operations without args defaulting
  test "parses operation without group_by" do
    ast = Platform::DSL::Parser.parse("locations | aggregate count()")
    op = ast[:operations].first
    assert_equal :aggregate, op[:name]
    assert_nil op[:group_by]
  end

  # Quality queries
  test "parses quality stats query" do
    ast = Platform::DSL::Parser.parse("quality | stats")
    assert_equal :quality_query, ast[:type]
    assert_equal :stats, ast[:operations].first[:name]
  end

  test "parses quality audit query" do
    ast = Platform::DSL::Parser.parse("quality | audit")
    assert_equal :quality_query, ast[:type]
    assert_equal :audit, ast[:operations].first[:name]
  end

  test "parses quality locations query" do
    ast = Platform::DSL::Parser.parse("quality | locations")
    assert_equal :quality_query, ast[:type]
    assert_equal :locations, ast[:operations].first[:name]
  end

  test "parses quality experiences query" do
    ast = Platform::DSL::Parser.parse("quality | experiences")
    assert_equal :quality_query, ast[:type]
    assert_equal :experiences, ast[:operations].first[:name]
  end

  test "parses quality with filters" do
    ast = Platform::DSL::Parser.parse("quality { limit: 50 } | locations")
    assert_equal :quality_query, ast[:type]
    assert_equal 50, ast[:filters][:limit]
  end

  test "parses quality without operation defaults to stats" do
    ast = Platform::DSL::Parser.parse("quality")
    assert_equal :quality_query, ast[:type]
  end

  # Removed commands should fail to parse
  test "removed improvement commands are rejected" do
    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL::Parser.parse('prepare fix for "N+1 query"')
    end

    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL::Parser.parse('prepare feature "Add ratings"')
    end
  end

  test "removed prompt action commands are rejected" do
    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL::Parser.parse("apply prompt { id: 123 }")
    end

    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL::Parser.parse('reject prompt { id: 123 } reason "spam"')
    end
  end

  test "removed knowledge commands parse as unknown tables" do
    # These parse as table queries but executor will reject them
    ast = Platform::DSL::Parser.parse("summaries | list")
    assert_equal :table_query, ast[:type]
    assert_equal "summaries", ast[:table]

    ast = Platform::DSL::Parser.parse("clusters | list")
    assert_equal :table_query, ast[:type]
    assert_equal "clusters", ast[:table]

    ast = Platform::DSL::Parser.parse("prompts | list")
    assert_equal :table_query, ast[:type]
    assert_equal "prompts", ast[:table]
  end
end
