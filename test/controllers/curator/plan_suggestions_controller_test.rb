# frozen_string_literal: true

require "test_helper"

class Curator::PlanSuggestionsControllerTest < ActionDispatch::IntegrationTest
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
    @plan = Plan.create!(
      user: @curator,
      title: "Test Plan",
      city_name: "Sarajevo",
      visibility: :public_plan
    )
  end

  teardown do
    PlanSuggestion.destroy_all
    @plan&.destroy
    @curator&.destroy
    @other_curator&.destroy
    @basic_user&.destroy
  end

  # Authentication tests
  test "new requires login" do
    get new_curator_plan_plan_suggestion_path(@plan)
    assert_redirected_to login_path
  end

  test "new requires curator role" do
    login_as(@basic_user)
    get new_curator_plan_plan_suggestion_path(@plan)
    assert_redirected_to root_path
  end

  # New action tests
  test "new creates pending suggestion and redirects to edit" do
    login_as(@curator)

    assert_difference "PlanSuggestion.count", 1 do
      get new_curator_plan_plan_suggestion_path(@plan)
    end

    suggestion = PlanSuggestion.last
    assert_redirected_to edit_curator_plan_plan_suggestion_path(@plan, suggestion)
    assert_equal @curator, suggestion.user
    assert_equal @plan, suggestion.plan
    assert_equal "pending", suggestion.status
    assert_equal "update_resource", suggestion.change_type
    assert_equal "human", suggestion.origin
  end

  test "new finds existing pending suggestion instead of creating new one" do
    login_as(@curator)

    # Create existing suggestion
    existing = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    assert_no_difference "PlanSuggestion.count" do
      get new_curator_plan_plan_suggestion_path(@plan)
    end

    assert_redirected_to edit_curator_plan_plan_suggestion_path(@plan, existing)
  end

  # Edit action tests
  test "edit requires login" do
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    get edit_curator_plan_plan_suggestion_path(@plan, suggestion)
    assert_redirected_to login_path
  end

  # Note: Skipping edit shows form test since views are created separately

  # Create action tests
  test "create requires login" do
    post curator_plan_plan_suggestions_path(@plan), params: {
      plan_suggestion: { proposed_title: "New Title" }
    }
    assert_redirected_to login_path
  end

  test "create by original creator updates suggestion directly" do
    login_as(@curator)

    # Create pending suggestion
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    post curator_plan_plan_suggestions_path(@plan), params: {
      plan_suggestion: {
        proposed_title: "Updated Title",
        proposed_notes: "Updated notes",
        proposed_city_name: "Mostar"
      }
    }

    assert_redirected_to curator_plan_path(@plan)
    assert_match "Prijedlog uspješno kreiran", flash[:notice]

    suggestion.reload
    assert_equal "Updated Title", suggestion.proposed_title
    assert_equal "Updated notes", suggestion.proposed_notes
    assert_equal "Mostar", suggestion.proposed_city_name
  end

  test "create by different curator adds contribution" do
    login_as(@curator)

    # Create pending suggestion by first curator
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_title: "Original Title"
    )

    # Other curator adds contribution
    login_as(@other_curator)

    assert_difference "PlanSuggestionContribution.count", 1 do
      post curator_plan_plan_suggestions_path(@plan), params: {
        plan_suggestion: {
          proposed_title: "Contributed Title",
          contribution_notes: "I suggest this title instead"
        }
      }
    end

    assert_redirected_to curator_plan_path(@plan)
    assert_match "Doprinos prijedlogu uspješno dodan", flash[:notice]

    suggestion.reload
    assert_equal "Contributed Title", suggestion.proposed_title
  end

  test "create records curator activity for original creator" do
    login_as(@curator)

    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    assert_difference "CuratorActivity.count", 1 do
      post curator_plan_plan_suggestions_path(@plan), params: {
        plan_suggestion: { proposed_title: "Activity Test" }
      }
    end

    activity = CuratorActivity.last
    assert_equal "suggestion_created", activity.action
    assert_equal @curator, activity.user
    assert_equal suggestion, activity.recordable
  end

  test "create records curator activity for contributor" do
    login_as(@curator)

    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    login_as(@other_curator)

    assert_difference "CuratorActivity.count", 1 do
      post curator_plan_plan_suggestions_path(@plan), params: {
        plan_suggestion: {
          proposed_title: "Contribution",
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
    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human
    )

    patch curator_plan_plan_suggestion_path(@plan, suggestion), params: {
      plan_suggestion: { proposed_title: "New Title" }
    }
    assert_redirected_to login_path
  end

  test "update by original creator updates suggestion directly" do
    login_as(@curator)

    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_title: "Original"
    )

    patch curator_plan_plan_suggestion_path(@plan, suggestion), params: {
      plan_suggestion: {
        proposed_title: "Updated via PATCH",
        proposed_visibility: "private_plan"
      }
    }

    assert_redirected_to curator_plan_path(@plan)
    assert_match "Prijedlog ažuriran", flash[:notice]

    suggestion.reload
    assert_equal "Updated via PATCH", suggestion.proposed_title
    assert_equal 0, suggestion.proposed_visibility
  end

  test "update by different curator adds contribution" do
    login_as(@curator)

    suggestion = PlanSuggestion.create!(
      plan: @plan,
      user: @curator,
      status: :pending,
      change_type: :update_resource,
      origin: :human,
      proposed_title: "Original"
    )

    login_as(@other_curator)

    assert_difference "PlanSuggestionContribution.count", 1 do
      patch curator_plan_plan_suggestion_path(@plan, suggestion), params: {
        plan_suggestion: {
          proposed_title: "Contributed via PATCH",
          contribution_notes: "Better title"
        }
      }
    end

    assert_redirected_to curator_plan_path(@plan)
    assert_match "Doprinos prijedlogu uspješno dodan", flash[:notice]

    suggestion.reload
    assert_equal "Contributed via PATCH", suggestion.proposed_title
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
