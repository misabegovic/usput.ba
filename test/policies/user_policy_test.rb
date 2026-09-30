# frozen_string_literal: true

require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @admin = person(:admin)
    @curator = person(:curator)
    @traveller = person(:basic)
  end

  test "only an admin sees and edits users" do
    assert UserPolicy.new(@admin, @traveller).index?
    assert UserPolicy.new(@admin, @traveller).update?
    assert_not UserPolicy.new(@curator, @traveller).index?
    assert_not UserPolicy.new(@curator, @traveller).update?
    assert_not UserPolicy.new(@traveller, @traveller).index?
    assert_not UserPolicy.new(nil, @traveller).index?
  end

  test "nobody creates or deletes users in the admin" do
    assert_not UserPolicy.new(@admin).create?
    assert_not UserPolicy.new(@admin, @traveller).destroy?
  end

  test "an admin changes other people's roles, never their own" do
    assert UserPolicy.new(@admin, @curator).change_role?
    assert_not UserPolicy.new(@admin, @admin).change_role?
    assert_not UserPolicy.new(@curator, @traveller).change_role?
  end

  test "an admin blocks others, not themselves, and only unblocks the blocked" do
    assert UserPolicy.new(@admin, @traveller).block?
    assert_not UserPolicy.new(@admin, @admin).block?
    assert_not UserPolicy.new(@admin, @traveller).unblock?

    @traveller.block!
    assert_not UserPolicy.new(@admin, @traveller).block?
    assert UserPolicy.new(@admin, @traveller).unblock?
  end

  test "controller actions map onto the policy" do
    assert UserPolicy.new(@admin, @traveller).allows?("edit")
    assert_not UserPolicy.new(@admin).allows?("new")
    assert_not UserPolicy.new(@admin, @traveller).allows?("destroy")
    assert_not UserPolicy.new(@admin).allows?("something_else")
  end

  test "resources without a policy of their own get the default" do
    assert_equal UserPolicy, AdminPolicy.for(User)
    assert_equal AdminPolicy, AdminPolicy.for(Location)
    assert AdminPolicy.new(@curator).update?
    assert_not AdminPolicy.new(@curator).destroy?
    assert AdminPolicy.new(@admin).destroy?
    assert_not AdminPolicy.new(@traveller).index?
  end

  private

  def person(role)
    User.create!(username: "policy_#{role}", email: "policy_#{role}@example.com", password: "password123", user_type: role)
  end
end
