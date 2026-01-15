# frozen_string_literal: true

require "test_helper"

class Platform::BrainTest < ActiveSupport::TestCase
  setup do
    @conversation = Platform::Conversation.new
  end

  test "DSL_BLOCK_REGEX extracts single DSL block" do
    content = "Here is the result [DSL: schema | stats] from the query"
    matches = content.scan(Platform::Brain::DSL_BLOCK_REGEX)

    assert_equal 1, matches.size
    assert_equal "schema | stats", matches[0][0].strip
  end

  test "DSL_BLOCK_REGEX extracts multiple DSL blocks" do
    content = "[DSL: locations { city: \"Mostar\" } | count] and [DSL: schema | stats]"
    matches = content.scan(Platform::Brain::DSL_BLOCK_REGEX)

    assert_equal 2, matches.size
    assert_equal "locations { city: \"Mostar\" } | count", matches[0][0].strip
    assert_equal "schema | stats", matches[1][0].strip
  end

  test "DSL_BLOCK_REGEX handles multiline DSL" do
    content = <<~TEXT
      [DSL: locations {
        city: "Sarajevo"
      } | count]
    TEXT
    matches = content.scan(Platform::Brain::DSL_BLOCK_REGEX)

    assert_equal 1, matches.size
    assert_includes matches[0][0], "city: \"Sarajevo\""
  end

  test "extract_dsl_queries returns empty array when no DSL blocks" do
    brain = Platform::Brain.new(@conversation)
    queries = brain.send(:extract_dsl_queries, "No DSL here")

    assert_empty queries
  end

  test "extract_dsl_queries extracts queries from content" do
    brain = Platform::Brain.new(@conversation)
    content = "Result: [DSL: schema | stats]"
    queries = brain.send(:extract_dsl_queries, content)

    assert_equal 1, queries.size
    assert_equal "schema | stats", queries[0][:query]
  end

  test "format_result formats hash" do
    brain = Platform::Brain.new(@conversation)
    result = brain.send(:format_result, { locations: 100, experiences: 50 })

    assert_includes result, "locations: 100"
    assert_includes result, "experiences: 50"
  end

  test "format_result formats array" do
    brain = Platform::Brain.new(@conversation)
    result = brain.send(:format_result, ["item1", "item2"])

    assert_includes result, "• item1"
    assert_includes result, "• item2"
  end

  test "format_result handles string" do
    brain = Platform::Brain.new(@conversation)
    result = brain.send(:format_result, "simple string")

    assert_equal "simple string", result
  end

  test "format_result handles numeric" do
    brain = Platform::Brain.new(@conversation)
    result = brain.send(:format_result, 42)

    assert_equal "42", result
  end

  test "system_prompt contains base prompt" do
    brain = Platform::Brain.new(@conversation)
    prompt = brain.send(:system_prompt)

    assert_includes prompt, "Usput.ba Platform"
    assert_includes prompt, "DSL"
  end

  test "base_prompt includes DSL documentation" do
    brain = Platform::Brain.new(@conversation)
    prompt = brain.send(:base_prompt)

    assert_includes prompt, "schema | stats"
    assert_includes prompt, "locations { city:"
    assert_includes prompt, "count"
    assert_includes prompt, "sample"
  end

  test "knowledge_layer_zero returns empty on error" do
    brain = Platform::Brain.new(@conversation)

    # Force an error by stubbing
    Platform::Knowledge::LayerZero.stub :for_system_prompt, -> { raise StandardError, "test error" } do
      result = brain.send(:knowledge_layer_zero)
      assert_equal "", result
    end
  end

  test "execute_dsl_queries handles parse errors" do
    brain = Platform::Brain.new(@conversation)
    queries = [{ query: "invalid!!! query", raw: "[DSL: invalid!!! query]" }]

    results = brain.send(:execute_dsl_queries, queries)

    assert_equal 1, results.size
    assert_equal false, results[0][:success]
    assert_not_nil results[0][:error]
  end

  test "format_response_with_results replaces DSL blocks" do
    brain = Platform::Brain.new(@conversation)
    original = "Count: [DSL: schema | stats]"
    results = [{ query: "schema | stats", success: true, result: { total: 100 } }]

    formatted = brain.send(:format_response_with_results, original, results)

    assert_includes formatted, "total: 100"
    refute_includes formatted, "[DSL:"
  end

  test "format_response_with_results handles errors" do
    brain = Platform::Brain.new(@conversation)
    original = "Result: [DSL: bad query]"
    results = [{ query: "bad query", success: false, error: "Parse error" }]

    formatted = brain.send(:format_response_with_results, original, results)

    assert_includes formatted, "Greška"
    assert_includes formatted, "Parse error"
  end
end
