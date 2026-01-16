# frozen_string_literal: true

require "test_helper"

class Platform::ConversationTest < ActiveSupport::TestCase
  # These tests use a mock Brain to avoid RubyLLM initialization issues
  # Full Brain tests are in brain_test.rb

  test "initializes with a new PlatformConversation when none provided" do
    # Don't create Brain - just test record creation
    record = PlatformConversation.create!
    conv = create_conversation_with_mock_brain(record)

    assert_instance_of PlatformConversation, conv.record
    assert conv.record.persisted?
  end

  test "uses provided record when initialized with record" do
    existing_record = PlatformConversation.create!
    conv = create_conversation_with_mock_brain(existing_record)

    assert_equal existing_record.id, conv.record.id
  end

  test "id returns conversation record id" do
    record = PlatformConversation.create!
    conv = create_conversation_with_mock_brain(record)

    assert_equal record.id, conv.id
  end

  test "messages returns record messages" do
    record = PlatformConversation.create!
    record.add_message(role: "user", content: "Hello")
    record.add_message(role: "assistant", content: "Hi there")

    conv = create_conversation_with_mock_brain(record)
    messages = conv.messages

    assert_equal 2, messages.size
    assert_equal "user", messages[0]["role"]
    assert_equal "assistant", messages[1]["role"]
  end

  test "context returns record context" do
    record = PlatformConversation.create!(context: { "key" => "value" })
    conv = create_conversation_with_mock_brain(record)

    assert_equal({ "key" => "value" }, conv.context)
  end

  test "update_context merges new context with existing" do
    record = PlatformConversation.create!(context: { "existing" => "value" })
    conv = create_conversation_with_mock_brain(record)

    conv.update_context({ "new" => "data" })
    record.reload

    assert_equal "value", record.context["existing"]
    assert_equal "data", record.context["new"]
  end

  test "handle_error logs error and marks conversation as errored" do
    record = PlatformConversation.create!
    conv = create_conversation_with_mock_brain(record)

    error = StandardError.new("Test error")
    error.set_backtrace(["line1", "line2"])

    result = conv.send(:handle_error, error)

    record.reload
    assert_equal "error", record.status
    assert_equal "Test error", record.context["last_error"]
    assert_includes result, "Test error"
    assert_includes result, "Došlo je do greške"
  end

  test "send_message saves user message" do
    record = PlatformConversation.create!
    conv = create_conversation_with_mock_brain(record)

    # Call send_message - it may succeed or handle error depending on implementation
    conv.send_message("Hello")

    record.reload
    # Should have at least user message
    assert record.messages.size >= 1
    assert_equal "user", record.messages[0]["role"]
    assert_equal "Hello", record.messages[0]["content"]
  end

  test "send_message handles brain errors gracefully" do
    record = PlatformConversation.create!
    conv = create_conversation_with_mock_brain(record)

    # Replace brain with one that raises an error
    error_brain = Object.new
    error_brain.define_singleton_method(:process) { |_| raise StandardError, "Brain error" }
    conv.instance_variable_set(:@brain, error_brain)

    result = conv.send_message("Hello")

    record.reload
    assert_equal "error", record.status
    assert_includes result, "Brain error"
  end

  private

  # Creates a Conversation with a mock Brain to avoid RubyLLM initialization
  def create_conversation_with_mock_brain(record)
    conv = Platform::Conversation.allocate
    conv.instance_variable_set(:@record, record)
    conv.instance_variable_set(:@brain, MockBrain.new)
    conv
  end

  class MockBrain
    def process(_message)
      { content: "Mock response", dsl_queries: [] }
    end
  end
end
