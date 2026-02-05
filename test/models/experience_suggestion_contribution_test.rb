# frozen_string_literal: true

require "test_helper"

class ExperienceSuggestionContributionTest < ActiveSupport::TestCase
  setup do
    @user_a = User.create!(
      username: "curator_a",
      password: "password123",
      user_type: :curator
    )
    @user_b = User.create!(
      username: "curator_b",
      password: "password123",
      user_type: :curator
    )
    @experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 120
    )
    @suggestion = ExperienceSuggestion.create!(
      experience: @experience,
      user: @user_a,
      proposed_title: "Original Title"
    )
  end

  teardown do
    ExperienceSuggestionContribution.destroy_all
    ExperienceSuggestion.destroy_all
    Experience.destroy_all
    User.destroy_all
  end

  test "creates contribution with valid attributes" do
    contribution = ExperienceSuggestionContribution.create!(
      experience_suggestion: @suggestion,
      user: @user_b,
      notes: "Improved title",
      proposed_title: "Better Title"
    )

    assert contribution.persisted?
    assert_equal @suggestion, contribution.experience_suggestion
    assert_equal @user_b, contribution.user
    assert_equal "Improved title", contribution.notes
    assert_equal "Better Title", contribution.proposed_title
  end

  test "requires experience_suggestion" do
    contribution = ExperienceSuggestionContribution.new(user: @user_b)
    assert_not contribution.valid?
    assert_includes contribution.errors[:experience_suggestion], "must exist"
  end

  test "requires user" do
    contribution = ExperienceSuggestionContribution.new(experience_suggestion: @suggestion)
    assert_not contribution.valid?
    assert_includes contribution.errors[:user], "must exist"
  end

  test "enforces unique user per suggestion" do
    ExperienceSuggestionContribution.create!(
      experience_suggestion: @suggestion,
      user: @user_b,
      proposed_title: "First contribution"
    )

    duplicate = ExperienceSuggestionContribution.new(
      experience_suggestion: @suggestion,
      user: @user_b,
      proposed_title: "Second contribution"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "already contributed to this suggestion"
  end

  test "allows same user to contribute to different suggestions" do
    suggestion_two = ExperienceSuggestion.create!(
      experience: Experience.create!(title: "Another Experience", estimated_duration: 60),
      user: @user_a,
      proposed_title: "Another Title"
    )

    first = ExperienceSuggestionContribution.create!(
      experience_suggestion: @suggestion,
      user: @user_b,
      proposed_title: "First"
    )

    second = ExperienceSuggestionContribution.create!(
      experience_suggestion: suggestion_two,
      user: @user_b,
      proposed_title: "Second"
    )

    assert first.persisted?
    assert second.persisted?
  end

  test "tracks multiple fields in contribution" do
    contribution = ExperienceSuggestionContribution.create!(
      experience_suggestion: @suggestion,
      user: @user_b,
      notes: "Multiple updates",
      proposed_title: "New Title",
      proposed_description: "New description",
      proposed_estimated_duration: 90,
      proposed_contact_name: "John Doe"
    )

    assert_equal "New Title", contribution.proposed_title
    assert_equal "New description", contribution.proposed_description
    assert_equal 90, contribution.proposed_estimated_duration
    assert_equal "John Doe", contribution.proposed_contact_name
  end

  test "allows nil for optional proposed fields" do
    contribution = ExperienceSuggestionContribution.create!(
      experience_suggestion: @suggestion,
      user: @user_b,
      proposed_title: "Just title"
    )

    assert_nil contribution.proposed_description
    assert_nil contribution.proposed_estimated_duration
    assert_nil contribution.proposed_contact_name
  end
end
