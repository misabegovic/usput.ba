# frozen_string_literal: true

require "test_helper"

class Platform::CLITest < ActiveSupport::TestCase
  setup do
    @cli = Platform::CLI.new
  end

  test "exit_on_failure? returns true" do
    assert Platform::CLI.exit_on_failure?
  end

  test "version outputs Platform version" do
    output = capture_output { @cli.version }

    assert_includes output, "Platform"
    assert_includes output, Platform.version
  end

  test "status outputs system information" do
    output = capture_output { @cli.status }

    assert_includes output, "Usput.ba Platform"
    assert_includes output, "Rails:"
    assert_includes output, "Ruby:"
    assert_includes output, "Environment:"
    assert_includes output, "Baza:"
  end

  test "status shows database connected when available" do
    output = capture_output { @cli.status }

    assert_includes output, "Povezan"
  end

  test "status shows database error when connection fails" do
    ActiveRecord::Base.connection.stub(:execute, ->(*args) { raise "Connection refused" }) do
      output = capture_output { @cli.status }

      assert_includes output, "Greška"
    end
  end

  test "status shows RubyLLM status" do
    output = capture_output { @cli.status }

    assert_includes output, "RubyLLM:"
    # Should show either "Učitan" or "Nije učitan" depending on whether RubyLLM is defined
    assert(output.include?("Učitan") || output.include?("Nije učitan"))
  end

  test "query executes DSL and outputs JSON" do
    output = capture_output { @cli.query("schema | stats") }

    # Should output valid JSON
    parsed = JSON.parse(output.strip)
    assert parsed.is_a?(Hash)
  end

  test "query handles parse errors" do
    output = capture_output { @cli.query("invalid !!! query") }

    assert_includes output, "Greška u parsiranju"
  end

  test "query handles execution errors" do
    output = capture_output { @cli.query("prompts { id: 99999999 } | show") }

    assert_includes output, "Greška u izvršavanju"
  end

  private

  def capture_output
    old_stdout = $stdout
    $stdout = StringIO.new

    yield

    $stdout.string
  ensure
    $stdout = old_stdout
  end
end

class Platform::CLIPrivateMethodsTest < ActiveSupport::TestCase
  # Test private methods by using send

  setup do
    @cli = Platform::CLI.new
  end

  test "print_banner outputs welcome message" do
    output = capture_output { @cli.send(:print_banner) }

    assert_includes output, "Usput.ba Platform"
    assert_includes output, "Zdravo!"
    assert_includes output, "help"
    assert_includes output, "exit"
  end

  test "print_help outputs help information" do
    output = capture_output { @cli.send(:print_help) }

    assert_includes output, "Pomoć"
    assert_includes output, "Primjeri"
    assert_includes output, "DSL komande"
    assert_includes output, "schema | stats"
  end

  test "load_or_create_conversation creates new conversation when no id" do
    conversation = @cli.send(:load_or_create_conversation, nil)

    assert_instance_of Platform::Conversation, conversation
  end

  test "load_or_create_conversation creates new when id not found" do
    output = capture_output do
      conversation = @cli.send(:load_or_create_conversation, "nonexistent-id")
      assert_instance_of Platform::Conversation, conversation
    end

    assert_includes output, "nije pronađena"
  end

  test "load_or_create_conversation loads existing conversation" do
    platform_conv = PlatformConversation.create!(
      context: { test: true }
    )

    output = capture_output do
      conversation = @cli.send(:load_or_create_conversation, platform_conv.id)
      assert_instance_of Platform::Conversation, conversation
    end

    assert_includes output, "Nastavljam konverzaciju"
  end

  private

  def capture_output
    old_stdout = $stdout
    $stdout = StringIO.new

    yield

    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
