# frozen_string_literal: true

require "test_helper"

class Curator::LocationSuggestionsControllerTest < ActionDispatch::IntegrationTest
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
  end

  teardown do
    LocationSuggestion.destroy_all
    @location&.destroy
    @curator&.destroy
    @other_curator&.destroy
    @basic_user&.destroy
  end

  # Authentication tests
  test "new requires login" do
    get new_curator_location_location_suggestion_path(@location)
    assert_redirected_to login_path
  end

  test "new requires curator role" do
    login_as(@basic_user)
    get new_curator_location_location_suggestion_path(@location)
    assert_redirected_to root_path
  end

  # New action tests
  test "new creates pending suggestion and redirects to edit" do
    login_as(@curator)

    assert_difference "LocationSuggestion.count", 1 do
      get new_curator_location_location_suggestion_path(@location)
    end

    suggestion = LocationSuggestion.last
    assert_redirected_to edit_curator_location_location_suggestion_path(@location, suggestion)
    assert_equal @curator, suggestion.user
    assert_equal @location, suggestion.location
    assert_equal "pending", suggestion.status
    assert_equal "update_resource", suggestion.change_type
    assert_equal "human", suggestion.origin
  end

  test "new finds existing pending suggestion instead of creating new one" do
    login_as(@curator)

    # Create existing suggestion
    existing = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    assert_no_difference "LocationSuggestion.count" do
      get new_curator_location_location_suggestion_path(@location)
    end

    assert_redirected_to edit_curator_location_location_suggestion_path(@location, existing)
  end

  # Edit action tests
  test "edit requires login" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    get edit_curator_location_location_suggestion_path(@location, suggestion)
    assert_redirected_to login_path
  end

  # Note: Skipping edit shows form test since views are created separately

  # Create action tests
  test "create requires login" do
    post curator_location_location_suggestions_path(@location), params: {
      location_suggestion: { proposed_name: "New Name" }
    }
    assert_redirected_to login_path
  end

  test "create by original creator updates suggestion directly" do
    login_as(@curator)

    # Create pending suggestion
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    post curator_location_location_suggestions_path(@location), params: {
      location_suggestion: {
        proposed_name: "Updated Name",
        proposed_description: "Updated description"
      }
    }

    assert_redirected_to curator_location_path(@location)
    assert_match "Prijedlog uspješno kreiran", flash[:notice]

    suggestion.reload
    assert_equal "Updated Name", suggestion.proposed_name
    assert_equal "Updated description", suggestion.proposed_description
  end

  test "create by different curator adds contribution" do
    login_as(@curator)

    # Create pending suggestion by first curator
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_name: "Original Name"
    )

    # Other curator adds contribution
    login_as(@other_curator)

    assert_difference "LocationSuggestionContribution.count", 1 do
      post curator_location_location_suggestions_path(@location), params: {
        location_suggestion: {
          proposed_name: "Contributed Name",
          contribution_notes: "I suggest this name instead"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)
    assert_match "Doprinos prijedlogu uspješno dodan", flash[:notice]

    suggestion.reload
    assert_equal "Contributed Name", suggestion.proposed_name
  end

  test "create records curator activity for original creator" do
    login_as(@curator)

    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    assert_difference "CuratorActivity.count", 1 do
      post curator_location_location_suggestions_path(@location), params: {
        location_suggestion: { proposed_name: "Activity Test" }
      }
    end

    activity = CuratorActivity.last
    assert_equal "suggestion_created", activity.action
    assert_equal @curator, activity.user
    assert_equal suggestion, activity.recordable
  end

  test "create records curator activity for contributor" do
    login_as(@curator)

    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    login_as(@other_curator)

    assert_difference "CuratorActivity.count", 1 do
      post curator_location_location_suggestions_path(@location), params: {
        location_suggestion: {
          proposed_name: "Contribution",
          contribution_notes: "Note"
        }
      }
    end

    activity = CuratorActivity.last
    assert_equal "suggestion_contributed", activity.action
    assert_equal @other_curator, activity.user
  end

  # Update action tests
  test "update requires login" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    patch curator_location_location_suggestion_path(@location, suggestion), params: {
      location_suggestion: { proposed_name: "New Name" }
    }
    assert_redirected_to login_path
  end

  test "update by original creator updates suggestion directly" do
    login_as(@curator)

    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_name: "Original"
    )

    patch curator_location_location_suggestion_path(@location, suggestion), params: {
      location_suggestion: {
        proposed_name: "Updated via PATCH",
        proposed_city: "Mostar"
      }
    }

    assert_redirected_to curator_location_path(@location)
    assert_match "Prijedlog ažuriran", flash[:notice]

    suggestion.reload
    assert_equal "Updated via PATCH", suggestion.proposed_name
    assert_equal "Mostar", suggestion.proposed_city
  end

  test "update by different curator adds contribution" do
    login_as(@curator)

    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_name: "Original"
    )

    login_as(@other_curator)

    assert_difference "LocationSuggestionContribution.count", 1 do
      patch curator_location_location_suggestion_path(@location, suggestion), params: {
        location_suggestion: {
          proposed_name: "Contributed via PATCH",
          contribution_notes: "Better name"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)
    assert_match "Doprinos prijedlogu uspješno dodan", flash[:notice]

    suggestion.reload
    assert_equal "Contributed via PATCH", suggestion.proposed_name
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
