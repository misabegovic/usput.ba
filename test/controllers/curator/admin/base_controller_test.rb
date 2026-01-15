# frozen_string_literal: true

require "test_helper"

class Curator::Admin::BaseControllerTest < ActionDispatch::IntegrationTest
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
  end

  teardown do
    @admin&.destroy
    @curator&.destroy
    @basic_user&.destroy
  end

  # Test that admin routes require admin role
  test "admin routes require login" do
    get curator_admin_photo_suggestions_path
    assert_redirected_to login_path
  end

  test "admin routes require curator role first" do
    login_as(@basic_user)
    get curator_admin_photo_suggestions_path
    assert_redirected_to root_path
  end

  test "admin routes require admin role" do
    login_as(@curator)
    get curator_admin_photo_suggestions_path
    assert_redirected_to curator_root_path
  end

  test "admin routes accessible by admin users" do
    login_as(@admin)
    get curator_admin_photo_suggestions_path
    assert_response :success
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
