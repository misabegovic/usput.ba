# frozen_string_literal: true

require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["ADMIN_DASHBOARD"] = "true"
    ENV["ADMIN_USERNAME"] = "testadmin"
    ENV["ADMIN_PASSWORD"] = "testpass123"
    Flipper.enable(:admin_dashboard)

    @user = User.create!(username: "testuser", password: "password123")
    @other_user = User.create!(username: "otheruser", password: "password123")

    login_as_admin
  end

  teardown do
    ENV["ADMIN_DASHBOARD"] = nil
    ENV["ADMIN_USERNAME"] = nil
    ENV["ADMIN_PASSWORD"] = nil
    Flipper.disable(:admin_dashboard)
  end

  test "index is accessible" do
    get admin_users_path
    assert_response :success
  end

  test "show is accessible" do
    get admin_user_path(@user)
    assert_response :success
  end

  test "edit is accessible" do
    get edit_admin_user_path(@user)
    assert_response :success
  end

  test "update succeeds" do
    patch admin_user_path(@user), params: { user: { user_type: "curator" } }
    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal "curator", @user.user_type
  end

  test "update to admin type succeeds" do
    patch admin_user_path(@user), params: { user: { user_type: "admin" } }
    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal "admin", @user.user_type
  end

  test "destroy succeeds" do
    assert_difference("User.count", -1) do
      delete admin_user_path(@other_user)
    end
    assert_redirected_to admin_users_path
  end

  test "actions rejected when Flipper disabled" do
    Flipper.disable(:admin_dashboard)

    patch admin_user_path(@user), params: { user: { user_type: "curator" } }
    assert_redirected_to root_path
  end

  private

  def login_as_admin
    post admin_login_path, params: {
      username: "testadmin",
      password: "testpass123"
    }
  end
end
