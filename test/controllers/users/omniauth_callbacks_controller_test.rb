# frozen_string_literal: true

require "test_helper"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  # === A new traveller ===

  test "a first Google sign-in creates a confirmed account and signs it in" do
    google(uid: "g-new", email: "Ana.Kovac@Example.com")

    assert_difference "User.count", 1 do
      sign_in_with_google
    end

    user = User.find_by(email: "ana.kovac@example.com")
    assert user.confirmed?
    assert_equal "ana_kovac", user.username
    assert_equal [ "g-new" ], user.identities.pluck(:uid)
    assert_redirected_to root_path
    assert_equal I18n.t("devise.omniauth_callbacks.success", kind: "Google"), flash[:notice]
    assert_signed_in
  end

  test "a taken username gets a number" do
    User.create!(username: "ana", email: "ana@elsewhere.example", password: "password123")
    google(uid: "g-ana", email: "ana@example.com")

    sign_in_with_google

    assert_equal "ana_2", User.find_by(email: "ana@example.com").username
  end

  test "a new Google account sends no confirmation email" do
    google(uid: "g-quiet", email: "quiet@example.com")

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      sign_in_with_google
    end
  end

  # === An existing traveller ===

  test "a verified Google email links to the account that already has it" do
    user = User.create!(username: "existing", email: "existing@example.com", password: "password123")
    google(uid: "g-existing", email: "existing@example.com")

    assert_no_difference "User.count" do
      sign_in_with_google
    end

    assert_equal [ "g-existing" ], user.identities.pluck(:uid)
    assert user.reload.confirmed?, "Google vouched for the address"
    assert_signed_in
  end

  test "a linked account signs in by its Google id even if the Google email changed" do
    user = User.create!(username: "moved", email: "old@example.com", password: "password123")
    user.identities.create!(provider: "google_oauth2", uid: "g-moved")
    google(uid: "g-moved", email: "new@example.com", verified: false)

    sign_in_with_google

    assert_signed_in
    assert_nil User.find_by(email: "new@example.com")
  end

  test "an account already linked to one Google account is not linked to a second" do
    user = User.create!(username: "twice", email: "twice@example.com", password: "password123")
    user.identities.create!(provider: "google_oauth2", uid: "g-first")
    google(uid: "g-second", email: "twice@example.com")

    sign_in_with_google

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("auth.google.refused"), flash[:alert]
    assert_equal [ "g-first" ], user.identities.pluck(:uid)
  end

  # === Refusals ===

  test "an email Google has not verified links to nothing" do
    User.create!(username: "target", email: "target@example.com", password: "password123")
    google(uid: "g-stranger", email: "target@example.com", verified: false)

    assert_no_difference [ "User.count", "Identity.count" ] do
      sign_in_with_google
    end

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("auth.google.refused"), flash[:alert]
    assert_signed_out
  end

  test "a blocked account cannot come in through Google" do
    user = User.create!(username: "blockedg", email: "blockedg@example.com", password: "password123")
    user.identities.create!(provider: "google_oauth2", uid: "g-blocked")
    user.block!
    google(uid: "g-blocked", email: "blockedg@example.com")

    sign_in_with_google

    assert_signed_out
  end

  test "a failure at Google sends the visitor back to sign in" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
    silence_omniauth_logger do
      post user_google_oauth2_omniauth_authorize_path
      follow_redirect!
    end

    assert_redirected_to new_user_session_path
    assert_signed_out
  end

  # === The guest door and the return path ===

  test "the guest's device data comes along through Google" do
    google(uid: "g-guest", email: "guest@example.com")
    profile = { "favorites" => [ { "id" => "fav-1", "type" => "location" } ] }.to_json

    with_real_cache do
      sign_in_with_google(travel_profile_data: profile)
    end

    favourites = User.find_by(email: "guest@example.com").travel_profile_data["favorites"]
    assert_equal [ "fav-1" ], favourites.map { |item| item["id"] }
  end

  test "the stash is spent once" do
    request = Struct.new(:params, :session).new({ "plans_data" => "[]" }, {})

    with_real_cache do
      GuestPayloadStash.store(request)
      assert_equal({ "plans_data" => "[]" }, GuestPayloadStash.take(request.session))
      assert_equal({}, GuestPayloadStash.take(request.session))
    end
  end

  test "Google sign-in returns the visitor to the page they came from" do
    google(uid: "g-return", email: "return@example.com")
    get new_user_session_path(return_to: profile_page_path)

    sign_in_with_google

    assert_redirected_to profile_page_path
  end

  # === The button ===

  test "the sign-in page offers Google when it is configured" do
    with_google_configured(true) { get new_user_session_path }

    assert_select "form[action='#{user_google_oauth2_omniauth_authorize_path}'] input[name='travel_profile_data']"
  end

  test "the sign-in page hides Google when it is not configured" do
    with_google_configured(false) { get new_user_session_path }

    assert_select "form[action='#{user_google_oauth2_omniauth_authorize_path}']", count: 0
  end

  private

  def google(uid:, email:, verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid,
      info: { email: email, email_verified: verified, name: "Test Traveller" }
    )
  end

  def sign_in_with_google(**params)
    post user_google_oauth2_omniauth_authorize_path, params: params
    follow_redirect!
  end

  def with_real_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end

  def with_google_configured(value)
    original = Rails.configuration.x.google_sign_in
    Rails.configuration.x.google_sign_in = value
    yield
  ensure
    Rails.configuration.x.google_sign_in = original
  end

  def silence_omniauth_logger
    original = OmniAuth.config.logger
    OmniAuth.config.logger = Logger.new(IO::NULL)
    yield
  ensure
    OmniAuth.config.logger = original
  end
end
