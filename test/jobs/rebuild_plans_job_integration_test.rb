# frozen_string_literal: true

require "test_helper"

class RebuildPlansJobIntegrationTest < ActiveJob::TestCase
  setup do
    @city = "Sarajevo"

    # Create a location for experiences
    @location = Location.create!(
      name: "Test Location",
      city: @city,
      lat: 43.8563,
      lng: 18.4131
    )

    # Create experience category
    @category = ExperienceCategory.find_or_create_by!(key: "culture") do |cat|
      cat.name = "Culture"
    end

    # Create current experiences in the plan
    @experience1 = Experience.create!(title: "Museum Visit", experience_category: @category)
    @experience1.add_location(@location)

    @experience2 = Experience.create!(title: "Walking Tour", experience_category: @category)
    @experience2.add_location(@location)

    # Create available replacement experiences
    @replacement_exp1 = Experience.create!(title: "Food Tour", experience_category: @category)
    @replacement_exp1.add_location(@location)

    @replacement_exp2 = Experience.create!(title: "Historical Walk", experience_category: @category)
    @replacement_exp2.add_location(@location)

    # Create AI-generated plan (user_id is nil)
    @plan = Plan.create!(
      title: "Test Plan",
      city_name: @city,
      user_id: nil,
      preferences: { "tourist_profile" => "family" }
    )

    # Add experiences to plan
    @plan.plan_experiences.create!(experience: @experience1, day_number: 1, position: 1)
    @plan.plan_experiences.create!(experience: @experience2, day_number: 2, position: 1)
  end

  teardown do
    RebuildPlansJob.clear_status!
  end

  # === Experience replacement threshold tests ===

  test "EXPERIENCE_REBUILD_THRESHOLD is 50" do
    assert_equal 50, RebuildPlansJob::EXPERIENCE_REBUILD_THRESHOLD
  end

  test "score below threshold triggers experience rebuild call in rebuild_plan" do
    job = RebuildPlansJob.new

    # Track whether rebuild_experiences_for_plan is called
    experience_rebuild_called = false

    # Redefine the method to track calls
    original_method = job.method(:rebuild_experiences_for_plan)
    job.define_singleton_method(:rebuild_experiences_for_plan) do |plan, experiences|
      experience_rebuild_called = true
      # Don't actually run it to avoid AI calls
    end

    issues = [{ type: :short_notes, message: "Notes too short" }]
    score = 30 # Below threshold of 50

    # Also stub the AI call for content regeneration
    ai_content_response = {
      titles: { "en" => "New Title", "bs" => "Novi Naslov" },
      notes: { "en" => "New notes for the plan", "bs" => "Nove bilješke za plan" }
    }

    Ai::OpenaiQueue.stub(:request, ai_content_response) do
      job.send(:rebuild_plan, @plan.id, issues, score)
    end

    assert experience_rebuild_called, "rebuild_experiences_for_plan should be called for score < 50"
  end

  test "score at or above threshold does not trigger experience rebuild" do
    job = RebuildPlansJob.new

    experience_rebuild_called = false

    job.define_singleton_method(:rebuild_experiences_for_plan) do |plan, experiences|
      experience_rebuild_called = true
    end

    issues = [{ type: :short_notes, message: "Notes too short" }]
    score = 60 # Above threshold of 50

    ai_content_response = {
      titles: { "en" => "New Title", "bs" => "Novi Naslov" },
      notes: { "en" => "New notes for the plan", "bs" => "Nove bilješke za plan" }
    }

    Ai::OpenaiQueue.stub(:request, ai_content_response) do
      job.send(:rebuild_plan, @plan.id, issues, score)
    end

    assert_not experience_rebuild_called, "rebuild_experiences_for_plan should NOT be called for score >= 50"
  end

  test "score exactly at threshold (50) does not trigger experience rebuild" do
    job = RebuildPlansJob.new

    experience_rebuild_called = false

    job.define_singleton_method(:rebuild_experiences_for_plan) do |plan, experiences|
      experience_rebuild_called = true
    end

    issues = [{ type: :short_notes, message: "Notes too short" }]
    score = 50 # Exactly at threshold

    ai_content_response = {
      titles: { "en" => "New Title", "bs" => "Novi Naslov" },
      notes: { "en" => "New notes", "bs" => "Nove bilješke" }
    }

    Ai::OpenaiQueue.stub(:request, ai_content_response) do
      job.send(:rebuild_plan, @plan.id, issues, score)
    end

    assert_not experience_rebuild_called, "rebuild_experiences_for_plan should NOT be called for score = 50"
  end

  # === apply_experience_replacements tests ===

  test "apply_experience_replacements preserves day_number and position" do
    # Get original plan_experience details
    original_pe = @plan.plan_experiences.find_by(experience: @experience1)
    original_day = original_pe.day_number
    original_position = original_pe.position

    # Create the job and call the private method directly
    job = RebuildPlansJob.new

    replacements = [
      {
        remove_experience_id: @experience1.id,
        add_experience_id: @replacement_exp1.id,
        reason: "Test replacement"
      }
    ]

    available = [@replacement_exp1, @replacement_exp2]

    job.send(:apply_experience_replacements, @plan, replacements, available)

    # Verify replacement preserves day and position
    @plan.reload
    new_pe = @plan.plan_experiences.find_by(experience: @replacement_exp1)

    assert_not_nil new_pe, "Replacement experience should be added to plan"
    assert_equal original_day, new_pe.day_number, "Day number should be preserved"
    assert_equal original_position, new_pe.position, "Position should be preserved"

    # Verify original experience is removed
    assert_nil @plan.plan_experiences.find_by(experience: @experience1), "Original experience should be removed"
  end

  test "apply_experience_replacements validates replacement experience exists in available list" do
    job = RebuildPlansJob.new

    # Try to replace with an experience not in available list
    other_experience = Experience.create!(title: "Other Experience")

    replacements = [
      {
        remove_experience_id: @experience1.id,
        add_experience_id: other_experience.id, # Not in available list
        reason: "Test replacement"
      }
    ]

    # Only @replacement_exp1 in available list
    available = [@replacement_exp1]

    job.send(:apply_experience_replacements, @plan, replacements, available)

    # Verify replacement did NOT happen (experience not in available list)
    @plan.reload
    assert @plan.plan_experiences.find_by(experience: @experience1).present?, "Original should remain if replacement not available"
    assert_nil @plan.plan_experiences.find_by(experience: other_experience), "Unavailable replacement should not be added"
  end

  test "apply_experience_replacements handles multiple replacements" do
    job = RebuildPlansJob.new

    original_pe1 = @plan.plan_experiences.find_by(experience: @experience1)
    original_pe2 = @plan.plan_experiences.find_by(experience: @experience2)

    replacements = [
      {
        remove_experience_id: @experience1.id,
        add_experience_id: @replacement_exp1.id,
        reason: "First replacement"
      },
      {
        remove_experience_id: @experience2.id,
        add_experience_id: @replacement_exp2.id,
        reason: "Second replacement"
      }
    ]

    available = [@replacement_exp1, @replacement_exp2]

    job.send(:apply_experience_replacements, @plan, replacements, available)

    @plan.reload

    # Verify both replacements happened
    new_pe1 = @plan.plan_experiences.find_by(experience: @replacement_exp1)
    new_pe2 = @plan.plan_experiences.find_by(experience: @replacement_exp2)

    assert_not_nil new_pe1
    assert_not_nil new_pe2
    assert_equal original_pe1.day_number, new_pe1.day_number
    assert_equal original_pe2.day_number, new_pe2.day_number
  end

  test "rebuild_experiences_for_plan respects keep_all=true" do
    job = RebuildPlansJob.new

    original_experience_ids = @plan.experiences.pluck(:id).sort

    # AI decides to keep all experiences
    ai_replacement_response = {
      keep_all: true,
      replacements: [],
      reasoning: "All experiences fit the profile well"
    }

    Ai::OpenaiQueue.stub(:request, ai_replacement_response) do
      job.send(:rebuild_experiences_for_plan, @plan, @plan.experiences.to_a)
    end

    @plan.reload
    assert_equal original_experience_ids, @plan.experiences.pluck(:id).sort, "All experiences should be preserved when AI decides keep_all"
  end

  # === User-owned plans should never be modified ===

  test "rebuild_plan returns false for user-owned plans" do
    # Create user-owned plan
    user = User.create!(username: "testuser", password: "password123")
    user_plan = Plan.create!(
      title: "User Plan",
      city_name: @city,
      user: user
    )
    user_plan.plan_experiences.create!(experience: @experience1, day_number: 1, position: 1)

    original_experience_ids = user_plan.experiences.pluck(:id)
    issues = [{ type: :missing_notes, message: "No notes" }]
    score = 10 # Very low score

    job = RebuildPlansJob.new

    # rebuild_plan should return false for user-owned plans without doing anything
    result = job.send(:rebuild_plan, user_plan.id, issues, score)

    assert_equal false, result, "rebuild_plan should return false for user-owned plans"

    user_plan.reload
    assert_equal original_experience_ids, user_plan.experiences.pluck(:id), "User plan experiences should remain unchanged"
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = RebuildPlansJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "clear_status! resets status to idle" do
    Setting.set("rebuild_plans.status", "in_progress")

    RebuildPlansJob.clear_status!

    status = RebuildPlansJob.current_status
    assert_equal "idle", status[:status]
  end
end
