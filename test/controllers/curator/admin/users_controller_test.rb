# frozen_string_literal: true

require "test_helper"

class Curator::Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      username: "test_admin_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :admin
    )
    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )
    @basic_user = User.create!(
      username: "basic_user_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :basic
    )
    @blocked_user = User.create!(
      username: "blocked_user_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator,
      spam_blocked_at: Time.current,
      spam_blocked_until: 24.hours.from_now,
      spam_block_reason: "Too many requests"
    )
  end

  teardown do
    @admin&.destroy
    @curator&.destroy
    @basic_user&.destroy
    @blocked_user&.destroy
  end

  # Index tests
  test "index requires admin" do
    login_as(@curator)
    get curator_admin_users_path
    assert_redirected_to curator_root_path
  end

  test "index shows all users" do
    login_as(@admin)
    get curator_admin_users_path
    assert_response :success
  end

  test "index filters by user type" do
    login_as(@admin)
    get curator_admin_users_path(user_type: "curator")
    assert_response :success
  end

  test "index filters by blocked status" do
    login_as(@admin)
    get curator_admin_users_path(blocked: "true")
    assert_response :success
  end

  test "index ignores invalid user_type and returns all users" do
    login_as(@admin)
    # This should not crash with ArgumentError
    get curator_admin_users_path(user_type: "invalid_type")
    assert_response :success
  end

  # Show tests
  test "show displays user details" do
    login_as(@admin)
    get curator_admin_user_path(@curator)
    assert_response :success
  end

  # Edit tests
  test "edit requires admin" do
    login_as(@curator)
    get edit_curator_admin_user_path(@basic_user)
    assert_redirected_to curator_root_path
  end

  test "edit shows form" do
    login_as(@admin)
    get edit_curator_admin_user_path(@basic_user)
    assert_response :success
  end

  # Update tests
  test "update requires admin" do
    login_as(@curator)
    patch curator_admin_user_path(@basic_user), params: { user: { user_type: "curator" } }
    assert_redirected_to curator_root_path
  end

  test "update changes user type" do
    login_as(@admin)
    patch curator_admin_user_path(@basic_user), params: { user: { user_type: "curator" } }
    assert_redirected_to curator_admin_user_path(@basic_user)

    @basic_user.reload
    assert @basic_user.curator?
  end

  test "update records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      patch curator_admin_user_path(@basic_user), params: { user: { user_type: "curator" } }
    end

    activity = CuratorActivity.last
    assert_equal "update_user", activity.action
    assert_equal @admin, activity.user
  end

  # Unblock tests
  test "unblock requires admin" do
    login_as(@curator)
    post unblock_curator_admin_user_path(@blocked_user)
    assert_redirected_to curator_root_path
  end

  test "unblock unblocks blocked user" do
    login_as(@admin)
    post unblock_curator_admin_user_path(@blocked_user)
    assert_redirected_to curator_admin_user_path(@blocked_user)

    @blocked_user.reload
    assert_not @blocked_user.spam_blocked?
  end

  test "unblock records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      post unblock_curator_admin_user_path(@blocked_user)
    end

    activity = CuratorActivity.last
    assert_equal "unblock_user", activity.action
  end

  test "unblock fails for non-blocked user" do
    login_as(@admin)
    post unblock_curator_admin_user_path(@basic_user)
    assert_redirected_to curator_admin_user_path(@basic_user)
    assert_match /not blocked/i, flash[:alert]
  end


  # Show curator activities
  test "show displays curator activities for curators" do
    CuratorActivity.create!(
      user: @curator,
      action: "login",
      recordable: @curator
    )

    login_as(@admin)
    get curator_admin_user_path(@curator)
    assert_response :success
  end

  test "show does not load activities for non-curator users" do
    login_as(@admin)
    get curator_admin_user_path(@basic_user)
    assert_response :success
  end

  test "update renders edit when update fails" do
    login_as(@admin)

    # Create a mock that returns false for update
    mock_user = @basic_user
    mock_user.define_singleton_method(:update) { |*_args, **_kwargs| false }

    User.stub(:find_by_public_id!, ->(_id) { mock_user }) do
      patch curator_admin_user_path(@basic_user), params: { user: { user_type: "curator" } }
    end

    assert_response :unprocessable_entity
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
