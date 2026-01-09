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

  # Index and Show don't require credentials
  test "index is accessible without credentials" do
    get admin_users_path
    assert_response :success
  end

  test "show is accessible without credentials" do
    get admin_user_path(@user)
    assert_response :success
  end

  test "edit is accessible without credentials" do
    get edit_admin_user_path(@user)
    assert_response :success
  end

  # Update requires credentials
  test "update without credentials is rejected" do
    patch admin_user_path(@user), params: { user: { user_type: "curator" } }
    assert_redirected_to admin_root_path
    assert_match(/credentials/i, flash[:alert])
  end

  test "update with invalid credentials is rejected" do
    patch admin_user_path(@user), params: {
      user: { user_type: "curator" },
      admin_username: "wrong",
      admin_password: "wrong"
    }
    assert_redirected_to admin_root_path
    assert_match(/invalid/i, flash[:alert])
  end

  test "update with valid credentials succeeds" do
    patch admin_user_path(@user), params: {
      user: { user_type: "curator" },
      admin_username: "testadmin",
      admin_password: "testpass123"
    }
    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal "curator", @user.user_type
  end

  # Destroy requires credentials
  test "destroy without credentials is rejected" do
    assert_no_difference("User.count") do
      delete admin_user_path(@other_user)
    end
    assert_redirected_to admin_root_path
  end

  test "destroy with invalid credentials is rejected" do
    assert_no_difference("User.count") do
      delete admin_user_path(@other_user), params: {
        admin_username: "wrong",
        admin_password: "wrong"
      }
    end
    assert_redirected_to admin_root_path
  end

  test "destroy with valid credentials succeeds" do
    assert_difference("User.count", -1) do
      delete admin_user_path(@other_user), params: {
        admin_username: "testadmin",
        admin_password: "testpass123"
      }
    end
    assert_redirected_to admin_users_path
  end

  test "credentials rejected when Flipper disabled mid-request" do
    # Simulate Flipper being disabled after login but before action
    Flipper.disable(:admin_dashboard)

    patch admin_user_path(@user), params: {
      user: { user_type: "curator" },
      admin_username: "testadmin",
      admin_password: "testpass123"
    }
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
