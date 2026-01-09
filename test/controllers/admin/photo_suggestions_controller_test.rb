# frozen_string_literal: true

require "test_helper"

class Admin::PhotoSuggestionsControllerTest < ActionDispatch::IntegrationTest
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
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @pending_suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg",
      description: "A nice photo"
    )
  end

  teardown do
    ENV["ADMIN_DASHBOARD"] = nil
    ENV["ADMIN_USERNAME"] = nil
    ENV["ADMIN_PASSWORD"] = nil
    Flipper.disable(:admin_dashboard)

    PhotoSuggestion.destroy_all
    @location&.destroy
    @curator&.destroy
  end

  test "index requires admin login" do
    get admin_photo_suggestions_path
    assert_redirected_to admin_login_path
  end

  test "index shows all photo suggestions when logged in" do
    login_as_admin
    get admin_photo_suggestions_path
    assert_response :success
  end

  test "index filters by status" do
    login_as_admin
    get admin_photo_suggestions_path(status: :pending)
    assert_response :success
  end

  test "show displays photo suggestion details" do
    login_as_admin
    get admin_photo_suggestion_path(@pending_suggestion)
    assert_response :success
  end

  test "approve requires admin credentials" do
    login_as_admin
    post approve_admin_photo_suggestion_path(@pending_suggestion)
    # HTML requests redirect with flash message instead of 403
    assert_redirected_to admin_root_path
  end

  test "approve with valid credentials approves the suggestion with attached photo" do
    # Create a suggestion with an attached photo (not URL) since URL download won't work in tests
    suggestion_with_photo = PhotoSuggestion.new(
      user: @curator,
      location: @location,
      description: "A nice photo"
    )
    suggestion_with_photo.photo.attach(
      io: StringIO.new("fake image data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )
    suggestion_with_photo.save!

    login_as_admin

    post approve_admin_photo_suggestion_path(suggestion_with_photo), params: {
      admin_username: "testadmin",
      admin_password: "testpass123",
      admin_notes: "Great photo!"
    }

    assert_redirected_to admin_photo_suggestions_path
    suggestion_with_photo.reload
    assert suggestion_with_photo.approved?
    assert_equal "Great photo!", suggestion_with_photo.admin_notes
  end

  test "approve with invalid credentials is rejected" do
    login_as_admin

    post approve_admin_photo_suggestion_path(@pending_suggestion), params: {
      admin_username: "testadmin",
      admin_password: "wrongpassword"
    }

    # HTML requests redirect with flash message instead of 403
    assert_redirected_to admin_root_path
    @pending_suggestion.reload
    assert @pending_suggestion.pending?
  end

  test "reject requires admin credentials" do
    login_as_admin
    post reject_admin_photo_suggestion_path(@pending_suggestion)
    # HTML requests redirect with flash message instead of 403
    assert_redirected_to admin_root_path
  end

  test "reject with valid credentials rejects the suggestion" do
    login_as_admin

    post reject_admin_photo_suggestion_path(@pending_suggestion), params: {
      admin_username: "testadmin",
      admin_password: "testpass123",
      admin_notes: "Low quality"
    }

    assert_redirected_to admin_photo_suggestions_path
    @pending_suggestion.reload
    assert @pending_suggestion.rejected?
    assert_equal "Low quality", @pending_suggestion.admin_notes
  end

  test "cannot approve already reviewed suggestion" do
    admin_user = User.first || @curator
    @pending_suggestion.reject!(admin_user, notes: "Already rejected")
    login_as_admin

    post approve_admin_photo_suggestion_path(@pending_suggestion), params: {
      admin_username: "testadmin",
      admin_password: "testpass123"
    }

    assert_redirected_to admin_photo_suggestions_path
    @pending_suggestion.reload
    assert @pending_suggestion.rejected? # Still rejected
  end

  private

  def login_as_admin
    post admin_login_path, params: {
      username: "testadmin",
      password: "testpass123"
    }
  end
end
