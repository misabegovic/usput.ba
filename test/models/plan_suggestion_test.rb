# frozen_string_literal: true

require "test_helper"

class PlanSuggestionTest < ActiveSupport::TestCase
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
    @plan = Plan.create!(
      title: "Test Plan",
      city_name: "Sarajevo",
      user: @user
    )
    @plan_two = Plan.create!(
      title: "Test Plan Two",
      city_name: "Mostar",
      user: @user
    )
  end

  teardown do
    PlanSuggestion.destroy_all
    PlanSuggestionContribution.destroy_all
    Plan.destroy_all
    User.destroy_all
  end

  # Basic creation and validation
  test "creates plan suggestion with valid attributes" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
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
    suggestion = PlanSuggestion.new(plan: @plan)
    assert_not suggestion.valid?
    assert_includes suggestion.errors[:user], "can't be blank"
  end

  test "allows nil plan for create_resource" do
    suggestion = PlanSuggestion.create!(
      plan: nil,
      user: @user,
      status: :pending,
      change_type: :create_resource,
      origin: :human,
      proposed_title: "New Plan",
      proposed_city_name: "Sarajevo"
    )

    assert suggestion.persisted?
    assert_nil suggestion.plan
  end

  # Status transitions
  test "pending is default status" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      proposed_title: "Test"
    )
    assert suggestion.pending?
  end

  test "changes status to approved" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
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
    suggestion = PlanSuggestion.create!(
      plan: @plan,
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
  test "approve applies changes to existing plan" do
    original_title = @plan.title
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      change_type: :update_resource,
      proposed_title: "New Title",
      proposed_city_name: "Mostar"
    )

    suggestion.approve!(@admin)

    @plan.reload
    assert_equal "New Title", @plan.title
    assert_equal "Mostar", @plan.city_name
  end

  test "approve creates new plan for create_resource" do
    suggestion = PlanSuggestion.create!(
      plan: nil,
      user: @user,
      change_type: :create_resource,
      proposed_title: "Brand New Plan",
      proposed_city_name: "Sarajevo"
    )

    assert_difference "Plan.count", 1 do
      suggestion.approve!(@admin)
    end

    suggestion.reload
    assert_not_nil suggestion.plan
    assert_equal "Brand New Plan", suggestion.plan.title
    assert_equal "Sarajevo", suggestion.plan.city_name
  end

  test "reject does not change plan" do
    original_title = @plan.title
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      proposed_title: "New Title"
    )

    suggestion.reject!(@admin)

    @plan.reload
    assert_equal original_title, @plan.title
  end

  # Multi-curator contributions
  test "add_contribution from another user" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      proposed_title: "Title from A",
      proposed_city_name: "Mostar"
    )

    suggestion.add_contribution(
      user: @curator_two,
      notes: "Improved title and city",
      proposed_title: "Better Title",
      proposed_city_name: "Updated City"
    )

    suggestion.reload
    assert_equal "Better Title", suggestion.proposed_title
    assert_equal "Updated City", suggestion.proposed_city_name
    assert_equal 1, suggestion.contributions.count

    contribution = suggestion.contributions.first
    assert_equal @curator_two, contribution.user
    assert_equal "Improved title and city", contribution.notes
    assert_equal "Better Title", contribution.proposed_title
  end

  # Unique constraint
  test "enforces one pending suggestion per plan" do
    PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      status: :pending,
      proposed_title: "First"
    )

    assert_raises ActiveRecord::RecordNotUnique do
      PlanSuggestion.create!(
        plan: @plan,
        user: @curator_two,
        status: :pending,
        proposed_title: "Second"
      )
    end
  end

  test "allows multiple approved suggestions for same plan" do
    PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      status: :approved,
      change_type: :update_resource,
      proposed_title: "First"
    )

    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator_two,
      status: :approved,
      change_type: :update_resource,
      proposed_title: "Second"
    )

    assert suggestion.persisted?
  end

  # find_or_create_pending!
  test "find_or_create_pending! returns existing pending suggestion" do
    existing = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      status: :pending,
      proposed_title: "Existing"
    )

    found = PlanSuggestion.find_or_create_pending!(
      @plan,
      user: @curator_two,
      proposed_title: "Should not create"
    )

    assert_equal existing.id, found.id
  end

  test "find_or_create_pending! creates new suggestion if none pending" do
    suggestion = PlanSuggestion.find_or_create_pending!(
      @plan,
      user: @user,
      proposed_title: "New"
    )

    assert suggestion.persisted?
    assert suggestion.pending?
    assert_equal "New", suggestion.proposed_title
  end

  # Cover photo attachment
  test "has proposed_cover_photo attachment" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      proposed_title: "Test"
    )
    assert suggestion.respond_to?(:proposed_cover_photo)
  end

  # proposed_changes
  test "proposed_changes returns non-nil proposed fields" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      proposed_title: "New Title",
      proposed_city_name: "Mostar",
      proposed_notes: nil
    )

    changes = suggestion.proposed_changes
    assert_includes changes.keys, "proposed_title"
    assert_includes changes.keys, "proposed_city_name"
    assert_not_includes changes.keys, "proposed_notes"
  end

  # Origin enum
  test "origin defaults to human" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      proposed_title: "Test"
    )
    assert suggestion.origin_human?
  end

  test "origin can be ai_generated" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      origin: :ai_generated,
      ai_service: "plan_generator",
      proposed_title: "AI Generated"
    )
    assert suggestion.origin_ai_generated?
    assert_equal "plan_generator", suggestion.ai_service
  end

  # Scopes
  test "pending_review scope" do
    pending = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      status: :pending,
      proposed_title: "Pending"
    )
    approved = PlanSuggestion.create!(
      plan: @plan_two,
      user: @user,
      status: :approved,
      change_type: :update_resource,
      proposed_title: "Approved"
    )

    results = PlanSuggestion.pending_review
    assert_includes results, pending
    assert_not_includes results, approved
  end

  test "human_suggestions scope" do
    human = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      origin: :human,
      proposed_title: "Human"
    )
    ai = PlanSuggestion.create!(
      plan: @plan_two,
      user: @user,
      origin: :ai_generated,
      ai_service: "test",
      proposed_title: "AI"
    )

    results = PlanSuggestion.human_suggestions
    assert_includes results, human
    assert_not_includes results, ai
  end

  test "ai_suggestions scope" do
    human = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      origin: :human,
      proposed_title: "Human"
    )
    ai = PlanSuggestion.create!(
      plan: @plan_two,
      user: @user,
      origin: :ai_generated,
      ai_service: "test",
      proposed_title: "AI"
    )

    results = PlanSuggestion.ai_suggestions
    assert_not_includes results, human
    assert_includes results, ai
  end

  # Experience days handling
  test "approve applies experience_days to plan" do
    exp1 = Experience.create!(title: "Exp 1")
    exp2 = Experience.create!(title: "Exp 2")

    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @user,
      change_type: :update_resource,
      proposed_experience_days: {
        "1" => [exp1.uuid, exp2.uuid]
      }
    )

    suggestion.approve!(@admin)

    @plan.reload
    days = @plan.experience_days
    assert_equal [exp1.uuid, exp2.uuid], days["1"]
  end
end
