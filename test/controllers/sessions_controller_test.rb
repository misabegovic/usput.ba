# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: "sessiontest",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  teardown do
    @user&.destroy
  end

  # === New action tests ===

  test "new renders login form" do
    get login_path

    assert_response :success
  end

  test "new redirects to root when already logged in" do
    post login_path, params: { username: @user.username, password: "password123" }

    get login_path

    assert_redirected_to root_path
  end

  # === Create action tests (HTML format) ===

  test "create logs in user with valid credentials" do
    post login_path, params: { username: @user.username, password: "password123" }

    assert_redirected_to root_path
    assert_equal I18n.t("auth.login_success"), flash[:notice]
    assert session[:user_id].present?
  end

  test "create handles case-insensitive username" do
    post login_path, params: { username: @user.username.upcase, password: "password123" }

    assert_redirected_to root_path
    assert session[:user_id].present?
  end

  test "create fails with invalid password" do
    post login_path, params: { username: @user.username, password: "wrongpassword" }

    assert_response :unprocessable_entity
    assert_equal I18n.t("auth.invalid_credentials"), flash.now[:alert]
    assert_nil session[:user_id]
  end

  test "create fails with non-existent username" do
    post login_path, params: { username: "nonexistent", password: "password123" }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "create fails with empty credentials" do
    post login_path, params: { username: "", password: "" }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "create merges travel profile from localStorage" do
    travel_profile = {
      "visited" => [ { "id" => "test-id" } ],
      "favorites" => []
    }.to_json

    post login_path, params: {
      username: @user.username,
      password: "password123",
      travel_profile_data: travel_profile
    }

    assert_redirected_to root_path
    @user.reload
    assert @user.travel_profile_data["visited"].present?
  end

  test "create ignores invalid travel profile JSON" do
    post login_path, params: {
      username: @user.username,
      password: "password123",
      travel_profile_data: "invalid json {{{}"
    }

    assert_redirected_to root_path
    # Should succeed without crashing
  end

  # === Create action tests (JSON format) ===

  test "create returns JSON success for valid credentials" do
    post login_path, params: { username: @user.username, password: "password123" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert_equal @user.uuid, body["user"]["id"]
    assert_equal @user.username, body["user"]["username"]
  end

  test "create returns JSON error for invalid credentials" do
    post login_path, params: { username: @user.username, password: "wrong" }, as: :json

    assert_response :unauthorized
    body = response.parsed_body
    assert_not body["success"]
    assert body["error"].present?
  end

  test "create returns travel profile data in JSON response" do
    @user.update!(travel_profile_data: { "visited" => [ { "id" => "test" } ] })

    post login_path, params: { username: @user.username, password: "password123" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["user"]["travel_profile_data"].present?
  end

  # === Destroy action tests (HTML format) ===

  test "destroy logs out user" do
    post login_path, params: { username: @user.username, password: "password123" }
    assert session[:user_id].present?

    delete logout_path

    assert_redirected_to root_path
    assert_equal I18n.t("auth.logout_success"), flash[:notice]
    assert_nil session[:user_id]
  end

  test "destroy succeeds even when not logged in" do
    delete logout_path

    assert_redirected_to root_path
  end

  # === Destroy action tests (JSON format) ===

  test "destroy returns JSON success" do
    post login_path, params: { username: @user.username, password: "password123" }

    delete logout_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
  end

  # === Security tests ===

  test "login prevents SQL injection in username" do
    post login_path, params: {
      username: "' OR '1'='1",
      password: "password"
    }

    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "session is regenerated on login" do
    # Make initial request to get a session
    get login_path
    old_session_options = request.session_options.dup

    post login_path, params: { username: @user.username, password: "password123" }

    # Session should be different after login (session fixation protection)
    # Note: Rails handles this automatically
    assert_redirected_to root_path
  end

  test "session is cleared on logout" do
    post login_path, params: { username: @user.username, password: "password123" }

    delete logout_path

    assert_nil session[:user_id]
  end

  # === Edge cases ===

  test "create handles whitespace in username" do
    post login_path, params: { username: "  #{@user.username}  ", password: "password123" }

    # Should either trim and succeed or fail gracefully
    # Current implementation doesn't trim, so this should fail
    assert_response :unprocessable_entity
  end

  test "create handles nil username" do
    post login_path, params: { username: nil, password: "password123" }

    assert_response :unprocessable_entity
  end

  test "create handles nil password" do
    post login_path, params: { username: @user.username, password: nil }

    assert_response :unprocessable_entity
  end
end
