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

  test "exec executes DSL and outputs JSON" do
    output = capture_output { @cli.exec("schema | stats") }

    # Should output valid JSON
    parsed = JSON.parse(output.strip)
    assert parsed.is_a?(Hash)
    assert parsed["success"]
  end

  test "exec handles errors gracefully" do
    output = capture_output do
      # Use SystemExit rescue to prevent test from exiting
      begin
        @cli.exec("invalid !!! query")
      rescue SystemExit
        # expected
      end
    end

    parsed = JSON.parse(output.strip)
    assert_equal false, parsed["success"]
    assert_equal "parse_error", parsed["error"]
  end

  test "production_guard! allows in non-production" do
    # In test environment, should not exit
    assert_nothing_raised do
      Platform::CLI.production_guard!
    end
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
