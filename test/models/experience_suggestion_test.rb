# frozen_string_literal: true

require "test_helper"

class ExperienceSuggestionTest < ActiveSupport::TestCase
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
    @category = ExperienceCategory.create!(
      key: "adventure",
      name: "Adventure"
    )
    @experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 120
    )
    @experience_two = Experience.create!(
      title: "Test Experience Two",
      estimated_duration: 60
    )
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
  end

  teardown do
    ExperienceSuggestion.destroy_all
    ExperienceSuggestionContribution.destroy_all
    Experience.destroy_all
    ExperienceCategory.destroy_all
    Location.destroy_all
    User.destroy_all
  end

  # Basic creation and validation
  test "creates experience suggestion with valid attributes" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_title: "Updated Title"
    )

    assert suggestion.persisted?
    assert_equal "Updated Title", suggestion.proposed_title
    assert suggestion.origin_human?
  end

  test "requires user" do
    suggestion = ExperienceSuggestion.new(experience: @experience)
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:user], "can't be blank"
  end

  test "allows nil experience for create_resource" do
    suggestion = ExperienceSuggestion.create!(
      experience: nil,
      user: @user,
      status: :pending,
      change_type: :create_resource,
      origin: :human,
      proposed_title: "New Experience"
    )

    assert suggestion.persisted?
    assert_nil suggestion.experience
  end

  # Status transitions
  test "pending is default status" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      proposed_title: "Test"
    )
    assert suggestion.pending?
  end

  test "changes status to approved" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      change_type: :update_resource,
      proposed_title: "Updated Title"
    )

    suggestion.approve!(@admin, notes: "Looks good")

    assert suggestion.approved?
    assert_equal @admin, suggestion.reviewed_by
    assert_not_nil suggestion.reviewed_at
    assert_equal "Looks good", suggestion.admin_notes
  end

  test "changes status to rejected" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      proposed_title: "Bad Title"
    )

    suggestion.reject!(@admin, notes: "Not accurate")

    assert suggestion.rejected?
    assert_equal @admin, suggestion.reviewed_by
    assert_not_nil suggestion.reviewed_at
    assert_equal "Not accurate", suggestion.admin_notes
  end

  # Apply changes
  test "approve applies changes to existing experience" do
    original_title = @experience.title
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      change_type: :update_resource,
      proposed_title: "New Title",
      proposed_description: "New description"
    )

    suggestion.approve!(@admin)

    @experience.reload
    assert_equal "New Title", @experience.title
    assert_equal "New description", @experience.description
  end

  test "approve creates new experience for create_resource" do
    suggestion = ExperienceSuggestion.create!(
      experience: nil,
      user: @user,
      change_type: :create_resource,
      proposed_title: "Brand New Experience",
      proposed_description: "Amazing adventure",
      proposed_estimated_duration: 180
    )

    assert_difference "Experience.count", 1 do
      suggestion.approve!(@admin)
    end

    suggestion.reload
    assert_not_nil suggestion.experience
    assert_equal "Brand New Experience", suggestion.experience.title
    assert_equal "Amazing adventure", suggestion.experience.description
    assert_equal 180, suggestion.experience.estimated_duration
  end

  test "reject does not change experience" do
    original_title = @experience.title
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      proposed_title: "New Title"
    )

    suggestion.reject!(@admin)

    @experience.reload
    assert_equal original_title, @experience.title
  end

  test "approve applies location associations" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      change_type: :update_resource,
      proposed_title: "Experience with Location",
      proposed_location_uuids: [@location.uuid]
    )

    suggestion.approve!(@admin)

    @experience.reload
    assert_includes @experience.locations, @location
  end

  # Multi-curator contributions
  test "add_contribution from another user" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      proposed_title: "Title from A",
      proposed_description: "Description from A"
    )

    suggestion.add_contribution(
      user: @curator_two,
      notes: "Improved description",
      proposed_description: "Better description",
      proposed_estimated_duration: 90
    )

    suggestion.reload
    assert_equal "Better description", suggestion.proposed_description
    assert_equal 90, suggestion.proposed_estimated_duration
    assert_equal 1, suggestion.contributions.count

    contribution = suggestion.contributions.first
    assert_equal @curator_two, contribution.user
    assert_equal "Improved description", contribution.notes
    assert_equal "Better description", contribution.proposed_description
  end

  # Unique constraint
  test "enforces one pending suggestion per experience" do
    ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      status: :pending,
      proposed_title: "First"
    )

    assert_raises ActiveRecord::RecordNotUnique do
      ExperienceSuggestion.create!(
        experience: @experience,
        user: @curator_two,
        status: :pending,
        proposed_title: "Second"
      )
    end
  end

  test "allows multiple approved suggestions for same experience" do
    ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      status: :approved,
      change_type: :update_resource,
      proposed_title: "First"
    )

    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @curator_two,
      status: :approved,
      change_type: :update_resource,
      proposed_title: "Second"
    )

    assert suggestion.persisted?
  end

  # find_or_create_pending!
  test "find_or_create_pending! returns existing pending suggestion" do
    existing = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      status: :pending,
      proposed_title: "Existing"
    )

    found = ExperienceSuggestion.find_or_create_pending!(
      @experience,
      user: @curator_two,
      proposed_title: "Should not create"
    )

    assert_equal existing.id, found.id
  end

  test "find_or_create_pending! creates new suggestion if none pending" do
    suggestion = ExperienceSuggestion.find_or_create_pending!(
      @experience,
      user: @user,
      proposed_title: "New"
    )

    assert suggestion.persisted?
    assert suggestion.pending?
    assert_equal "New", suggestion.proposed_title
  end

  # Cover photo validation
  test "has acceptable_cover_photo validation method" do
    suggestion = ExperienceSuggestion.new(
      experience: @experience,
      user: @user,
      proposed_title: "Test"
    )
    assert suggestion.respond_to?(:acceptable_cover_photo, true)
  end

  test "has proposed_cover_photo attachment" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      proposed_title: "Test"
    )
    assert suggestion.respond_to?(:proposed_cover_photo)
  end

  # proposed_changes
  test "proposed_changes returns non-nil proposed fields" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      proposed_title: "New Title",
      proposed_description: "New description",
      proposed_contact_name: nil
    )

    changes = suggestion.proposed_changes
    assert_includes changes.keys, "proposed_title"
    assert_includes changes.keys, "proposed_description"
    assert_not_includes changes.keys, "proposed_contact_name"
  end

  # Origin enum
  test "origin defaults to human" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      proposed_title: "Test"
    )
    assert suggestion.origin_human?
  end

  test "origin can be ai_generated" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      origin: :ai_generated,
      ai_service: "experience_enricher",
      proposed_title: "AI Generated"
    )
    assert suggestion.origin_ai_generated?
    assert_equal "experience_enricher", suggestion.ai_service
  end

  # Scopes
  test "pending_review scope" do
    pending = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      status: :pending,
      proposed_title: "Pending"
    )
    approved = ExperienceSuggestion.create!(
      experience: @experience_two,
      user: @user,
      status: :approved,
      change_type: :update_resource,
      proposed_title: "Approved"
    )

    results = ExperienceSuggestion.pending_review
    assert_includes results, pending
    assert_not_includes results, approved
  end

  test "human_suggestions scope" do
    human = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      origin: :human,
      proposed_title: "Human"
    )
    ai = ExperienceSuggestion.create!(
      experience: @experience_two,
      user: @user,
      origin: :ai_generated,
      ai_service: "test",
      proposed_title: "AI"
    )

    results = ExperienceSuggestion.human_suggestions
    assert_includes results, human
    assert_not_includes results, ai
  end

  test "ai_suggestions scope" do
    human = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      origin: :human,
      proposed_title: "Human"
    )
    ai = ExperienceSuggestion.create!(
      experience: @experience_two,
      user: @user,
      origin: :ai_generated,
      ai_service: "test",
      proposed_title: "AI"
    )

    results = ExperienceSuggestion.ai_suggestions
    assert_not_includes results, human
    assert_includes results, ai
  end

  # Experience-specific features
  test "applies category changes" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      change_type: :update_resource,
      proposed_experience_category_id: @category.id
    )

    suggestion.approve!(@admin)

    @experience.reload
    assert_equal @category.id, @experience.experience_category_id
  end

  test "applies seasons changes" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      change_type: :update_resource,
      proposed_seasons: ["summer", "spring"]
    )

    suggestion.approve!(@admin)

    @experience.reload
    assert_equal ["summer", "spring"], @experience.seasons
  end

  test "applies contact information changes" do
    suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user,
      change_type: :update_resource,
      proposed_contact_name: "John Doe",
      proposed_contact_email: "john@example.com",
      proposed_contact_phone: "+387 33 123 456",
      proposed_contact_website: "https://example.com"
    )

    suggestion.approve!(@admin)

    @experience.reload
    assert_equal "John Doe", @experience.contact_name
    assert_equal "john@example.com", @experience.contact_email
    assert_equal "+387 33 123 456", @experience.contact_phone
    assert_equal "https://example.com", @experience.contact_website
  end
end
