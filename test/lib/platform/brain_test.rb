# frozen_string_literal: true

require "test_helper"

class Platform::BrainTest < ActiveSupport::TestCase
  setup do
    # Create a mock chat that responds to with_instructions
    @mock_chat = Object.new
    def @mock_chat.with_instructions(_prompt)
      self
    end

    # Stub LayerZero to prevent database access that can abort transactions
    Platform::Knowledge::LayerZero.stub :for_system_prompt, "" do
      RubyLLM.stub :chat, @mock_chat do
        @conversation = Platform::Conversation.new
        @brain = Platform::Brain.new(@conversation)
      end
    end
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
    queries = @brain.send(:extract_dsl_queries, "No DSL here")

    assert_empty queries
  end

  test "extract_dsl_queries extracts queries from content" do
    content = "Result: [DSL: schema | stats]"
    queries = @brain.send(:extract_dsl_queries, content)

    assert_equal 1, queries.size
    assert_equal "schema | stats", queries[0][:query]
  end

  test "format_result formats hash" do
    result = @brain.send(:format_result, { locations: 100, experiences: 50 })

    assert_includes result, "locations: 100"
    assert_includes result, "experiences: 50"
  end

  test "format_result formats array" do
    result = @brain.send(:format_result, ["item1", "item2"])

    assert_includes result, "• item1"
    assert_includes result, "• item2"
  end

  test "format_result handles string" do
    result = @brain.send(:format_result, "simple string")

    assert_equal "simple string", result
  end

  test "format_result handles numeric" do
    result = @brain.send(:format_result, 42)

    assert_equal "42", result
  end

  test "system_prompt contains base prompt" do
    prompt = @brain.send(:system_prompt)

    assert_includes prompt, "Usput.ba Platform"
    assert_includes prompt, "DSL"
  end

  test "base_prompt includes DSL documentation" do
    prompt = @brain.send(:base_prompt)

    assert_includes prompt, "schema | stats"
    assert_includes prompt, "locations { city:"
    assert_includes prompt, "count"
    assert_includes prompt, "sample"
  end

  test "knowledge_layer_zero returns empty on error" do
    # Force an error by stubbing
    Platform::Knowledge::LayerZero.stub :for_system_prompt, -> { raise StandardError, "test error" } do
      result = @brain.send(:knowledge_layer_zero)
      assert_equal "", result
    end
  end

  test "execute_dsl_queries handles parse errors" do
    queries = [{ query: "invalid!!! query", raw: "[DSL: invalid!!! query]" }]

    results = @brain.send(:execute_dsl_queries, queries)

    assert_equal 1, results.size
    assert_equal false, results[0][:success]
    assert_not_nil results[0][:error]
  end

  test "format_response_with_results replaces DSL blocks" do
    original = "Count: [DSL: schema | stats]"
    results = [{ query: "schema | stats", success: true, result: { total: 100 } }]

    formatted = @brain.send(:format_response_with_results, original, results)

    assert_includes formatted, "total: 100"
    refute_includes formatted, "[DSL:"
  end

  test "format_response_with_results handles errors" do
    original = "Result: [DSL: bad query]"
    results = [{ query: "bad query", success: false, error: "Parse error" }]

    formatted = @brain.send(:format_response_with_results, original, results)

    assert_includes formatted, "Greška"
    assert_includes formatted, "Parse error"
  end

  test "execute_dsl_queries executes valid queries" do
    # Mock DSL.execute to avoid transaction issues
    Platform::DSL.stub :execute, 42 do
      queries = [{ query: "prompts | count", raw: "[DSL: prompts | count]" }]

      results = @brain.send(:execute_dsl_queries, queries)

      assert_equal 1, results.size
      assert_equal true, results[0][:success]
      assert_equal 42, results[0][:result]
    end
  end

  test "process returns response with DSL content" do
    # Create a mock response with DSL
    mock_response = Object.new
    def mock_response.content
      "Here are [DSL: prompts | count] prompts"
    end

    # Mock the chat.ask method
    @mock_chat.define_singleton_method(:ask) { |_msg| mock_response }

    # Mock DSL execution and LayerZero
    Platform::DSL.stub :execute, 42 do
      Platform::Knowledge::LayerZero.stub :for_system_prompt, "" do
        RubyLLM.stub :chat, @mock_chat do
          @brain = Platform::Brain.new(@conversation)
          result = @brain.process("Show me prompts")

          assert result.key?(:content)
          assert result.key?(:dsl_queries)
          assert_includes result[:dsl_queries], "prompts | count"
          # DSL block should be replaced with actual result (count)
          refute_includes result[:content], "[DSL:"
        end
      end
    end
  end

  test "process handles response without DSL blocks" do
    mock_response = Object.new
    def mock_response.content
      "Hello! I can help you with your platform."
    end

    @mock_chat.define_singleton_method(:ask) { |_msg| mock_response }

    RubyLLM.stub :chat, @mock_chat do
      @brain = Platform::Brain.new(@conversation)
      result = @brain.process("Hello")

      assert_equal "Hello! I can help you with your platform.", result[:content]
      assert_empty result[:dsl_queries]
    end
  end

  test "knowledge_layer_zero returns layer zero content" do
    Platform::Knowledge::LayerZero.stub :for_system_prompt, "## Layer Zero Stats" do
      result = @brain.send(:knowledge_layer_zero)

      assert_includes result, "Layer Zero Stats"
    end
  end

  test "knowledge_layer_zero returns empty for blank content" do
    Platform::Knowledge::LayerZero.stub :for_system_prompt, "" do
      result = @brain.send(:knowledge_layer_zero)

      assert_equal "", result
    end
  end
end
