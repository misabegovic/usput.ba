# frozen_string_literal: true

require "test_helper"

# Proposals and curator applications were removed with the curator area:
# curators edit content directly in Avo and an admin sets roles there.
class Platform::DSL::ApprovalTest < ActiveSupport::TestCase
  test "proposal commands are gone" do
    [ "approve proposal { id: 1 }", 'reject proposal { id: 1 } reason "x"' ].each do |dsl|
      assert_raises(Platform::DSL::ParseError, dsl) { Platform::DSL::Parser.parse(dsl) }
    end
    error = assert_raises(Platform::DSL::ExecutionError) { Platform::DSL.execute("proposals | list") }
    assert_match "proposals", error.message
  end

  test "curator application commands are gone" do
    [ "approve application { id: 1 }", 'reject application { id: 1 } reason "x"' ].each do |dsl|
      assert_raises(Platform::DSL::ParseError, dsl) { Platform::DSL::Parser.parse(dsl) }
    end
    error = assert_raises(Platform::DSL::ExecutionError) { Platform::DSL.execute("applications | list") }
    assert_match "applications", error.message
  end
end
