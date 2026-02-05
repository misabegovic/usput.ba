# frozen_string_literal: true

require "test_helper"

class LocationSuggestionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      username: "test_curator",
      password: "password123",
      user_type: :curator
    )
    @admin = User.create!(
      username: "test_admin",
      password: "password123",
      user_type: :admin
    )
    @curator_two = User.create!(
      username: "test_curator_two",
      password: "password123",
      user_type: :curator
    )
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
    @location_two = Location.create!(
      name: "Test Location Two",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    )
  end

  teardown do
    LocationSuggestion.destroy_all
    LocationSuggestionContribution.destroy_all
    Location.destroy_all
    User.destroy_all
  end

  # Basic creation and validation
  test "creates location suggestion with valid attributes" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_name: "Updated Name"
    )

    assert suggestion.persisted?
    assert_equal "Updated Name", suggestion.proposed_name
    assert suggestion.origin_human?
  end

  test "requires user" do
    suggestion = LocationSuggestion.new(location: @location)
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:user], "can't be blank"
  end

  test "allows nil location for create_resource" do
    suggestion = LocationSuggestion.create!(
      location: nil,
      user: @user,
      status: :pending,
      change_type: :create_resource,
      origin: :human,
      proposed_name: "New Location"
    )

    assert suggestion.persisted?
    assert_nil suggestion.location
  end

  # Status transitions
  test "pending is default status" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "Test"
    )
    assert suggestion.pending?
  end

  test "changes status to approved" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      change_type: :update_resource,
      proposed_name: "Updated Name"
    )

    suggestion.approve!(@admin, notes: "Looks good")

    assert suggestion.approved?
    assert_equal @admin, suggestion.reviewed_by
    assert_not_nil suggestion.reviewed_at
    assert_equal "Looks good", suggestion.admin_notes
  end

  test "changes status to rejected" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "Bad Name"
    )

    suggestion.reject!(@admin, notes: "Not accurate")

    assert suggestion.rejected?
    assert_equal @admin, suggestion.reviewed_by
    assert_not_nil suggestion.reviewed_at
    assert_equal "Not accurate", suggestion.admin_notes
  end

  # Apply changes
  test "approve applies changes to existing location" do
    original_name = @location.name
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      change_type: :update_resource,
      proposed_name: "New Name",
      proposed_city: "Mostar"
    )

    suggestion.approve!(@admin)

    @location.reload
    assert_equal "New Name", @location.name
    assert_equal "Mostar", @location.city
  end

  test "approve creates new location for create_resource" do
    suggestion = LocationSuggestion.create!(
      location: nil,
      user: @user,
      change_type: :create_resource,
      proposed_name: "Brand New Location",
      proposed_city: "Sarajevo",
      proposed_lat: 43.8564,
      proposed_lng: 18.4131
    )

    assert_difference "Location.count", 1 do
      suggestion.approve!(@admin)
    end

    suggestion.reload
    assert_not_nil suggestion.location
    assert_equal "Brand New Location", suggestion.location.name
    assert_equal "Sarajevo", suggestion.location.city
  end

  test "reject does not change location" do
    original_name = @location.name
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "New Name"
    )

    suggestion.reject!(@admin)

    @location.reload
    assert_equal original_name, @location.name
  end

  # Multi-curator contributions
  test "add_contribution from another user" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "Name from A",
      proposed_city: "Mostar"
    )

    suggestion.add_contribution(
      user: @curator_two,
      notes: "Improved description",
      proposed_description: "Better description",
      proposed_city: "Updated City"
    )

    suggestion.reload
    assert_equal "Better description", suggestion.proposed_description
    assert_equal "Updated City", suggestion.proposed_city
    assert_equal 1, suggestion.contributions.count

    contribution = suggestion.contributions.first
    assert_equal @curator_two, contribution.user
    assert_equal "Improved description", contribution.notes
    assert_equal "Better description", contribution.proposed_description
  end

  # Unique constraint
  test "enforces one pending suggestion per location" do
    LocationSuggestion.create!(
      location: @location,
      user: @user,
      status: :pending,
      proposed_name: "First"
    )

    assert_raises ActiveRecord::RecordNotUnique do
      LocationSuggestion.create!(
        location: @location,
        user: @curator_two,
        status: :pending,
        proposed_name: "Second"
      )
    end
  end

  test "allows multiple approved suggestions for same location" do
    LocationSuggestion.create!(
      location: @location,
      user: @user,
      status: :approved,
      change_type: :update_resource,
      proposed_name: "First"
    )

    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @curator_two,
      status: :approved,
      change_type: :update_resource,
      proposed_name: "Second"
    )

    assert suggestion.persisted?
  end

  # find_or_create_pending!
  test "find_or_create_pending! returns existing pending suggestion" do
    existing = LocationSuggestion.create!(
      location: @location,
      user: @user,
      status: :pending,
      proposed_name: "Existing"
    )

    found = LocationSuggestion.find_or_create_pending!(
      @location,
      user: @curator_two,
      proposed_name: "Should not create"
    )

    assert_equal existing.id, found.id
  end

  test "find_or_create_pending! creates new suggestion if none pending" do
    suggestion = LocationSuggestion.find_or_create_pending!(
      @location,
      user: @user,
      proposed_name: "New"
    )

    assert suggestion.persisted?
    assert suggestion.pending?
    assert_equal "New", suggestion.proposed_name
  end

  # Photo validation
  # Note: Full Active Storage validation tests would require actual file fixtures
  # These tests verify the validation methods exist and basic structure
  test "has acceptable_photos validation method" do
    suggestion = LocationSuggestion.new(
      location: @location,
      user: @user,
      proposed_name: "Test"
    )
    assert suggestion.respond_to?(:acceptable_photos, true)
  end

  test "has proposed_photos attachment" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "Test"
    )
    assert suggestion.respond_to?(:proposed_photos)
  end

  # proposed_changes
  test "proposed_changes returns non-nil proposed fields" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "New Name",
      proposed_city: "Mostar",
      proposed_description: nil
    )

    changes = suggestion.proposed_changes
    assert_includes changes.keys, "proposed_name"
    assert_includes changes.keys, "proposed_city"
    assert_not_includes changes.keys, "proposed_description"
  end

  # Origin enum
  test "origin defaults to human" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "Test"
    )
    assert suggestion.origin_human?
  end

  test "origin can be ai_generated" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      origin: :ai_generated,
      ai_service: "location_enricher",
      proposed_name: "AI Generated"
    )
    assert suggestion.origin_ai_generated?
    assert_equal "location_enricher", suggestion.ai_service
  end

  # Scopes
  test "pending_review scope" do
    pending = LocationSuggestion.create!(
      location: @location,
      user: @user,
      status: :pending,
      proposed_name: "Pending"
    )
    approved = LocationSuggestion.create!(
      location: @location_two,
      user: @user,
      status: :approved,
      change_type: :update_resource,
      proposed_name: "Approved"
    )

    results = LocationSuggestion.pending_review
    assert_includes results, pending
    assert_not_includes results, approved
  end

  test "human_suggestions scope" do
    human = LocationSuggestion.create!(
      location: @location,
      user: @user,
      origin: :human,
      proposed_name: "Human"
    )
    ai = LocationSuggestion.create!(
      location: @location_two,
      user: @user,
      origin: :ai_generated,
      ai_service: "test",
      proposed_name: "AI"
    )

    results = LocationSuggestion.human_suggestions
    assert_includes results, human
    assert_not_includes results, ai
  end

  test "ai_suggestions scope" do
    human = LocationSuggestion.create!(
      location: @location,
      user: @user,
      origin: :human,
      proposed_name: "Human"
    )
    ai = LocationSuggestion.create!(
      location: @location_two,
      user: @user,
      origin: :ai_generated,
      ai_service: "test",
      proposed_name: "AI"
    )

    results = LocationSuggestion.ai_suggestions
    assert_not_includes results, human
    assert_includes results, ai
  end
end
