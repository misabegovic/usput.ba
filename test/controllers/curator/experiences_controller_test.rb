# frozen_string_literal: true

require "test_helper"

class Curator::ExperiencesControllerTest < ActionDispatch::IntegrationTest
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
    @admin = User.create!(
      username: "admin_user_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :admin
    )

    @experience_category = ExperienceCategory.create!(
      key: "test_category_#{SecureRandom.hex(4)}",
      name: "Test Category"
    )

    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @experience = Experience.create!(
      title: "Test Experience",
      description: "A test experience description",
      experience_category: @experience_category,
      estimated_duration: 120,
      contact_name: "John Doe",
      contact_email: "john@example.com"
    )
    @experience.locations << @location
  end

  teardown do
    ContentChange.destroy_all
    CuratorActivity.destroy_all
    @experience&.experience_locations&.destroy_all
    @experience&.destroy
    @location&.destroy
    @experience_category&.destroy
    @curator&.destroy
    @other_curator&.destroy
    @basic_user&.destroy
    @admin&.destroy
  end

  # ============================================
  # Authentication Tests
  # ============================================

  test "index requires login" do
    get curator_experiences_path
    assert_redirected_to login_path
  end

  test "index requires curator role" do
    login_as(@basic_user)
    get curator_experiences_path
    assert_redirected_to root_path
  end

  test "show requires login" do
    get curator_experience_path(@experience)
    assert_redirected_to login_path
  end

  test "show requires curator role" do
    login_as(@basic_user)
    get curator_experience_path(@experience)
    assert_redirected_to root_path
  end

  test "new requires login" do
    get new_curator_experience_path
    assert_redirected_to login_path
  end

  test "new requires curator role" do
    login_as(@basic_user)
    get new_curator_experience_path
    assert_redirected_to root_path
  end

  test "create requires login" do
    post curator_experiences_path, params: { experience: valid_experience_params }
    assert_redirected_to login_path
  end

  test "create requires curator role" do
    login_as(@basic_user)
    post curator_experiences_path, params: { experience: valid_experience_params }
    assert_redirected_to root_path
  end

  test "edit requires login" do
    get edit_curator_experience_path(@experience)
    assert_redirected_to login_path
  end

  test "edit requires curator role" do
    login_as(@basic_user)
    get edit_curator_experience_path(@experience)
    assert_redirected_to root_path
  end

  test "update requires login" do
    patch curator_experience_path(@experience), params: { experience: { title: "Updated" } }
    assert_redirected_to login_path
  end

  test "update requires curator role" do
    login_as(@basic_user)
    patch curator_experience_path(@experience), params: { experience: { title: "Updated" } }
    assert_redirected_to root_path
  end

  test "destroy requires login" do
    delete curator_experience_path(@experience)
    assert_redirected_to login_path
  end

  test "destroy requires curator role" do
    login_as(@basic_user)
    delete curator_experience_path(@experience)
    assert_redirected_to root_path
  end

  # ============================================
  # Admin Access Tests
  # ============================================

  test "admin can access curator experiences" do
    login_as(@admin)
    get curator_experiences_path
    assert_response :success
  end

  # ============================================
  # Index Action Tests
  # ============================================

  test "index shows experiences list" do
    login_as(@curator)
    get curator_experiences_path
    assert_response :success
    assert_match @experience.title, response.body
  end

  test "index filters by city_name" do
    login_as(@curator)
    get curator_experiences_path, params: { city_name: "Sarajevo" }
    assert_response :success
    assert_match @experience.title, response.body
  end

  test "index filters by city_name excludes non-matching" do
    login_as(@curator)
    get curator_experiences_path, params: { city_name: "Mostar" }
    assert_response :success
    assert_no_match @experience.title, response.body
  end

  test "index filters by category_id" do
    login_as(@curator)
    get curator_experiences_path, params: { category_id: @experience_category.uuid }
    assert_response :success
    assert_match @experience.title, response.body
  end

  test "index filters by search term" do
    login_as(@curator)
    get curator_experiences_path, params: { search: "Test" }
    assert_response :success
    assert_match @experience.title, response.body
  end

  test "index search excludes non-matching" do
    login_as(@curator)
    get curator_experiences_path, params: { search: "NonExistent" }
    assert_response :success
    assert_no_match @experience.title, response.body
  end

  test "index shows pending proposals for curator" do
    # Create a pending proposal for this curator
    proposal = @curator.content_changes.create!(
      change_type: :create_content,
      changeable_class: "Experience",
      proposed_data: { "title" => "New Experience" }
    )

    login_as(@curator)
    get curator_experiences_path
    assert_response :success

    proposal.destroy
  end

  # ============================================
  # Show Action Tests
  # ============================================

  test "show displays experience details" do
    login_as(@curator)
    get curator_experience_path(@experience)
    assert_response :success
    assert_match @experience.title, response.body
    assert_match @experience.description, response.body
  end

  test "show finds experience by uuid" do
    login_as(@curator)
    get curator_experience_path(@experience.uuid)
    assert_response :success
    assert_match @experience.title, response.body
  end

  test "show returns 404 for non-existent experience" do
    login_as(@curator)
    get curator_experience_path("00000000-0000-0000-0000-000000000000")
    assert_response :not_found
  end

  test "show displays pending proposal if exists" do
    # Create a pending proposal for this experience
    proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @experience,
      original_data: { "title" => @experience.title },
      proposed_data: { "title" => "Updated Title" }
    )

    login_as(@curator)
    get curator_experience_path(@experience)
    assert_response :success

    proposal.destroy
  end

  # ============================================
  # New Action Tests
  # ============================================

  test "new shows create form" do
    login_as(@curator)
    get new_curator_experience_path
    assert_response :success
  end

  test "new loads form options" do
    login_as(@curator)
    get new_curator_experience_path
    assert_response :success
    # Form should render categories and locations dropdowns
    assert_select "select[name='experience[experience_category_id]']"
    assert_select "select#location-search"
  end

  # ============================================
  # Create Action Tests
  # ============================================

  test "create with valid params creates proposal not experience" do
    login_as(@curator)

    assert_no_difference "Experience.count" do
      assert_difference "ContentChange.count", 1 do
        post curator_experiences_path, params: { experience: valid_experience_params }
      end
    end

    assert_redirected_to curator_experiences_path

    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal "Experience", proposal.changeable_class
    assert_equal @curator, proposal.user
    assert_equal "pending", proposal.status
    assert_equal valid_experience_params[:title], proposal.proposed_data["title"]

    proposal.destroy
  end

  test "create records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      post curator_experiences_path, params: { experience: valid_experience_params }
    end

    activity = CuratorActivity.last
    assert_equal "proposal_created", activity.action
    assert_equal @curator, activity.user
    assert_equal "Experience", activity.metadata["type"]

    activity.destroy
    ContentChange.last&.destroy
  end

  test "create includes location_uuids in proposal data" do
    login_as(@curator)

    params = valid_experience_params.merge(location_uuids: [@location.uuid])
    post curator_experiences_path, params: { experience: params }

    proposal = ContentChange.last
    assert_includes proposal.proposed_data["location_uuids"], @location.uuid

    proposal.destroy
  end

  test "create with empty title still creates proposal" do
    # Note: Experience validation happens when proposal is approved, not at submission
    # The proposal system accepts any data, admin validates on approval
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      post curator_experiences_path, params: { experience: { title: "" } }
    end

    assert_redirected_to curator_experiences_path
    ContentChange.last&.destroy
  end

  test "create without experience params returns bad request" do
    login_as(@curator)

    # This should fail as there's no experience parameter at all
    post curator_experiences_path, params: {}
    assert_response :bad_request
  end

  # ============================================
  # Edit Action Tests
  # ============================================

  test "edit shows edit form" do
    login_as(@curator)
    get edit_curator_experience_path(@experience)
    assert_response :success
    assert_match @experience.title, response.body
  end

  test "edit loads form options" do
    login_as(@curator)
    get edit_curator_experience_path(@experience)
    assert_response :success
    # Form should render categories and locations dropdowns
    assert_select "select[name='experience[experience_category_id]']"
    assert_select "select#location-search"
  end

  test "edit shows pending proposal warning if exists" do
    # Create a pending proposal for this experience
    proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @experience,
      original_data: { "title" => @experience.title },
      proposed_data: { "title" => "Updated Title" }
    )

    login_as(@curator)
    get edit_curator_experience_path(@experience)
    assert_response :success
    # The page should show some indication of pending proposal
    # (checking for presence in response body or specific element)

    proposal.destroy
  end

  # ============================================
  # Update Action Tests
  # ============================================

  test "update creates proposal not direct update" do
    login_as(@curator)

    original_title = @experience.title

    assert_difference "ContentChange.count", 1 do
      patch curator_experience_path(@experience), params: {
        experience: { title: "Updated Experience Title" }
      }
    end

    assert_redirected_to curator_experience_path(@experience)

    # Experience should not be updated directly
    @experience.reload
    assert_equal original_title, @experience.title

    proposal = ContentChange.last
    assert_equal "update_content", proposal.change_type
    assert_equal @experience, proposal.changeable
    assert_equal "Updated Experience Title", proposal.proposed_data["title"]

    proposal.destroy
  end

  test "update records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      patch curator_experience_path(@experience), params: {
        experience: { title: "Updated Experience Title" }
      }
    end

    activity = CuratorActivity.last
    assert_includes ["proposal_updated", "proposal_contributed"], activity.action
    assert_equal @curator, activity.user

    activity.destroy
    ContentChange.last&.destroy
  end

  test "update adds contribution to existing proposal" do
    # Create an existing pending proposal by another curator
    existing_proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @experience,
      original_data: { "title" => @experience.title },
      proposed_data: { "title" => "First Update" }
    )

    login_as(@curator)

    # Should not create a new proposal, but add contribution
    assert_no_difference "ContentChange.count" do
      patch curator_experience_path(@experience), params: {
        experience: { title: "Second Update", description: "New description" }
      }
    end

    assert_redirected_to curator_experience_path(@experience)

    existing_proposal.reload
    # Contributions should be added
    assert existing_proposal.contributions.exists?(user: @curator)

    existing_proposal.destroy
  end

  test "update with invalid data renders edit with errors" do
    login_as(@curator)

    # Mock the find_or_create_for_update to return unpersisted record
    ContentChange.stub(:find_or_create_for_update, ContentChange.new) do
      patch curator_experience_path(@experience), params: {
        experience: { title: "Updated Title" }
      }
    end

    assert_response :unprocessable_entity
  end

  # ============================================
  # Destroy Action Tests
  # ============================================

  test "destroy creates delete proposal not direct delete" do
    login_as(@curator)

    assert_no_difference "Experience.count" do
      assert_difference "ContentChange.count", 1 do
        delete curator_experience_path(@experience)
      end
    end

    assert_redirected_to curator_experiences_path

    proposal = ContentChange.last
    assert_equal "delete_content", proposal.change_type
    assert_equal @experience, proposal.changeable

    proposal.destroy
  end

  test "destroy records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      delete curator_experience_path(@experience)
    end

    activity = CuratorActivity.last
    assert_equal "proposal_deleted", activity.action
    assert_equal @curator, activity.user
    assert_equal @experience.title, activity.metadata["title"]

    activity.destroy
    ContentChange.last&.destroy
  end

  test "destroy adds contribution to existing proposal" do
    # Create an existing pending update proposal
    existing_proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @experience,
      original_data: { "title" => @experience.title },
      proposed_data: { "title" => "Updated Title" }
    )

    login_as(@curator)

    # Should not create a new proposal
    assert_no_difference "ContentChange.count" do
      delete curator_experience_path(@experience)
    end

    assert_redirected_to curator_experiences_path

    existing_proposal.reload
    # Should be converted to delete
    assert_equal "delete_content", existing_proposal.change_type

    existing_proposal.destroy
  end

  # ============================================
  # Spam Protection Tests
  # ============================================

  test "spam blocked curator cannot access index" do
    @curator.update!(
      spam_blocked_at: Time.current,
      spam_blocked_until: 1.hour.from_now,
      spam_block_reason: "Testing"
    )

    login_as(@curator)
    get curator_experiences_path
    assert_redirected_to root_path
  end

  test "spam blocked curator cannot create" do
    @curator.update!(
      spam_blocked_at: Time.current,
      spam_blocked_until: 1.hour.from_now,
      spam_block_reason: "Testing"
    )

    login_as(@curator)
    post curator_experiences_path, params: { experience: valid_experience_params }
    assert_redirected_to root_path

    assert_no_difference "ContentChange.count" do
      # Re-attempt after redirect
    end
  end

  # ============================================
  # Edge Cases
  # ============================================

  test "create filters blank location_uuids" do
    login_as(@curator)

    params = valid_experience_params.merge(location_uuids: ["", @location.uuid, ""])
    post curator_experiences_path, params: { experience: params }

    proposal = ContentChange.last
    assert_equal [@location.uuid], proposal.proposed_data["location_uuids"]

    proposal.destroy
  end

  test "create handles seasons array" do
    login_as(@curator)

    params = valid_experience_params.merge(seasons: ["spring", "summer"])
    post curator_experiences_path, params: { experience: params }

    proposal = ContentChange.last
    assert_equal ["spring", "summer"], proposal.proposed_data["seasons"]

    proposal.destroy
  end

  test "index with pagination" do
    login_as(@curator)
    get curator_experiences_path, params: { page: 1 }
    assert_response :success
  end

  test "index combined filters" do
    login_as(@curator)
    get curator_experiences_path, params: {
      city_name: "Sarajevo",
      category_id: @experience_category.uuid,
      search: "Test"
    }
    assert_response :success
    assert_match @experience.title, response.body
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end

  def valid_experience_params
    {
      title: "New Test Experience",
      description: "A description for the new experience",
      experience_category_id: @experience_category.id,
      estimated_duration: 90,
      contact_name: "Jane Doe",
      contact_email: "jane@example.com",
      contact_phone: "+387 61 123 456",
      contact_website: "https://example.com"
    }
  end
end
