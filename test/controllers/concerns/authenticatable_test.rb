# frozen_string_literal: true

require "test_helper"

class AuthenticatableTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: "test_user_#{SecureRandom.hex(4)}",
      email: "test_user_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      user_type: :basic
    )
    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      email: "test_curator_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      user_type: :curator
    )
    @admin = User.create!(
      username: "test_admin_#{SecureRandom.hex(4)}",
      email: "test_admin_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      user_type: :admin
    )
  end

  # current_user tests

  test "current_user returns nil when not logged in" do
    get curator_root_path

    assert_redirected_to new_user_session_path
  end

  test "current_user returns user when logged in" do
    post user_session_path, params: { user: { email: @curator.email, password: "password123" } }

    get curator_root_path

    assert_response :success
  end

  # logged_in? tests

  test "redirects to login when not logged in for protected routes" do
    get curator_root_path

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("auth.login_required"), flash[:alert]
  end

  test "allows access when logged in" do
    post user_session_path, params: { user: { email: @curator.email, password: "password123" } }

    get curator_root_path

    assert_response :success
  end

  # require_login JSON response test

  test "require_login returns JSON error for API requests" do
    get curator_root_path, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
    assert_equal "Unauthorized", response.parsed_body["error"]
  end

  # log_in and log_out tests

  test "log_in sets session" do
    post user_session_path, params: { user: { email: @curator.email, password: "password123" } }

    get curator_root_path

    assert_response :success
  end

  test "log_out clears session" do
    post user_session_path, params: { user: { email: @curator.email, password: "password123" } }

    delete destroy_user_session_path

    get curator_root_path

    assert_redirected_to new_user_session_path
  end

  # require_curator tests

  test "require_curator redirects regular users" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    get curator_root_path

    assert_redirected_to root_path
    assert_equal I18n.t("auth.curator_required"), flash[:alert]
  end

  test "require_curator allows curators" do
    post user_session_path, params: { user: { email: @curator.email, password: "password123" } }

    get curator_root_path

    assert_response :success
  end

  test "require_curator allows admins" do
    post user_session_path, params: { user: { email: @admin.email, password: "password123" } }

    get curator_root_path

    assert_response :success
  end

  test "require_curator returns JSON forbidden for API requests" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    get curator_root_path, headers: { "Accept" => "application/json" }

    assert_response :forbidden
    assert_equal "Forbidden", response.parsed_body["error"]
  end

  # require_admin tests

  test "require_admin redirects curators" do
    post user_session_path, params: { user: { email: @curator.email, password: "password123" } }

    get curator_admin_users_path

    assert_redirected_to curator_root_path
    assert_equal I18n.t("auth.admin_required"), flash[:alert]
  end

  test "require_admin allows admins" do
    post user_session_path, params: { user: { email: @admin.email, password: "password123" } }

    get curator_admin_users_path

    assert_response :success
  end

  test "require_admin returns JSON forbidden for API requests" do
    post user_session_path, params: { user: { email: @curator.email, password: "password123" } }

    get curator_admin_users_path, headers: { "Accept" => "application/json" }

    assert_response :forbidden
    assert_equal "Forbidden", response.parsed_body["error"]
  end
end
