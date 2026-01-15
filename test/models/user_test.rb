# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @valid_params = {
      username: "testuser",
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
    duplicate = User.new(@valid_params.merge(username: "testuser"))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
    User.find_by(username: "testuser")&.destroy
  end

  test "username uniqueness is case-insensitive" do
    User.create!(@valid_params)
    duplicate = User.new(@valid_params.merge(username: "TESTUSER"))
    assert_not duplicate.valid?
    User.find_by(username: "testuser")&.destroy
  end

  test "username minimum length is 3" do
    user = User.new(@valid_params.merge(username: "ab"))
    assert_not user.valid?
    assert user.errors[:username].any? { |e| e.include?("short") || e.include?("minimum") }
  end

  test "username maximum length is 30" do
    user = User.new(@valid_params.merge(username: "a" * 31))
    assert_not user.valid?
    assert user.errors[:username].any? { |e| e.include?("long") || e.include?("maximum") }
  end

  test "username only allows alphanumeric and underscore" do
    invalid_usernames = ["user@name", "user name", "user-name", "user.name"]
    invalid_usernames.each do |username|
      user = User.new(@valid_params.merge(username: username))
      assert_not user.valid?, "#{username} should be invalid"
    end
  end

  test "username allows underscores" do
    user = User.new(@valid_params.merge(username: "test_user_123"))
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
    user2 = User.create!(@valid_params.merge(username: "testuser2"))
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
    user = User.create!(@valid_params.merge(username: "curator_user", user_type: :curator))
    assert user.can_curate?
    user.destroy
  end

  test "can_curate? returns true for admins" do
    user = User.create!(@valid_params.merge(username: "admin_user", user_type: :admin))
    assert user.can_curate?
    user.destroy
  end

  test "admin? returns true only for admin users" do
    admin = User.create!(@valid_params.merge(username: "admin_test", user_type: :admin))
    curator = User.create!(@valid_params.merge(username: "curator_test", user_type: :curator))
    basic = User.create!(@valid_params.merge(username: "basic_test"))

    assert admin.admin?
    assert_not curator.admin?
    assert_not basic.admin?

    admin.destroy
    curator.destroy
    basic.destroy
  end

  # === Username normalization tests ===

  test "username is normalized to lowercase on save" do
    user = User.create!(@valid_params.merge(username: "MixedCase"))
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

  test "merge_travel_profile merges visited items" do
    user = User.create!(@valid_params)

    user.merge_travel_profile({
      "visited" => [{ "id" => "loc1" }],
      "favorites" => []
    })

    user.reload
    assert_equal 1, user.travel_profile_data["visited"].length
    assert_equal "loc1", user.travel_profile_data["visited"].first["id"]

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
    user = User.create!(@valid_params.merge(username: "curator_app_test", user_type: :curator))
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

  test "authenticate succeeds with correct password" do
    user = User.create!(@valid_params)
    assert user.authenticate("password123")
    user.destroy
  end

  test "authenticate fails with wrong password" do
    user = User.create!(@valid_params)
    assert_not user.authenticate("wrongpassword")
    user.destroy
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
