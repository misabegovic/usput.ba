# frozen_string_literal: true

require "test_helper"

class Curator::PhotoSuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @curator = User.create!(
      username: "test_curator_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )
    @other_curator = User.create!(
      username: "other_curator_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )
    @basic_user = User.create!(
      username: "basic_user_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :basic
    )
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @suggestion = PhotoSuggestion.create!(
      user: @curator,
      location: @location,
      photo_url: "https://example.com/photo.jpg",
      description: "A nice photo"
    )
  end

  teardown do
    PhotoSuggestion.destroy_all
    @location&.destroy
    @curator&.destroy
    @other_curator&.destroy
    @basic_user&.destroy
  end

  # Authentication tests
  test "index requires login" do
    get curator_photo_suggestions_path
    assert_redirected_to login_path
  end

  test "index requires curator role" do
    login_as(@basic_user)
    get curator_photo_suggestions_path
    assert_redirected_to root_path
  end

  test "index shows curator's photo suggestions" do
    login_as(@curator)
    get curator_photo_suggestions_path
    assert_response :success
    assert_select "h1", text: /Photo Suggestions|Moji prijedlozi/i
  end

  test "index only shows current curator's suggestions" do
    # Create a suggestion for another curator
    other_suggestion = PhotoSuggestion.create!(
      user: @other_curator,
      location: @location,
      photo_url: "https://example.com/other.jpg"
    )

    login_as(@curator)
    get curator_photo_suggestions_path
    assert_response :success

    # Should see own suggestion
    assert_match @suggestion.photo_url, response.body
    # Should not see other curator's suggestion
    assert_no_match other_suggestion.photo_url, response.body

    other_suggestion.destroy
  end

  # New action tests
  test "new requires login" do
    get new_curator_location_photo_suggestion_path(@location)
    assert_redirected_to login_path
  end

  test "new shows form" do
    login_as(@curator)
    get new_curator_location_photo_suggestion_path(@location)
    assert_response :success
  end

  # Create action tests
  test "create requires login" do
    post curator_location_photo_suggestions_path(@location), params: {
      photo_suggestion: { photo_url: "https://example.com/new.jpg" }
    }
    assert_redirected_to login_path
  end

  test "create with valid photo_url creates suggestion" do
    login_as(@curator)

    assert_difference "PhotoSuggestion.count", 1 do
      post curator_location_photo_suggestions_path(@location), params: {
        photo_suggestion: {
          photo_url: "https://example.com/new.jpg",
          description: "New photo"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)
    assert_equal "pending", PhotoSuggestion.last.status
    assert_equal @curator, PhotoSuggestion.last.user
    assert_equal @location, PhotoSuggestion.last.location
  end

  test "create with attached photo creates suggestion" do
    login_as(@curator)

    assert_difference "PhotoSuggestion.count", 1 do
      post curator_location_photo_suggestions_path(@location), params: {
        photo_suggestion: {
          photo: fixture_file_upload("test/fixtures/files/test_image.jpg", "image/jpeg"),
          description: "Uploaded photo"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)
    assert PhotoSuggestion.last.photo.attached?
  end

  test "create without photo or url fails" do
    login_as(@curator)

    assert_no_difference "PhotoSuggestion.count" do
      post curator_location_photo_suggestions_path(@location), params: {
        photo_suggestion: {
          description: "No photo provided"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      post curator_location_photo_suggestions_path(@location), params: {
        photo_suggestion: {
          photo_url: "https://example.com/activity.jpg"
        }
      }
    end

    activity = CuratorActivity.last
    assert_equal "photo_suggested", activity.action
    assert_equal @curator, activity.user
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
