# frozen_string_literal: true

require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "sessionmodel", password: "password123")
  end

  teardown do
    @user&.destroy
  end

  test "touch_seen! records the first sighting" do
    record = @user.sessions.create!

    record.touch_seen!

    assert_not_nil record.reload.last_seen_at
  end

  test "touch_seen! writes at most once an hour" do
    seen = 10.minutes.ago.change(usec: 0)
    record = @user.sessions.create!(last_seen_at: seen)

    record.touch_seen!

    assert_equal seen, record.reload.last_seen_at
  end

  test "deleting a user deletes their sessions" do
    @user.sessions.create!

    assert_difference "Session.count", -1 do
      @user.destroy
    end
  end
end
