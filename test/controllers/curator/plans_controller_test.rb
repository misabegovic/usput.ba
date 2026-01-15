# frozen_string_literal: true

require "test_helper"

class Curator::PlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      username: "test_admin_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :admin
    )
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

    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 60
    )
    @experience.add_location(@location, position: 1)

    @plan = Plan.create!(
      title: "Test Plan",
      city_name: "Sarajevo",
      visibility: :public_plan,
      notes: "Test notes"
    )
    @plan.add_experience(@experience, day_number: 1)

    @private_plan = Plan.create!(
      title: "Private Plan",
      city_name: "Mostar",
      visibility: :private_plan
    )
  end

  teardown do
    ContentChange.destroy_all
    CuratorActivity.destroy_all
    PlanExperience.destroy_all
    Plan.destroy_all
    ExperienceLocation.destroy_all
    @experience&.destroy
    @location&.destroy
    @admin&.destroy
    @curator&.destroy
    @other_curator&.destroy
    @basic_user&.destroy
  end

  # === Authentication tests ===

  test "index requires login" do
    get curator_plans_path
    assert_redirected_to login_path
  end

  test "index requires curator role" do
    login_as(@basic_user)
    get curator_plans_path
    assert_redirected_to root_path
  end

  test "show requires login" do
    get curator_plan_path(@plan)
    assert_redirected_to login_path
  end

  test "show requires curator role" do
    login_as(@basic_user)
    get curator_plan_path(@plan)
    assert_redirected_to root_path
  end

  test "new requires login" do
    get new_curator_plan_path
    assert_redirected_to login_path
  end

  test "new requires curator role" do
    login_as(@basic_user)
    get new_curator_plan_path
    assert_redirected_to root_path
  end

  test "create requires login" do
    post curator_plans_path, params: { plan: { title: "New Plan" } }
    assert_redirected_to login_path
  end

  test "create requires curator role" do
    login_as(@basic_user)
    post curator_plans_path, params: { plan: { title: "New Plan" } }
    assert_redirected_to root_path
  end

  test "edit requires login" do
    get edit_curator_plan_path(@plan)
    assert_redirected_to login_path
  end

  test "edit requires curator role" do
    login_as(@basic_user)
    get edit_curator_plan_path(@plan)
    assert_redirected_to root_path
  end

  test "update requires login" do
    patch curator_plan_path(@plan), params: { plan: { title: "Updated" } }
    assert_redirected_to login_path
  end

  test "update requires curator role" do
    login_as(@basic_user)
    patch curator_plan_path(@plan), params: { plan: { title: "Updated" } }
    assert_redirected_to root_path
  end

  test "destroy requires login" do
    delete curator_plan_path(@plan)
    assert_redirected_to login_path
  end

  test "destroy requires curator role" do
    login_as(@basic_user)
    delete curator_plan_path(@plan)
    assert_redirected_to root_path
  end

  # === Authorization: Curator can access ===

  test "curator can access index" do
    login_as(@curator)
    get curator_plans_path
    assert_response :success
  end

  test "admin can access index" do
    login_as(@admin)
    get curator_plans_path
    assert_response :success
  end

  # === Spam block tests ===

  test "spam blocked curator cannot access index" do
    @curator.block_for_spam!("Testing spam block")
    login_as(@curator)
    get curator_plans_path
    assert_redirected_to root_path
    assert_match(/blocked/i, flash[:alert])
  end

  # === Index action tests ===

  test "index shows all plans" do
    login_as(@curator)
    get curator_plans_path
    assert_response :success
    assert_match @plan.title, response.body
  end

  test "index filters by public visibility" do
    login_as(@curator)
    get curator_plans_path(visibility: "public")
    assert_response :success
    assert_match @plan.title, response.body
    assert_no_match @private_plan.title, response.body
  end

  test "index filters by private visibility" do
    login_as(@curator)
    get curator_plans_path(visibility: "private")
    assert_response :success
    assert_no_match @plan.title, response.body
    assert_match @private_plan.title, response.body
  end

  test "index filters by city name" do
    login_as(@curator)
    get curator_plans_path(city_name: "Sarajevo")
    assert_response :success
    assert_match @plan.title, response.body
    assert_no_match @private_plan.title, response.body
  end

  test "index searches by title" do
    login_as(@curator)
    get curator_plans_path(search: "Test")
    assert_response :success
    assert_match @plan.title, response.body
  end

  test "index search is case insensitive" do
    login_as(@curator)
    get curator_plans_path(search: "test")
    assert_response :success
    assert_match @plan.title, response.body
  end

  test "index paginates results" do
    login_as(@curator)
    get curator_plans_path(page: 1)
    assert_response :success
  end

  # === Show action tests ===

  test "show displays plan details" do
    login_as(@curator)
    get curator_plan_path(@plan)
    assert_response :success
    assert_match @plan.title, response.body
  end

  test "show finds plan by public_id (uuid)" do
    login_as(@curator)
    get curator_plan_path(@plan.uuid)
    assert_response :success
  end

  test "show returns 404 for non-existent plan" do
    login_as(@curator)
    get curator_plan_path("non-existent-uuid")
    assert_response :not_found
  end

  # === New action tests ===

  test "new shows form" do
    login_as(@curator)
    get new_curator_plan_path
    assert_response :success
  end

  # === Create action tests ===

  test "create creates proposal instead of direct plan" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Plan.count" do
        post curator_plans_path, params: {
          plan: {
            title: "New Curator Plan",
            city_name: "Banja Luka",
            visibility: "public_plan",
            notes: "Some notes"
          }
        }
      end
    end

    assert_redirected_to curator_plans_path

    proposal = ContentChange.last
    assert_equal :create_content, proposal.change_type.to_sym
    assert_equal "Plan", proposal.changeable_class
    assert_equal "New Curator Plan", proposal.proposed_data["title"]
    assert_equal "Banja Luka", proposal.proposed_data["city_name"]
    assert_equal @curator.id, proposal.proposed_data["user_id"]
    assert_equal @curator, proposal.user

    proposal.destroy
  end

  test "create records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      post curator_plans_path, params: {
        plan: {
          title: "Activity Test Plan",
          city_name: "Sarajevo"
        }
      }
    end

    activity = CuratorActivity.last
    assert_equal "proposal_created", activity.action
    assert_equal @curator, activity.user
    assert_equal "Plan", activity.metadata["type"]
    assert_equal "Activity Test Plan", activity.metadata["title"]

    ContentChange.last.destroy
  end

  # === Edit action tests ===

  test "edit shows form with plan data" do
    login_as(@curator)
    get edit_curator_plan_path(@plan)
    assert_response :success
    assert_match @plan.title, response.body
  end

  # === Update action tests ===

  test "update creates proposal instead of direct update" do
    login_as(@curator)

    original_title = @plan.title

    assert_difference "ContentChange.count", 1 do
      patch curator_plan_path(@plan), params: {
        plan: {
          title: "Updated Plan Title",
          notes: "Updated notes"
        }
      }
    end

    assert_redirected_to curator_plan_path(@plan)

    # Plan should NOT be updated directly
    @plan.reload
    assert_equal original_title, @plan.title

    # Proposal should be created
    proposal = ContentChange.last
    assert_equal :update_content, proposal.change_type.to_sym
    assert_equal @plan, proposal.changeable
    assert_equal "Updated Plan Title", proposal.proposed_data["title"]
    assert_equal @curator, proposal.user

    proposal.destroy
  end

  test "update records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      patch curator_plan_path(@plan), params: {
        plan: { title: "Updated for Activity" }
      }
    end

    activity = CuratorActivity.last
    # First update creates "proposal_updated"
    assert_includes ["proposal_updated", "proposal_contributed"], activity.action
    assert_equal @curator, activity.user

    ContentChange.last.destroy
  end

  test "update adds contribution to existing pending proposal" do
    # Create existing proposal from another curator
    existing_proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @plan,
      original_data: { "title" => @plan.title, "notes" => @plan.notes },
      proposed_data: { "title" => "Other curator's title", "notes" => @plan.notes }
    )

    login_as(@curator)

    assert_no_difference "ContentChange.count" do
      patch curator_plan_path(@plan), params: {
        plan: { notes: "Curator's additional notes" }
      }
    end

    assert_redirected_to curator_plan_path(@plan)

    # Check contribution was added
    existing_proposal.reload
    assert existing_proposal.contributions.exists?(user: @curator)

    existing_proposal.destroy
  end

  # === Destroy action tests ===

  test "destroy creates delete proposal instead of direct deletion" do
    login_as(@curator)

    plan_to_delete = Plan.create!(
      title: "Plan to Delete",
      city_name: "Trebinje"
    )

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Plan.count" do
        delete curator_plan_path(plan_to_delete)
      end
    end

    assert_redirected_to curator_plans_path

    proposal = ContentChange.last
    assert_equal :delete_content, proposal.change_type.to_sym
    assert_equal plan_to_delete, proposal.changeable
    assert_equal @curator, proposal.user

    proposal.destroy
    plan_to_delete.destroy
  end

  test "destroy records curator activity" do
    login_as(@curator)

    plan_to_delete = Plan.create!(
      title: "Activity Delete Plan",
      city_name: "Zenica"
    )

    assert_difference "CuratorActivity.count", 1 do
      delete curator_plan_path(plan_to_delete)
    end

    activity = CuratorActivity.last
    assert_equal "proposal_deleted", activity.action
    assert_equal @curator, activity.user
    assert_equal "Plan", activity.metadata["type"]

    ContentChange.last.destroy
    plan_to_delete.destroy
  end

  test "destroy adds contribution to existing pending proposal" do
    plan_to_delete = Plan.create!(
      title: "Plan with Existing Proposal",
      city_name: "Tuzla"
    )

    # Create existing update proposal from another curator
    existing_proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: plan_to_delete,
      original_data: { "title" => plan_to_delete.title },
      proposed_data: { "title" => "Updated title" }
    )

    login_as(@curator)

    assert_no_difference "ContentChange.count" do
      delete curator_plan_path(plan_to_delete)
    end

    assert_redirected_to curator_plans_path

    # Should convert to delete and add contribution
    existing_proposal.reload
    assert_equal :delete_content, existing_proposal.change_type.to_sym

    existing_proposal.destroy
    plan_to_delete.destroy
  end

  # === Edge cases ===

  test "handles plan with all fields" do
    login_as(@curator)

    post curator_plans_path, params: {
      plan: {
        title: "Complete Plan",
        notes: "Detailed notes",
        city_name: "Sarajevo",
        visibility: "private_plan",
        start_date: Date.today,
        end_date: Date.today + 5.days
      }
    }

    assert_redirected_to curator_plans_path

    proposal = ContentChange.last
    assert_equal "Complete Plan", proposal.proposed_data["title"]
    assert_equal "Detailed notes", proposal.proposed_data["notes"]
    assert_equal "Sarajevo", proposal.proposed_data["city_name"]
    assert_equal "private_plan", proposal.proposed_data["visibility"]
    assert proposal.proposed_data["start_date"].present?
    assert proposal.proposed_data["end_date"].present?

    proposal.destroy
  end

  test "index with multiple filters" do
    login_as(@curator)
    get curator_plans_path(visibility: "public", city_name: "Sarajevo", search: "Test")
    assert_response :success
    assert_match @plan.title, response.body
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
