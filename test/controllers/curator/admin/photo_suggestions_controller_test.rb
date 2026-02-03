# frozen_string_literal: true

require "test_helper"

class Curator::Admin::PhotoSuggestionsControllerTest < ActionDispatch::IntegrationTest
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
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @suggestion = PhotoSuggestion.new(
      user: @curator,
      location: @location,
      description: "A nice photo"
    )
    @suggestion.photos.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.jpg")),
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
    @suggestion.save!
  end

  teardown do
    PhotoSuggestion.destroy_all
    @location&.destroy
    @admin&.destroy
    @curator&.destroy
  end

  # Index tests
  test "index requires admin" do
    login_as(@curator)
    get curator_admin_photo_suggestions_path
    assert_redirected_to curator_root_path
  end

  test "index shows all photo suggestions" do
    login_as(@admin)
    get curator_admin_photo_suggestions_path
    assert_response :success
  end

  test "index filters by status" do
    login_as(@admin)
    get curator_admin_photo_suggestions_path(status: "pending")
    assert_response :success
  end

  # Show tests
  test "show displays suggestion details" do
    login_as(@admin)
    get curator_admin_photo_suggestion_path(@suggestion)
    assert_response :success
  end

  # Approve tests
  test "approve requires admin" do
    login_as(@curator)
    post approve_curator_admin_photo_suggestion_path(@suggestion)
    assert_redirected_to curator_root_path
  end

  test "approve approves pending suggestion" do
    login_as(@admin)
    post approve_curator_admin_photo_suggestion_path(@suggestion)
    assert_redirected_to curator_admin_photo_suggestions_path

    @suggestion.reload
    assert @suggestion.approved?
    assert_equal @admin, @suggestion.reviewed_by
  end

  test "approve records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      post approve_curator_admin_photo_suggestion_path(@suggestion)
    end

    activity = CuratorActivity.last
    assert_equal "approve_photo_suggestion", activity.action
    assert_equal @admin, activity.user
  end

  test "approve fails for already reviewed suggestion" do
    @suggestion.update!(status: :approved, reviewed_by: @admin, reviewed_at: Time.current)

    login_as(@admin)
    post approve_curator_admin_photo_suggestion_path(@suggestion)
    assert_redirected_to curator_admin_photo_suggestions_path
    assert_match /already.*reviewed/i, flash[:alert]
  end

  test "approve shows error when approval fails" do
    login_as(@admin)

    # Create a mock that returns false for approve!
    mock_suggestion = @suggestion
    mock_suggestion.define_singleton_method(:approve!) { |*_args, **_kwargs| false }

    PhotoSuggestion.stub(:find, ->(_id) { mock_suggestion }) do
      post approve_curator_admin_photo_suggestion_path(@suggestion)
    end

    assert_redirected_to curator_admin_photo_suggestion_path(@suggestion)
    assert_match /failed/i, flash[:alert]
  end

  # Reject tests
  test "reject requires admin" do
    login_as(@curator)
    post reject_curator_admin_photo_suggestion_path(@suggestion)
    assert_redirected_to curator_root_path
  end

  test "reject rejects pending suggestion" do
    login_as(@admin)
    post reject_curator_admin_photo_suggestion_path(@suggestion), params: { admin_notes: "Not appropriate" }
    assert_redirected_to curator_admin_photo_suggestions_path

    @suggestion.reload
    assert @suggestion.rejected?
    assert_equal @admin, @suggestion.reviewed_by
    assert_equal "Not appropriate", @suggestion.admin_notes
  end

  test "reject records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      post reject_curator_admin_photo_suggestion_path(@suggestion)
    end

    activity = CuratorActivity.last
    assert_equal "reject_photo_suggestion", activity.action
  end

  test "reject fails for already reviewed suggestion" do
    @suggestion.update!(status: :rejected, reviewed_by: @admin, reviewed_at: Time.current)

    login_as(@admin)
    post reject_curator_admin_photo_suggestion_path(@suggestion)
    assert_redirected_to curator_admin_photo_suggestions_path
    assert_match /already.*reviewed/i, flash[:alert]
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
