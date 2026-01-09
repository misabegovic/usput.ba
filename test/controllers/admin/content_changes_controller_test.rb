# frozen_string_literal: true

require "test_helper"

class Admin::ContentChangesControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["ADMIN_DASHBOARD"] = "true"
    ENV["ADMIN_USERNAME"] = "testadmin"
    ENV["ADMIN_PASSWORD"] = "testpass123"
    Flipper.enable(:admin_dashboard)

    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )
    @admin = User.create!(
      username: "test_admin_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @pending_change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "Test Location", "city" => "Sarajevo" }
    )
  end

  teardown do
    ENV["ADMIN_DASHBOARD"] = nil
    ENV["ADMIN_USERNAME"] = nil
    ENV["ADMIN_PASSWORD"] = nil
    Flipper.disable(:admin_dashboard)

    ContentChange.destroy_all
    @location&.destroy
    @curator&.destroy
    @admin&.destroy
  end

  test "index requires admin login" do
    get admin_content_changes_path
    assert_redirected_to admin_login_path
  end

  test "index shows all content changes when logged in" do
    login_as_admin
    get admin_content_changes_path
    assert_response :success
  end

  test "index filters by status" do
    login_as_admin
    get admin_content_changes_path(status: :pending)
    assert_response :success
  end

  test "show displays content change details" do
    login_as_admin
    get admin_content_change_path(@pending_change)
    assert_response :success
  end

  test "approve requires admin credentials" do
    login_as_admin
    post approve_admin_content_change_path(@pending_change)
    # HTML requests redirect with flash message instead of 403
    assert_redirected_to admin_root_path
  end

  test "approve with valid credentials approves the proposal" do
    login_as_admin

    assert_difference "Location.count", 1 do
      post approve_admin_content_change_path(@pending_change), params: {
        admin_username: "testadmin",
        admin_password: "testpass123"
      }
    end

    assert_redirected_to admin_content_changes_path
    @pending_change.reload
    assert @pending_change.approved?
  end

  test "approve with invalid credentials is rejected" do
    login_as_admin

    assert_no_difference "Location.count" do
      post approve_admin_content_change_path(@pending_change), params: {
        admin_username: "testadmin",
        admin_password: "wrongpassword"
      }
    end

    # HTML requests redirect with flash message instead of 403
    assert_redirected_to admin_root_path
  end

  test "reject requires admin credentials" do
    login_as_admin
    post reject_admin_content_change_path(@pending_change)
    # HTML requests redirect with flash message instead of 403
    assert_redirected_to admin_root_path
  end

  test "reject with valid credentials rejects the proposal" do
    login_as_admin

    post reject_admin_content_change_path(@pending_change), params: {
      admin_username: "testadmin",
      admin_password: "testpass123",
      admin_notes: "Not appropriate"
    }

    assert_redirected_to admin_content_changes_path
    @pending_change.reload
    assert @pending_change.rejected?
    assert_equal "Not appropriate", @pending_change.admin_notes
  end

  test "cannot approve already reviewed proposal" do
    @pending_change.reject!(@admin, notes: "Already rejected")
    login_as_admin

    post approve_admin_content_change_path(@pending_change), params: {
      admin_username: "testadmin",
      admin_password: "testpass123"
    }

    assert_redirected_to admin_content_changes_path
  end

  private

  def login_as_admin
    post admin_login_path, params: {
      username: "testadmin",
      password: "testpass123"
    }
  end
end
