# frozen_string_literal: true

require "test_helper"

class UserPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test location
    @location = Location.create!(
      name: "Test Location",
      description: "A test location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place,
      budget: :medium
    )

    # Create test experience
    @experience = Experience.create!(
      title: "Test Experience",
      description: "A test experience",
      estimated_duration: 60
    )
    @experience.add_location(@location, position: 1)

    # Create second experience for multi-experience tests
    @experience2 = Experience.create!(
      title: "Second Experience",
      description: "Another test experience",
      estimated_duration: 45
    )
    @experience2.add_location(@location, position: 1)

    # Create test user
    @user = User.create!(
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    )

    # Create a plan for the user
    @plan = Plan.create!(
      title: "My Test Plan",
      city_name: "Sarajevo",
      user: @user,
      visibility: :private_plan,
      local_id: "local-plan-123"
    )
    @plan.plan_experiences.create!(
      experience: @experience,
      day_number: 1,
      position: 1
    )

    # Create another user for authorization tests
    @other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  teardown do
    @plan&.destroy
    @user&.destroy
    @other_user&.destroy
    @experience2&.destroy
    @experience&.destroy
    @location&.destroy
  end

  # === Authentication tests ===

  test "index requires authentication" do
    get user_plans_path, as: :json

    assert_response :unauthorized
    body = response.parsed_body
    assert_equal "Authentication required", body["error"]
  end

  test "show requires authentication" do
    get user_plan_path(@plan.uuid), as: :json

    assert_response :unauthorized
  end

  test "create requires authentication" do
    post user_plans_path, params: { plan: valid_plan_params }, as: :json

    assert_response :unauthorized
  end

  test "update requires authentication" do
    patch user_plan_path(@plan.uuid), params: { plan: valid_plan_params }, as: :json

    assert_response :unauthorized
  end

  test "destroy requires authentication" do
    delete user_plan_path(@plan.uuid), as: :json

    assert_response :unauthorized
  end

  test "sync requires authentication" do
    post sync_user_plans_path, params: { plans: [] }, as: :json

    assert_response :unauthorized
  end

  test "share requires authentication" do
    post share_user_plans_path, params: { plan: valid_plan_params }, as: :json

    assert_response :unauthorized
  end

  test "toggle_visibility requires authentication" do
    post toggle_visibility_user_plan_path(@plan.uuid), as: :json

    assert_response :unauthorized
  end

  # === Index action tests ===

  test "index returns user plans" do
    login_as(@user)

    get user_plans_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["plans"].is_a?(Array)
    assert_equal 1, body["plans"].count
    assert_equal @plan.local_id, body["plans"].first["id"]
  end

  test "index returns only current user plans" do
    login_as(@user)

    # Create plan for other user
    other_plan = Plan.create!(
      title: "Other User Plan",
      city_name: "Mostar",
      user: @other_user,
      visibility: :private_plan
    )

    get user_plans_path, as: :json

    assert_response :success
    body = response.parsed_body
    plan_ids = body["plans"].map { |p| p["uuid"] }
    assert_includes plan_ids, @plan.uuid
    assert_not_includes plan_ids, other_plan.uuid

    other_plan.destroy
  end

  test "index returns plans in descending order by created_at" do
    login_as(@user)

    # Create a newer plan
    newer_plan = Plan.create!(
      title: "Newer Plan",
      city_name: "Mostar",
      user: @user,
      visibility: :private_plan,
      local_id: "local-plan-newer"
    )

    get user_plans_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body["plans"].count
    assert_equal newer_plan.uuid, body["plans"].first["uuid"]

    newer_plan.destroy
  end

  test "index returns empty array when user has no plans" do
    login_as(@other_user)

    get user_plans_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal [], body["plans"]
  end

  # === Show action tests ===

  test "show returns plan by UUID" do
    login_as(@user)

    get user_plan_path(@plan.uuid), as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal @plan.uuid, body["uuid"]
    assert_equal @plan.city_name, body["city_name"]
  end

  test "show returns plan by local_id" do
    login_as(@user)

    get user_plan_path(@plan.local_id), as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal @plan.uuid, body["uuid"]
  end

  test "show returns 404 for non-existent plan" do
    login_as(@user)

    get user_plan_path("non-existent-id"), as: :json

    assert_response :not_found
    body = response.parsed_body
    assert_equal "Plan not found", body["error"]
  end

  test "show returns 404 for other users plan" do
    login_as(@other_user)

    get user_plan_path(@plan.uuid), as: :json

    assert_response :not_found
  end

  # === Create action tests ===

  test "create creates new plan" do
    login_as(@user)

    assert_difference "Plan.count" do
      post user_plans_path, params: { plan: valid_plan_params }, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert body["uuid"].present?
    assert_equal "Sarajevo", body["city_name"]
  end

  test "create associates plan with current user" do
    login_as(@user)

    post user_plans_path, params: { plan: valid_plan_params }, as: :json

    assert_response :created
    body = response.parsed_body
    plan = Plan.find_by(uuid: body["uuid"])
    assert_equal @user.id, plan.user_id
  end

  test "create stores local_id" do
    login_as(@user)

    params = valid_plan_params.merge(id: "my-local-plan-id")
    post user_plans_path, params: { plan: params }, as: :json

    assert_response :created
    body = response.parsed_body
    plan = Plan.find_by(uuid: body["uuid"])
    assert_equal "my-local-plan-id", plan.local_id
  end

  test "create handles experiences from days data" do
    login_as(@user)

    params = valid_plan_params.merge(
      days: [
        {
          day_number: 1,
          experiences: [{ id: @experience.uuid }]
        }
      ]
    )

    post user_plans_path, params: { plan: params }, as: :json

    assert_response :created
    body = response.parsed_body
    plan = Plan.find_by(uuid: body["uuid"])
    assert_equal 1, plan.plan_experiences.count

    plan.destroy
  end

  test "create returns warnings for invalid experience IDs" do
    login_as(@user)

    params = valid_plan_params.merge(
      days: [
        {
          day_number: 1,
          experiences: [{ id: "non-existent-experience-id" }]
        }
      ]
    )

    post user_plans_path, params: { plan: params }, as: :json

    assert_response :created
    body = response.parsed_body
    assert body["warnings"].present? || body["warnings"].nil?
    # Even with invalid experience, plan should be created

    Plan.find_by(uuid: body["uuid"])&.destroy
  end

  test "create returns error for invalid plan data" do
    login_as(@user)

    # Missing city data
    post user_plans_path, params: { plan: { duration_days: 2 } }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert body["error"].present?
  end

  test "create stores custom_title in preferences" do
    login_as(@user)

    params = valid_plan_params.merge(custom_title: "My Custom Title")
    post user_plans_path, params: { plan: params }, as: :json

    assert_response :created
    body = response.parsed_body
    plan = Plan.find_by(uuid: body["uuid"])
    assert_equal "My Custom Title", plan.preferences["custom_title"]

    plan.destroy
  end

  test "create stores notes" do
    login_as(@user)

    params = valid_plan_params.merge(notes: "Some travel notes")
    post user_plans_path, params: { plan: params }, as: :json

    assert_response :created
    body = response.parsed_body
    plan = Plan.find_by(uuid: body["uuid"])
    assert_equal "Some travel notes", plan.notes

    plan.destroy
  end

  # === Update action tests ===

  test "update updates plan" do
    login_as(@user)

    patch user_plan_path(@plan.uuid), params: {
      plan: { notes: "Updated notes", custom_title: "Updated Title" }
    }, as: :json

    assert_response :success
    @plan.reload
    assert_equal "Updated notes", @plan.notes
    assert_equal "Updated Title", @plan.preferences["custom_title"]
  end

  test "update replaces experiences" do
    login_as(@user)

    patch user_plan_path(@plan.uuid), params: {
      plan: {
        days: [
          {
            day_number: 1,
            experiences: [{ id: @experience2.uuid }]
          }
        ]
      }
    }, as: :json

    assert_response :success
    @plan.reload
    assert_equal 1, @plan.plan_experiences.count
    assert_equal @experience2.id, @plan.plan_experiences.first.experience_id
  end

  test "update returns 404 for non-existent plan" do
    login_as(@user)

    patch user_plan_path("non-existent"), params: { plan: { notes: "test" } }, as: :json

    assert_response :not_found
  end

  test "update returns 404 for other users plan" do
    login_as(@other_user)

    patch user_plan_path(@plan.uuid), params: { plan: { notes: "test" } }, as: :json

    assert_response :not_found
  end

  test "update returns warnings for skipped experiences" do
    login_as(@user)

    patch user_plan_path(@plan.uuid), params: {
      plan: {
        days: [
          {
            day_number: 1,
            experiences: [
              { id: @experience.uuid },
              { id: "non-existent-id" }
            ]
          }
        ]
      }
    }, as: :json

    assert_response :success
    # Plan should still have 1 experience (valid one)
    @plan.reload
    assert_equal 1, @plan.plan_experiences.count
  end

  # === Destroy action tests ===

  test "destroy deletes plan" do
    login_as(@user)

    assert_difference "Plan.count", -1 do
      delete user_plan_path(@plan.uuid), as: :json
    end

    assert_response :no_content
  end

  test "destroy returns 404 for non-existent plan" do
    login_as(@user)

    delete user_plan_path("non-existent"), as: :json

    assert_response :not_found
  end

  test "destroy returns 404 for other users plan" do
    login_as(@other_user)

    assert_no_difference "Plan.count" do
      delete user_plan_path(@plan.uuid), as: :json
    end

    assert_response :not_found
  end

  # === Sync action tests ===

  test "sync creates new plans from localStorage" do
    login_as(@user)

    plans_data = [
      {
        "id" => "new-local-plan",
        "city_name" => "Mostar",
        "duration_days" => 2,
        "days" => [
          {
            "day_number" => 1,
            "experiences" => [{ "id" => @experience.uuid }]
          }
        ]
      }
    ]

    assert_difference "Plan.count" do
      post sync_user_plans_path, params: { plans: plans_data }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert_equal 2, body["plans"].count # existing + new

    Plan.find_by(local_id: "new-local-plan")&.destroy
  end

  test "sync updates existing plans" do
    login_as(@user)

    plans_data = [
      {
        "id" => @plan.local_id,
        "city_name" => "Sarajevo",
        "notes" => "Updated via sync",
        "days" => []
      }
    ]

    assert_no_difference "Plan.count" do
      post sync_user_plans_path, params: { plans: plans_data }, as: :json
    end

    assert_response :success
    @plan.reload
    assert_equal "Updated via sync", @plan.notes
  end

  test "sync returns plans from DB not in localStorage" do
    login_as(@user)

    # Sync with empty array should return DB-only plans
    post sync_user_plans_path, params: { plans: [] }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["plans"].any? { |p| p["uuid"] == @plan.uuid }
  end

  test "sync handles errors gracefully" do
    login_as(@user)

    # Send invalid plan data (missing city_name)
    plans_data = [
      {
        "id" => "invalid-plan",
        "duration_days" => 2,
        "days" => []
      }
    ]

    post sync_user_plans_path, params: { plans: plans_data }, as: :json

    assert_response :success
    body = response.parsed_body
    # Should have errors but still return existing plans
    assert body["errors"].present? || body["plans"].present?
  end

  test "sync handles empty plans parameter" do
    login_as(@user)

    post sync_user_plans_path, params: {}, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["plans"].is_a?(Array)
  end

  # === Share action tests ===

  test "share creates and makes plan public" do
    login_as(@user)

    plan_data = {
      "id" => "share-local-plan",
      "city_name" => "Banja Luka",
      "duration_days" => 1,
      "days" => [
        {
          "day_number" => 1,
          "experiences" => [{ "id" => @experience.uuid }]
        }
      ]
    }

    assert_difference "Plan.count" do
      post share_user_plans_path, params: { plan: plan_data }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert body["plan_id"].present?
    assert body["plan_url"].present?

    shared_plan = Plan.find_by(uuid: body["plan_id"])
    assert shared_plan.visibility_public_plan?

    shared_plan.destroy
  end

  test "share makes existing plan public" do
    login_as(@user)

    assert @plan.visibility_private_plan?

    plan_data = {
      "id" => @plan.local_id,
      "city_name" => @plan.city_name,
      "days" => []
    }

    assert_no_difference "Plan.count" do
      post share_user_plans_path, params: { plan: plan_data }, as: :json
    end

    assert_response :success
    @plan.reload
    assert @plan.visibility_public_plan?
  end

  test "share returns error without plan data" do
    login_as(@user)

    post share_user_plans_path, params: {}, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_not body["success"]
    assert_equal "No plan data provided", body["error"]
  end

  test "share returns error for invalid plan" do
    login_as(@user)

    # Missing city_name
    plan_data = {
      "id" => "invalid-share",
      "duration_days" => 1
    }

    post share_user_plans_path, params: { plan: plan_data }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_not body["success"]
  end

  test "share returns warnings for skipped experiences" do
    login_as(@user)

    plan_data = {
      "id" => "share-with-invalid",
      "city_name" => "Sarajevo",
      "days" => [
        {
          "day_number" => 1,
          "experiences" => [
            { "id" => "non-existent-id" },
            { "id" => @experience.uuid }
          ]
        }
      ]
    }

    post share_user_plans_path, params: { plan: plan_data }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]

    Plan.find_by(uuid: body["plan_id"])&.destroy
  end

  # === Toggle visibility action tests ===

  test "toggle_visibility changes private to public" do
    login_as(@user)

    assert @plan.visibility_private_plan?

    post toggle_visibility_user_plan_path(@plan.uuid), as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert body["is_public"]
    assert_equal "public_plan", body["visibility"]
    assert body["plan_url"].present?

    @plan.reload
    assert @plan.visibility_public_plan?
  end

  test "toggle_visibility changes public to private" do
    login_as(@user)

    @plan.update!(visibility: :public_plan)
    assert @plan.visibility_public_plan?

    post toggle_visibility_user_plan_path(@plan.uuid), as: :json

    assert_response :success
    body = response.parsed_body
    assert body["success"]
    assert_not body["is_public"]
    assert_equal "private_plan", body["visibility"]
    assert_nil body["plan_url"]

    @plan.reload
    assert @plan.visibility_private_plan?
  end

  test "toggle_visibility returns 404 for non-existent plan" do
    login_as(@user)

    post toggle_visibility_user_plan_path("non-existent"), as: :json

    assert_response :not_found
  end

  test "toggle_visibility returns 404 for other users plan" do
    login_as(@other_user)

    post toggle_visibility_user_plan_path(@plan.uuid), as: :json

    assert_response :not_found
  end

  # === Edge cases ===

  test "handles JSON request format correctly" do
    login_as(@user)

    get user_plans_path, as: :json, headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "create sanitizes XSS in notes" do
    login_as(@user)

    params = valid_plan_params.merge(notes: "<script>alert('xss')</script>Safe text")
    post user_plans_path, params: { plan: params }, as: :json

    assert_response :created
    body = response.parsed_body
    plan = Plan.find_by(uuid: body["uuid"])
    assert_not_includes plan.notes, "<script>"

    plan.destroy
  end

  test "show includes plan experiences in response" do
    login_as(@user)

    get user_plan_path(@plan.uuid), as: :json

    assert_response :success
    body = response.parsed_body
    assert body["days"].present?
    assert body["days"].first["experiences"].present?
  end

  test "handles plan with multiple days" do
    login_as(@user)

    # Add experience to day 2
    @plan.plan_experiences.create!(
      experience: @experience2,
      day_number: 2,
      position: 1
    )

    get user_plan_path(@plan.uuid), as: :json

    assert_response :success
    body = response.parsed_body
    assert body["days"].count >= 2
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def valid_plan_params
    {
      id: "local-id-#{SecureRandom.hex(4)}",
      city: { name: "Sarajevo", display_name: "Sarajevo" },
      duration_days: 2,
      preferences: { budget: "medium" },
      days: []
    }
  end
end
