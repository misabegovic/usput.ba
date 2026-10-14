# frozen_string_literal: true

require "test_helper"

class DemoUsersSeedTest < ActionDispatch::IntegrationTest
  def load_demo_users
    silence_warnings { load Rails.root.join("db/seeds/demo_users.rb") }
  end

  test "seeds one confirmed account per role" do
    load_demo_users

    { "admin" => "admin", "curator" => "curator", "user" => "basic" }.each do |username, role|
      user = User.find_by!(username: username)
      assert_equal role, user.user_type
      assert_equal "#{username}@usput.local", user.email
      assert user.confirmed?, "#{username} should be confirmed"
    end
  end

  test "a demo account signs in with its email and password" do
    load_demo_users

    post user_session_path, params: { user: { email: "admin@usput.local", password: "admin123" } }

    assert_signed_in
  end

  test "loading twice creates no duplicates" do
    load_demo_users

    assert_no_difference -> { User.count } do
      load_demo_users
    end
  end
end
