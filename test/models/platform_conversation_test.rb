# frozen_string_literal: true

require "test_helper"

class PlatformConversationTest < ActiveSupport::TestCase
  test "creates with default values" do
    conversation = PlatformConversation.create!

    assert_equal "active", conversation.status
    assert_equal [], conversation.messages
    assert_equal({}, conversation.context)
    assert conversation.id.present?
  end

  test "validates status inclusion" do
    conversation = PlatformConversation.new(status: "invalid")

    assert_not conversation.valid?
    assert conversation.errors[:status].any?
  end

  test "add_message appends to messages array" do
    conversation = PlatformConversation.create!

    conversation.add_message(role: "user", content: "Zdravo!")

    assert_equal 1, conversation.messages.length
    assert_equal "user", conversation.messages.first["role"]
    assert_equal "Zdravo!", conversation.messages.first["content"]
    assert conversation.messages.first["timestamp"].present?
  end

  test "add_message supports metadata" do
    conversation = PlatformConversation.create!

    conversation.add_message(
      role: "assistant",
      content: "Odgovor",
      metadata: { dsl_queries: ["schema | stats"] }
    )

    assert_equal ["schema | stats"], conversation.messages.first["dsl_queries"]
  end

  test "messages_for_llm returns formatted messages" do
    conversation = PlatformConversation.create!
    conversation.add_message(role: "user", content: "Pitanje?")
    conversation.add_message(role: "assistant", content: "Odgovor.")

    llm_messages = conversation.messages_for_llm

    assert_equal 2, llm_messages.length
    assert_equal({ role: "user", content: "Pitanje?" }, llm_messages.first)
    assert_equal({ role: "assistant", content: "Odgovor." }, llm_messages.last)
  end

  test "message_count returns correct count" do
    conversation = PlatformConversation.create!
    conversation.add_message(role: "user", content: "1")
    conversation.add_message(role: "assistant", content: "2")
    conversation.add_message(role: "user", content: "3")

    assert_equal 3, conversation.message_count
  end

  test "last_message returns the last message" do
    conversation = PlatformConversation.create!
    conversation.add_message(role: "user", content: "Prva")
    conversation.add_message(role: "assistant", content: "Zadnja")

    assert_equal "Zadnja", conversation.last_message["content"]
  end

  test "archive! changes status to archived" do
    conversation = PlatformConversation.create!

    conversation.archive!

    assert_equal "archived", conversation.reload.status
  end

  test "mark_error! sets error status and context" do
    conversation = PlatformConversation.create!

    conversation.mark_error!("Test error message")

    assert_equal "error", conversation.reload.status
    assert_equal "Test error message", conversation.context["last_error"]
    assert conversation.context["error_at"].present?
  end

  test "active scope returns only active conversations" do
    active = PlatformConversation.create!(status: "active")
    archived = PlatformConversation.create!(status: "archived")

    result = PlatformConversation.active

    assert_includes result, active
    assert_not_includes result, archived
  end

  test "recent scope orders by updated_at desc" do
    old = PlatformConversation.create!
    old.update!(updated_at: 1.day.ago)
    new = PlatformConversation.create!

    result = PlatformConversation.recent.first

    assert_equal new.id, result.id
  end
end
