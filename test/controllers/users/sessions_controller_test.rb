# frozen_string_literal: true

require "test_helper"

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "sessiontest", email: "sessiontest@example.com", password: "password123")
  end

  # === The form ===

  test "the sign-in form renders" do
    get new_user_session_path

    assert_response :success
    assert_select "input[name='user[email]']"
  end

  test "a signed-in visitor is sent home from the sign-in form" do
    sign_in @user

    get new_user_session_path

    assert_redirected_to root_path
  end

  # === Returning the visitor where they were ===

  test "signing in returns the visitor to the page they came from" do
    get new_user_session_path, headers: { "HTTP_REFERER" => explore_path }

    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to explore_path
  end

  test "an explicit return_to wins over the referring page" do
    get new_user_session_path(return_to: profile_page_path), headers: { "HTTP_REFERER" => explore_path }

    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to profile_page_path
  end

  test "arriving from the register page does not bounce the visitor back to it" do
    get new_user_session_path, headers: { "HTTP_REFERER" => new_user_registration_path }

    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to root_path
  end

  test "a return_to pointing off the site is ignored" do
    get new_user_session_path(return_to: "//evil.example/steal")

    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to root_path
  end

  # === Signing in ===

  test "the right email and password sign the visitor in" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_redirected_to root_path
    assert_equal I18n.t("devise.sessions.signed_in"), flash[:notice]
    assert_signed_in
  end

  test "the email is matched regardless of case and surrounding spaces" do
    post user_session_path, params: { user: { email: "  SessionTest@Example.com ", password: "password123" } }

    assert_signed_in
  end

  test "the username does not sign anyone in" do
    post user_session_path, params: { user: { email: @user.username, password: "password123" } }

    assert_response :unprocessable_content
    assert_signed_out
  end

  test "a wrong password is refused with one message for every failure" do
    post user_session_path, params: { user: { email: @user.email, password: "wrongpassword" } }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("devise.failure.invalid")
    assert_signed_out
  end

  test "an unknown email gets the same message as a wrong password" do
    post user_session_path, params: { user: { email: "nobody@example.com", password: "password123" } }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("devise.failure.invalid")
  end

  test "empty and missing credentials are refused" do
    post user_session_path, params: { user: { email: "", password: "" } }
    assert_response :unprocessable_content

    post user_session_path, params: { user: { email: nil, password: nil } }
    assert_response :unprocessable_content
  end

  test "SQL in the email field is just a wrong email" do
    post user_session_path, params: { user: { email: "' OR '1'='1", password: "password" } }

    assert_response :unprocessable_content
    assert_signed_out
  end

  test "signing in starts a fresh Rails session" do
    get new_user_session_path
    before = session.id

    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_not_equal before.to_s, session.id.to_s
  end

  # === The guest door ===

  test "signing in merges the device's profile but never its visited claims" do
    travel_profile = { "visited" => [ { "id" => "test-id" } ], "favorites" => [ "fav-1" ] }.to_json

    post user_session_path, params: { user: { email: @user.email, password: "password123" }, travel_profile_data: travel_profile }

    assert_redirected_to root_path
    @user.reload
    assert_equal [ "fav-1" ], @user.travel_profile_data["favorites"]
    assert_empty @user.travel_profile_data["visited"], "visited comes from PlanVisit, not the browser"
  end

  test "an unreadable profile does not stop the sign-in" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" }, travel_profile_data: "invalid json {{{}" }

    assert_redirected_to root_path
    assert_signed_in
  end

  test "a failed sign-in replays nothing" do
    travel_profile = { "favorites" => [ "fav-1" ] }.to_json

    post user_session_path, params: { user: { email: @user.email, password: "wrong" }, travel_profile_data: travel_profile }

    assert_empty @user.reload.travel_profile_data["favorites"].to_a
  end

  # === Signing out ===

  test "signing out ends the session" do
    sign_in @user

    delete destroy_user_session_path

    assert_redirected_to root_path
    assert_equal I18n.t("devise.sessions.signed_out"), flash[:notice]
    assert_signed_out
  end

  test "signing out keeps the language the visitor chose" do
    sign_in @user
    get root_path(locale: :bs)

    delete destroy_user_session_path

    assert_equal "bs", session[:locale].to_s
  end

  test "signing out when not signed in is harmless" do
    delete destroy_user_session_path

    assert_redirected_to root_path
  end

  # === Ending sessions ===

  test "signing out of all other devices ends the other browser and keeps this one" do
    other = open_session
    other.post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    delete other_sessions_path

    assert_redirected_to edit_user_registration_path
    assert_equal I18n.t("auth.other_sessions_ended"), flash[:notice]
    assert_signed_in
    other.get user_plans_path, as: :json
    assert_equal 401, other.response.status
  end

  test "signing out of other devices needs a signed-in user" do
    delete other_sessions_path

    assert_redirected_to new_user_session_path
  end

  test "a blocked user is signed out on their next request" do
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    assert_signed_in

    @user.block!

    assert_signed_out
  end

  test "a blocked user cannot sign in and is told why" do
    @user.block!

    post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    assert_equal I18n.t("devise.failure.blocked"), flash[:alert]
    assert_signed_out
  end

  test "an account unconfirmed after three days cannot sign in" do
    travel 4.days do
      post user_session_path, params: { user: { email: @user.email, password: "password123" } }

      assert_equal I18n.t("devise.failure.unconfirmed"), flash[:alert]
      assert_signed_out
    end
  end

  # === Password change and reset ===

  test "changing the password on the account page signs other browsers out" do
    other = open_session
    other.post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    sign_in @user

    put user_registration_path, params: { user: { password: "new-password-1", password_confirmation: "new-password-1", current_password: "password123" } }

    assert_signed_in
    other.get user_plans_path, as: :json
    assert_equal 401, other.response.status
  end

  test "a password reset by email works once and ends every session" do
    other = open_session
    other.post user_session_path, params: { user: { email: @user.email, password: "password123" } }

    perform_enqueued_jobs do
      post user_password_path, params: { user: { email: @user.email } }
    end
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
    token = ActionMailer::Base.deliveries.last.text_part.body.to_s[/reset_password_token=([^\s&]+)/, 1]

    put user_password_path, params: { user: { reset_password_token: token, password: "brand-new-pass", password_confirmation: "brand-new-pass" } }

    assert @user.reload.valid_password?("brand-new-pass")
    other.get user_plans_path, as: :json
    assert_equal 401, other.response.status

    put user_password_path, params: { user: { reset_password_token: token, password: "third-password", password_confirmation: "third-password" } }
    assert_not @user.reload.valid_password?("third-password")
  end

  test "asking for a reset does not reveal whether an email has an account" do
    post user_password_path, params: { user: { email: "nobody@example.com" } }

    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
  end

  # === Rate limits ===

  test "the eleventh sign-in attempt in the window is refused" do
    with_real_cache do
      10.times { post user_session_path, params: { user: { email: @user.email, password: "wrong" } } }
      post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    end

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("auth.too_many_attempts"), flash[:alert]
    assert_signed_out
  end

  test "the sixth reset request in an hour is refused" do
    with_real_cache do
      5.times { post user_password_path, params: { user: { email: @user.email } } }
      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        post user_password_path, params: { user: { email: @user.email } }
      end
    end

    assert_equal I18n.t("auth.too_many_attempts"), flash[:alert]
  end

  private

  def with_real_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end
