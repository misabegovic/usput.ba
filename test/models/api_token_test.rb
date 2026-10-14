# frozen_string_literal: true

require "test_helper"

class APITokenTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "token_owner", email: "token_owner@example.com", password: "password123")
  end

  test "a token is shown once and only its digest is kept" do
    record, token = APIToken.issue!(user: @user, name: "laptop")

    assert token.start_with?("usput_")
    assert_not_includes record.attributes.values.map(&:to_s), token
    assert_equal record, APIToken.authenticate(token)
  end

  test "a revoked, unknown or malformed token authenticates nothing" do
    record, token = APIToken.issue!(user: @user, name: "laptop")
    record.revoke!

    assert_nil APIToken.authenticate(token)
    assert_nil APIToken.authenticate("usput_unknown")
    assert_nil APIToken.authenticate(nil)
    assert_nil APIToken.authenticate("Bearer something")
  end
end
