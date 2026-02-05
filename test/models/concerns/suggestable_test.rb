# frozen_string_literal: true

require "test_helper"

# Test Suggestable concern through LocationSuggestion
# (concerns are tested through their including models)
class SuggestableTest < ActiveSupport::TestCase
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
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
  end

  teardown do
    LocationSuggestion.destroy_all
    Location.destroy_all
    User.destroy_all
  end

  test "includes status enum" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "Test"
    )

    assert suggestion.respond_to?(:status)
    assert suggestion.respond_to?(:pending?)
    assert suggestion.respond_to?(:approved?)
    assert suggestion.respond_to?(:rejected?)
  end

  test "includes change_type enum" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      change_type: :update_resource,
      proposed_name: "Test"
    )

    assert suggestion.respond_to?(:change_type)
    assert suggestion.respond_to?(:create_resource?)
    assert suggestion.respond_to?(:update_resource?)
    assert suggestion.respond_to?(:delete_resource?)
  end

  test "includes origin enum" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      origin: :human,
      proposed_name: "Test"
    )

    assert suggestion.respond_to?(:origin)
    assert suggestion.respond_to?(:origin_human?)
    assert suggestion.respond_to?(:origin_ai_generated?)
  end

  test "validates user presence" do
    suggestion = LocationSuggestion.new(
      location: @location,
      proposed_name: "Test"
    )

    assert_not suggestion.valid?
    assert_includes suggestion.errors[:user], "can't be blank"
  end

  test "approve! changes status and records reviewer" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      change_type: :update_resource,
      proposed_name: "Updated Name"
    )

    suggestion.approve!(@admin, notes: "Approved")

    assert suggestion.approved?
    assert_equal @admin, suggestion.reviewed_by
    assert_not_nil suggestion.reviewed_at
    assert_equal "Approved", suggestion.admin_notes
  end

  test "reject! changes status without applying changes" do
    original_name = @location.name
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "New Name"
    )

    suggestion.reject!(@admin, notes: "Rejected")

    assert suggestion.rejected?
    assert_equal @admin, suggestion.reviewed_by
    assert_not_nil suggestion.reviewed_at
    assert_equal "Rejected", suggestion.admin_notes

    @location.reload
    assert_equal original_name, @location.name
  end

  test "scopes work correctly" do
    pending = LocationSuggestion.create!(
      location: @location,
      user: @user,
      status: :pending,
      proposed_name: "Pending"
    )

    approved = LocationSuggestion.create!(
      location: Location.create!(name: "Another", city: "Mostar", lat: 43.3, lng: 17.8),
      user: @user,
      status: :approved,
      change_type: :update_resource,
      proposed_name: "Approved"
    )

    assert_includes LocationSuggestion.pending_review, pending
    assert_not_includes LocationSuggestion.pending_review, approved
  end

  test "proposed_changes returns only populated fields" do
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      proposed_name: "New Name",
      proposed_city: "Mostar"
    )

    changes = suggestion.proposed_changes
    assert changes.key?("proposed_name")
    assert changes.key?("proposed_city")
    assert_equal "New Name", changes["proposed_name"]
    assert_equal "Mostar", changes["proposed_city"]
  end

  test "applies changes via apply_changes! method" do
    # LocationSuggestion implements apply_changes!, so we test through it
    suggestion = LocationSuggestion.create!(
      location: @location,
      user: @user,
      change_type: :update_resource,
      proposed_name: "Updated Name"
    )

    # Should respond to apply_changes! (implemented by LocationSuggestion)
    assert suggestion.respond_to?(:apply_changes!, true)

    # approve! should call apply_changes!
    suggestion.approve!(@admin)
    @location.reload
    assert_equal "Updated Name", @location.name
  end
end
