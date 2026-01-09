# frozen_string_literal: true

require "test_helper"

class ContentChangeTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(
      username: "test_curator",
      password: "password123",
      user_type: :curator
    )
    @admin = User.create!(
      username: "test_admin",
      password: "password123",
      user_type: :curator
    )
    @location = Location.create!(
      name: "Test Bridge",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )
  end

  teardown do
    ContentChange.destroy_all
    @location&.destroy
    @curator&.destroy
    @admin&.destroy
  end

  test "create content change requires user" do
    change = ContentChange.new(
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "New Location" }
    )
    assert_not change.valid?
    assert_includes change.errors[:user], "must exist"
  end

  test "create content change requires changeable_class" do
    change = ContentChange.new(
      user: @curator,
      change_type: :create_content,
      proposed_data: { "name" => "New Location" }
    )
    assert_not change.valid?
  end

  test "update content change requires changeable" do
    change = ContentChange.new(
      user: @curator,
      change_type: :update_content,
      proposed_data: { "name" => "Updated Name" }
    )
    assert_not change.valid?
    assert change.errors[:changeable].present?
  end

  test "create proposal sets default status to pending" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "New Location", "city" => "Sarajevo" }
    )
    assert change.pending?
  end

  test "approve creates record for create_content" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: {
        "name" => "Test Location",
        "city" => "Sarajevo",
        "description" => "A test location"
      }
    )

    assert_difference "Location.count", 1 do
      change.approve!(@admin)
    end

    assert change.approved?
    assert_equal @admin, change.reviewed_by
    assert_not_nil change.reviewed_at
    assert_not_nil change.changeable
    assert_equal "Test Location", change.changeable.name
  end

  test "approve updates record for update_content" do
    original_name = @location.name
    change = ContentChange.create!(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => original_name },
      proposed_data: { "name" => "Updated Bridge Name" }
    )

    change.approve!(@admin)

    assert change.approved?
    @location.reload
    assert_equal "Updated Bridge Name", @location.name
  end

  test "approve destroys record for delete_content" do
    # Create a separate location for this test since it will be destroyed
    delete_location = Location.create!(
      name: "To Delete",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )
    change = ContentChange.create!(
      user: @curator,
      change_type: :delete_content,
      changeable: delete_location,
      original_data: { "name" => delete_location.name }
    )

    assert_difference "Location.count", -1 do
      change.approve!(@admin)
    end

    assert change.approved?
  end

  test "reject sets status and notes" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "Test Location" }
    )

    change.reject!(@admin, notes: "Not appropriate content")

    assert change.rejected?
    assert_equal @admin, change.reviewed_by
    assert_equal "Not appropriate content", change.admin_notes
    assert_not_nil change.reviewed_at
  end

  test "cannot approve already reviewed proposal" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "Test Location" }
    )
    change.reject!(@admin, notes: "Rejected")

    assert_equal false, change.approve!(@admin)
    assert change.rejected? # Still rejected
  end

  test "cannot reject already approved proposal" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "Test Location", "city" => "Sarajevo" }
    )
    change.approve!(@admin)

    result = change.reject!(@admin, notes: "Too late")
    assert_equal false, result
    assert change.approved? # Still approved
  end

  test "description for create content" do
    change = ContentChange.new(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "New Location" }
    )
    assert_match(/Create new Location: New Location/, change.description)
  end

  test "description for update content" do
    change = ContentChange.new(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      proposed_data: { "name" => "Updated Name" }
    )
    assert_match(/Update Location/, change.description)
  end

  test "description for delete content" do
    change = ContentChange.new(
      user: @curator,
      change_type: :delete_content,
      changeable: @location,
      original_data: { "name" => @location.name }
    )
    assert_match(/Delete Location/, change.description)
  end

  test "changes_diff shows changed fields" do
    change = ContentChange.new(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => "Old Name", "city" => "Sarajevo" },
      proposed_data: { "name" => "New Name", "city" => "Sarajevo" }
    )

    diff = change.changes_diff
    assert diff.key?("name")
    assert_equal "Old Name", diff["name"][:from]
    assert_equal "New Name", diff["name"][:to]
    assert_not diff.key?("city") # Unchanged
  end

  test "pending_review scope returns only pending ordered by created_at" do
    ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "First" },
      created_at: 2.days.ago
    )
    ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "Second" },
      created_at: 1.day.ago
    )

    pending = ContentChange.pending_review
    assert pending.all?(&:pending?)
    assert_equal "First", pending.first.proposed_data["name"]
  end

  # Tests for single proposal per resource feature
  test "find_or_create_for_update creates new proposal when none exists" do
    proposal = ContentChange.find_or_create_for_update(
      changeable: @location,
      user: @curator,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "New Name" }
    )

    assert proposal.persisted?
    assert_equal @curator, proposal.user
    assert_equal @location, proposal.changeable
    assert proposal.update_content?
  end

  test "find_or_create_for_update adds contribution to existing proposal" do
    # First curator creates proposal
    first_proposal = ContentChange.find_or_create_for_update(
      changeable: @location,
      user: @curator,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Name from first curator" }
    )

    # Second curator adds to same proposal
    second_curator = User.create!(
      username: "second_curator",
      password: "password123",
      user_type: :curator
    )

    second_proposal = ContentChange.find_or_create_for_update(
      changeable: @location,
      user: second_curator,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Name from second curator", "description" => "New description" }
    )

    # Should return the same proposal
    assert_equal first_proposal.id, second_proposal.id

    # Should have one contribution (second curator's - first curator's data is in main proposed_data)
    assert_equal 1, second_proposal.contributions.count

    # Merged data should have the second curator's changes
    assert_equal "Name from second curator", second_proposal.proposed_data["name"]
    assert_equal "New description", second_proposal.proposed_data["description"]

    second_curator.destroy
  end

  test "find_or_create_for_delete creates deletion proposal" do
    proposal = ContentChange.find_or_create_for_delete(
      changeable: @location,
      user: @curator,
      original_data: { "name" => @location.name }
    )

    assert proposal.persisted?
    assert proposal.delete_content?
  end

  test "find_or_create_for_delete converts update proposal to delete" do
    # First create an update proposal
    update_proposal = ContentChange.find_or_create_for_update(
      changeable: @location,
      user: @curator,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Updated Name" }
    )

    assert update_proposal.update_content?

    # Now request deletion
    delete_proposal = ContentChange.find_or_create_for_delete(
      changeable: @location,
      user: @curator,
      original_data: { "name" => @location.name }
    )

    # Should be the same proposal, converted to delete
    assert_equal update_proposal.id, delete_proposal.id
    assert delete_proposal.reload.delete_content?
  end

  test "recommendation_summary counts reviews correctly" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "Test Location" }
    )

    reviewer1 = User.create!(username: "reviewer1", password: "password123", user_type: :curator)
    reviewer2 = User.create!(username: "reviewer2", password: "password123", user_type: :curator)
    reviewer3 = User.create!(username: "reviewer3", password: "password123", user_type: :curator)

    CuratorReview.create!(content_change: change, user: reviewer1, comment: "Looks good to me", recommendation: :recommend_approve)
    CuratorReview.create!(content_change: change, user: reviewer2, comment: "I have concerns about this", recommendation: :recommend_reject)
    CuratorReview.create!(content_change: change, user: reviewer3, comment: "No strong opinion", recommendation: :neutral)

    summary = change.recommendation_summary
    assert_equal 1, summary[:approve]
    assert_equal 1, summary[:reject]
    assert_equal 1, summary[:neutral]

    reviewer1.destroy
    reviewer2.destroy
    reviewer3.destroy
  end

  test "all_contributors includes proposer and all contributors" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Updated" }
    )

    contributor = User.create!(username: "contributor", password: "password123", user_type: :curator)
    change.add_contribution(user: contributor, proposed_data: { "description" => "New description" })

    all = change.all_contributors
    assert_includes all, @curator
    assert_includes all, contributor
    assert_equal 2, all.size

    contributor.destroy
  end

  test "sanitize_proposed_data removes dangerous HTML" do
    change = ContentChange.new(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: {
        "name" => "<script>alert('xss')</script>Test Location",
        "description" => "<b>Bold</b> and <onclick='alert()'>dangerous</onclick>"
      }
    )
    change.save!

    # Script tags should be stripped
    assert_not_includes change.proposed_data["name"], "<script>"
    # Safe tags should be kept
    assert_includes change.proposed_data["description"], "<b>Bold</b>"
    # Event handlers should be stripped
    assert_not_includes change.proposed_data["description"], "onclick"
  end

  # === Tests for needs_ai_regeneration (dirty flag) ===

  test "approve marks location as needing AI regeneration" do
    # Ensure location starts clean
    @location.update!(needs_ai_regeneration: false)

    change = ContentChange.create!(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Updated Name" }
    )

    change.approve!(@admin)
    @location.reload

    assert @location.needs_ai_regeneration, "Location should be marked as needing AI regeneration after approval"
  end

  test "approve marks experience as needing AI regeneration" do
    experience = Experience.create!(
      title: "Test Experience",
      needs_ai_regeneration: false
    )

    change = ContentChange.create!(
      user: @curator,
      change_type: :update_content,
      changeable: experience,
      original_data: { "title" => experience.title },
      proposed_data: { "title" => "Updated Title" }
    )

    change.approve!(@admin)
    experience.reload

    assert experience.needs_ai_regeneration, "Experience should be marked as needing AI regeneration after approval"

    experience.destroy
  end

  test "approve marks new location as needing AI regeneration" do
    change = ContentChange.create!(
      user: @curator,
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: {
        "name" => "New Test Location",
        "city" => "Sarajevo"
      }
    )

    change.approve!(@admin)

    created_location = change.changeable
    assert created_location.needs_ai_regeneration, "Newly created location should need AI regeneration"

    created_location.destroy
  end

  test "approve does not fail for delete_content" do
    delete_location = Location.create!(
      name: "To Delete",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )

    change = ContentChange.create!(
      user: @curator,
      change_type: :delete_content,
      changeable: delete_location,
      original_data: { "name" => delete_location.name }
    )

    # Should not raise an error
    assert_nothing_raised do
      change.approve!(@admin)
    end

    assert change.approved?
  end
end
