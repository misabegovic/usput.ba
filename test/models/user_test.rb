# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @valid_params = {
      username: "testuser",
      email: "testuser@example.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  # === Validation tests ===

  test "valid user is saved" do
    user = User.new(@valid_params)
    assert user.save
    user.destroy
  end

  test "username is required" do
    user = User.new(@valid_params.merge(username: nil))
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "username must be unique" do
    User.create!(@valid_params)
    duplicate = User.new(@valid_params.merge(username: "testuser", email: "testuser@example.com"))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
    User.find_by(username: "testuser")&.destroy
  end

  test "username uniqueness is case-insensitive" do
    User.create!(@valid_params)
    duplicate = User.new(@valid_params.merge(username: "TESTUSER", email: "TESTUSER@example.com"))
    assert_not duplicate.valid?
    User.find_by(username: "testuser")&.destroy
  end

  test "username minimum length is 3" do
    user = User.new(@valid_params.merge(username: "ab", email: "ab@example.com"))
    assert_not user.valid?
    assert user.errors[:username].any? { |e| e.include?("short") || e.include?("minimum") }
  end

  test "username maximum length is 30" do
    user = User.new(@valid_params.merge(username: "a" * 31, email: "long@example.com"))
    assert_not user.valid?
    assert user.errors[:username].any? { |e| e.include?("long") || e.include?("maximum") }
  end

  test "username only allows alphanumeric and underscore" do
    invalid_usernames = [ "user@name", "user name", "user-name", "user.name" ]
    invalid_usernames.each do |username|
      user = User.new(@valid_params.merge(username: username, email: "#{username}@example.com"))
      assert_not user.valid?, "#{username} should be invalid"
    end
  end

  test "username allows underscores" do
    user = User.new(@valid_params.merge(username: "test_user_123", email: "test_user_123@example.com"))
    assert user.valid?
  end

  test "password minimum length is 6" do
    user = User.new(@valid_params.merge(password: "short", password_confirmation: "short"))
    assert_not user.valid?
    assert user.errors[:password].any? { |e| e.include?("short") || e.include?("minimum") }
  end

  test "password confirmation must match" do
    user = User.new(@valid_params.merge(password_confirmation: "different"))
    assert_not user.valid?
    assert user.errors[:password_confirmation].present?
  end

  # === UUID generation tests ===

  test "uuid is generated on create" do
    user = User.create!(@valid_params)
    assert user.uuid.present?
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, user.uuid)
    user.destroy
  end

  test "uuid is unique" do
    user1 = User.create!(@valid_params)
    user2 = User.create!(@valid_params.merge(username: "testuser2", email: "testuser2@example.com"))
    assert_not_equal user1.uuid, user2.uuid
    user1.destroy
    user2.destroy
  end

  # === User type tests ===

  test "default user type is basic" do
    user = User.create!(@valid_params)
    assert user.basic?
    user.destroy
  end

  test "can_curate? returns false for basic users" do
    user = User.create!(@valid_params)
    assert_not user.can_curate?
    user.destroy
  end

  test "can_curate? returns true for curators" do
    user = User.create!(@valid_params.merge(username: "curator_user", email: "curator_user@example.com", user_type: :curator))
    assert user.can_curate?
    user.destroy
  end

  test "can_curate? returns true for admins" do
    user = User.create!(@valid_params.merge(username: "admin_user", email: "admin_user@example.com", user_type: :admin))
    assert user.can_curate?
    user.destroy
  end

  test "admin? returns true only for admin users" do
    admin = User.create!(@valid_params.merge(username: "admin_test", email: "admin_test@example.com", user_type: :admin))
    curator = User.create!(@valid_params.merge(username: "curator_test", email: "curator_test@example.com", user_type: :curator))
    basic = User.create!(@valid_params.merge(username: "basic_test", email: "basic_test@example.com"))

    assert admin.admin?
    assert_not curator.admin?
    assert_not basic.admin?

    admin.destroy
    curator.destroy
    basic.destroy
  end

  # === Username normalization tests ===

  test "username is normalized to lowercase on save" do
    user = User.create!(@valid_params.merge(username: "MixedCase", email: "MixedCase@example.com"))
    assert_equal "mixedcase", user.username
    user.destroy
  end

  # === Travel profile tests ===

  test "travel_profile_data returns default structure when nil" do
    user = User.create!(@valid_params)
    profile = user.travel_profile_data

    assert profile["visited"].is_a?(Array)
    assert profile["favorites"].is_a?(Array)
    assert profile["badges"].is_a?(Array)
    assert profile["recentlyViewed"].is_a?(Array)
    assert profile["savedPlans"].is_a?(Array)

    user.destroy
  end

  # A visit is a check-in, not a client preference: the browser can claim
  # anything, so `visited` comes from PlanVisit and the payload is ignored.
  test "merge_travel_profile ignores visited sent by the client" do
    user = User.create!(@valid_params)

    user.merge_travel_profile({
      "visited" => [ { "id" => "loc1" } ],
      "favorites" => []
    })

    user.reload
    assert_empty user.travel_profile_data["visited"]

    user.destroy
  end

  test "travel_profile_data projects visited from plan visits" do
    user = User.create!(@valid_params)
    location = Location.create!(name: "Projected Fort", city: "Sarajevo", lat: 43.85, lng: 18.41)
    plan = Plan.create!(title: "Trip", visibility: :private_plan, user: user)
    user.plan_visits.create!(plan: plan, location: location)

    visited = user.reload.travel_profile_data["visited"]

    assert_equal 1, visited.length
    assert_equal location.uuid, visited.first["id"]
    assert_equal "Sarajevo", visited.first["city"]

    location.destroy
    user.destroy
  end

  test "travel_profile_data projects stats from plan visits" do
    user = User.create!(@valid_params)
    plan = Plan.create!(title: "Trip", visibility: :private_plan, user: user)
    mostar = Location.create!(name: "Stats Bridge", city: "Mostar", lat: 43.337, lng: 17.815)
    sarajevo = Location.create!(name: "Stats Tunnel", city: "Sarajevo", lat: 43.82, lng: 18.32)
    user.plan_visits.create!(plan: plan, location: mostar, created_at: Time.zone.local(2026, 1, 15))
    user.plan_visits.create!(plan: plan, location: sarajevo, created_at: Time.zone.local(2026, 7, 15))

    stats = user.reload.travel_profile_data["stats"]

    assert_equal 2, stats["totalVisits"]
    assert_equal %w[Mostar Sarajevo], stats["citiesVisited"].sort
    assert_equal %w[summer winter], stats["seasonsVisited"].sort

    mostar.destroy
    sarajevo.destroy
    user.destroy
  end

  # The counters are a function of the visits, exactly as `visited` is, so a
  # browser that never saw the last check-in cannot reverse it.
  test "merge_travel_profile ignores stats sent by the client" do
    user = User.create!(@valid_params)
    plan = Plan.create!(title: "Trip", visibility: :private_plan, user: user)
    location = Location.create!(name: "Stats Fort", city: "Jajce", lat: 44.34, lng: 17.27)
    user.plan_visits.create!(plan: plan, location: location)

    user.merge_travel_profile({
      "stats" => { "totalVisits" => 99, "citiesVisited" => [ "Paris" ], "seasonsVisited" => [] }
    })

    stats = user.reload.travel_profile_data["stats"]
    assert_equal 1, stats["totalVisits"]
    assert_equal [ "Jajce" ], stats["citiesVisited"]

    location.destroy
    user.destroy
  end

  test "travel_profile_data reflects a visit recorded after it was first read" do
    user = User.create!(@valid_params)
    plan = Plan.create!(title: "Trip", visibility: :private_plan, user: user)
    location = Location.create!(name: "Stats Mill", city: "Travnik", lat: 44.22, lng: 17.66)

    assert_equal 0, user.travel_profile_data["stats"]["totalVisits"]
    user.plan_visits.create!(plan: plan, location: location)

    assert_equal 1, user.reload.travel_profile_data["stats"]["totalVisits"]

    location.destroy
    user.destroy
  end

  test "travel_profile_data reads the visits in one pass" do
    user = User.create!(@valid_params)
    plan = Plan.create!(title: "Trip", visibility: :private_plan, user: user)
    location = Location.create!(name: "Stats Mosque", city: "Blagaj", lat: 43.25, lng: 17.89)
    user.plan_visits.create!(plan: plan, location: location)
    user.reload

    assert_queries_count(2) { user.travel_profile_data }

    location.destroy
    user.destroy
  end

  # An empty array is truthy in Ruby, so a browser holding no profile used to
  # arrive looking like an instruction to delete the account's favourites.
  test "merge_travel_profile treats an empty incoming favorites list as no opinion" do
    user = User.create!(@valid_params)
    user.merge_travel_profile({ "favorites" => [ { "id" => "loc1", "type" => "location" } ] })

    user.merge_travel_profile({ "favorites" => [] })

    assert_equal [ "loc1" ], user.reload.travel_profile_data["favorites"].map { |item| item["id"] }

    user.destroy
  end

  test "merge_travel_profile lets a newer client remove a favorite" do
    user = User.create!(@valid_params)
    user.merge_travel_profile({
      "favorites" => [ { "id" => "loc1" }, { "id" => "loc2" } ]
    })

    user.merge_travel_profile({
      "updatedAt" => 1.hour.from_now.utc.iso8601,
      "favorites" => [ { "id" => "loc2" } ]
    })

    assert_equal [ "loc2" ], user.reload.travel_profile_data["favorites"].map { |item| item["id"] }

    user.destroy
  end

  test "merge_travel_profile keeps stored favorites when the client copy is older" do
    user = User.create!(@valid_params)
    user.merge_travel_profile({ "favorites" => [ { "id" => "loc1" }, { "id" => "loc2" } ] })

    user.merge_travel_profile({
      "updatedAt" => 1.day.ago.utc.iso8601,
      "favorites" => [ { "id" => "loc3" } ]
    })

    assert_equal %w[loc1 loc2], user.reload.travel_profile_data["favorites"].map { |item| item["id"] }.sort

    user.destroy
  end

  test "merge_travel_profile does nothing with blank data" do
    user = User.create!(@valid_params)
    original_profile = user.travel_profile_data.dup

    user.merge_travel_profile(nil)
    user.merge_travel_profile({})

    # Should not have changed
    assert_equal original_profile["visited"], user.travel_profile_data["visited"]

    user.destroy
  end

  # === Curator application tests ===

  test "can_apply_for_curator? returns true for basic users without pending application" do
    user = User.create!(@valid_params)
    assert user.can_apply_for_curator?
    user.destroy
  end

  test "can_apply_for_curator? returns false for curators" do
    user = User.create!(@valid_params.merge(username: "curator_app_test", email: "curator_app_test@example.com", user_type: :curator))
    assert_not user.can_apply_for_curator?
    user.destroy
  end

  # === Spam protection tests ===

  test "spam_blocked? returns false when not blocked" do
    user = User.create!(@valid_params)
    assert_not user.spam_blocked?
    user.destroy
  end

  test "spam_blocked? returns true when blocked until future time" do
    user = User.create!(@valid_params)
    user.update!(spam_blocked_until: 1.hour.from_now)
    assert user.spam_blocked?
    user.destroy
  end

  test "spam_blocked? auto-clears expired block" do
    user = User.create!(@valid_params)
    user.update!(
      spam_blocked_until: 1.hour.ago,
      spam_blocked_at: 2.hours.ago
    )
    assert_not user.spam_blocked?
    user.reload
    assert_nil user.spam_blocked_until
    user.destroy
  end

  test "block_for_spam! sets block fields" do
    user = User.create!(@valid_params)
    user.block_for_spam!("Test reason")

    assert user.spam_blocked?
    assert user.spam_blocked_at.present?
    assert user.spam_blocked_until.present?
    assert_equal "Test reason", user.spam_block_reason

    user.destroy
  end

  test "clear_spam_block! removes block" do
    user = User.create!(@valid_params)
    user.block_for_spam!("Test")
    user.clear_spam_block!

    assert_not user.spam_blocked?
    assert_nil user.spam_blocked_at
    assert_nil user.spam_blocked_until

    user.destroy
  end

  # === Authentication tests ===

  test "valid_password? accepts the right password only" do
    user = User.create!(@valid_params)
    assert user.valid_password?("password123")
    assert_not user.valid_password?("wrongpassword")
  end

  test "email is required and stored lower-cased" do
    assert_not User.new(@valid_params.merge(email: "")).valid?
    user = User.create!(@valid_params.merge(email: "  Ime.Prezime@Example.TEST "))
    assert_equal "ime.prezime@example.test", user.email
  end

  test "email is unique regardless of case" do
    User.create!(@valid_params)
    duplicate = User.new(@valid_params.merge(username: "another", email: "TestUser@Example.com"))
    assert_not duplicate.valid?
    assert duplicate.errors[:email].present?
  end

  test "a new account can sign in for three days before confirming" do
    user = User.create!(@valid_params)
    assert user.active_for_authentication?

    travel 4.days do
      assert_not user.reload.active_for_authentication?
      assert_equal :unconfirmed, user.inactive_message
    end
  end

  test "a confirmed account keeps signing in" do
    user = User.create!(@valid_params)
    user.confirm
    travel 30.days do
      assert user.reload.active_for_authentication?
    end
  end

  test "a new account gets a session token" do
    assert User.create!(@valid_params).session_token.present?
  end

  test "ending sessions changes what Devise checks on each request" do
    user = User.create!(@valid_params)
    before = user.authenticatable_salt
    user.end_sessions
    assert_not_equal before, user.reload.authenticatable_salt
  end

  test "a new password changes what Devise checks on each request" do
    user = User.create!(@valid_params)
    before = user.authenticatable_salt
    user.update!(password: "another-password", password_confirmation: "another-password")
    assert_not_equal before, user.reload.authenticatable_salt
  end

  test "block! refuses sign-in and ends sessions" do
    user = User.create!(@valid_params)
    user.confirm
    before = user.authenticatable_salt

    user.block!

    assert user.blocked?
    assert_not user.active_for_authentication?
    assert_equal :blocked, user.inactive_message
    assert_not_equal before, user.authenticatable_salt
  end

  test "unblock! lets the user sign in again" do
    user = User.create!(@valid_params)
    user.confirm
    user.block!
    user.unblock!
    assert user.active_for_authentication?
  end

  test "Devise mail is sent from a job" do
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      User.create!(@valid_params)
    end
  end

  # === Association tests ===

  test "destroying user nullifies plans" do
    user = User.create!(@valid_params)
    plan = Plan.create!(
      title: "Test Plan",
      city_name: "Sarajevo",
      user: user
    )

    user.destroy

    plan.reload
    assert_nil plan.user_id

    plan.destroy
  end
end
