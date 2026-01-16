# frozen_string_literal: true

require "test_helper"

class PlatformTest < ActiveSupport::TestCase
  test "root returns platform lib path" do
    result = Platform.root

    assert result.is_a?(Pathname)
    assert result.to_s.end_with?("lib/platform")
  end

  test "version returns version string" do
    result = Platform.version

    assert result.is_a?(String)
    assert result.match?(/\d+\.\d+\.\d+/)
  end

  test "Error is defined as StandardError subclass" do
    assert Platform::Error < StandardError
  end
end
