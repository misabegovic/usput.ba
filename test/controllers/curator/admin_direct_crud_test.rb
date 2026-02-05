# frozen_string_literal: true

require "test_helper"

class Curator::AdminDirectCrudTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      username: "admin_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :admin
    )

    @admin_without_flag = User.create!(
      username: "admin_no_flag_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :admin
    )

    @curator = User.create!(
      username: "curator_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )

    # Enable the Flipper flag for @admin only
    Flipper.enable_actor(:curator_edit_delete, @admin)

    # Create existing resources for update/delete tests
    @location = Location.create!(
      name: "Test Location",
      description: "Test description",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @experience = Experience.create!(
      title: "Test Experience",
      description: "Test experience description",
      experience_category: ExperienceCategory.first || ExperienceCategory.create!(
        key: "culture",
        name: "Culture",
        active: true,
        position: 1
      )
    )

    @plan = Plan.create!(
      title: "Test Plan",
      city_name: "Sarajevo",
      visibility: :public_plan,
      user: @curator
    )

    # Create location category for tests
    @category = LocationCategory.find_or_create_by!(key: "attraction") do |c|
      c.name = "Attraction"
      c.active = true
      c.position = 1
    end
  end

  teardown do
    # Clean up content changes and activities first (foreign keys)
    ContentChange.where(user: [ @admin, @admin_without_flag, @curator ]).destroy_all
    ContentChange.where(changeable: [ @location, @experience, @plan ]).destroy_all
    CuratorActivity.where(user: [ @admin, @admin_without_flag, @curator ]).destroy_all

    # Clean up resources
    @location&.destroy
    @experience&.destroy
    @plan&.destroy

    # Clean up users
    @admin&.destroy
    @admin_without_flag&.destroy
    @curator&.destroy

    # Disable Flipper flag
    Flipper.disable(:curator_edit_delete)
  end

  # ==========================================================================
  # LocationsController - Admin Direct CRUD Tests
  # ==========================================================================

  test "admin with flag creates location directly without proposal" do
    login_as(@admin)

    assert_no_difference "ContentChange.count" do
      assert_difference "Location.count", 1 do
        post curator_locations_path, params: {
          location: {
            name: "Admin Direct Location",
            description: "Created directly by admin",
            city: "Mostar",
            lat: 43.3438,
            lng: 17.8078,
            location_type: "place"
          }
        }
      end
    end

    assert_redirected_to curator_location_path(Location.last)
    follow_redirect!
    assert_response :success

    # Verify location was created
    location = Location.last
    assert_equal "Admin Direct Location", location.name
    assert_equal "Mostar", location.city

    # Verify CuratorActivity was recorded with correct action
    activity = CuratorActivity.last
    assert_equal "resource_created", activity.action
    assert_equal @admin, activity.user
    assert_equal location, activity.recordable
    assert_equal "Location", activity.metadata["type"]
    assert_equal "Admin Direct Location", activity.metadata["name"]

    # Clean up
    location.destroy
  end

  test "admin with flag updates location directly without proposal" do
    login_as(@admin)
    original_name = @location.name

    assert_no_difference "ContentChange.count" do
      patch curator_location_path(@location), params: {
        location: {
          name: "Updated by Admin",
          description: "Updated description"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)

    # Verify location was updated directly
    @location.reload
    assert_equal "Updated by Admin", @location.name
    assert_equal "Updated description", @location.description
    assert_not_equal original_name, @location.name

    # Verify CuratorActivity was recorded
    activity = CuratorActivity.last
    assert_equal "resource_updated", activity.action
    assert_equal @admin, activity.user
    assert_equal @location, activity.recordable
  end

  test "admin with flag deletes location directly without proposal" do
    login_as(@admin)
    location_to_delete = Location.create!(
      name: "To Delete",
      city: "Zenica",
      lat: 44.2037,
      lng: 17.9078,
      location_type: :place
    )

    assert_no_difference "ContentChange.count" do
      assert_difference "Location.count", -1 do
        delete curator_location_path(location_to_delete)
      end
    end

    assert_redirected_to curator_locations_path

    # Verify CuratorActivity was recorded
    activity = CuratorActivity.last
    assert_equal "resource_deleted", activity.action
    assert_equal @admin, activity.user
    assert_nil activity.recordable # Resource deleted, so nil
    assert_equal "Location", activity.metadata["type"]
    assert_equal "To Delete", activity.metadata["name"]
  end

  # ==========================================================================
  # ExperiencesController - Admin Direct CRUD Tests
  # ==========================================================================

  test "admin with flag creates experience directly without proposal" do
    login_as(@admin)

    assert_no_difference "ContentChange.count" do
      assert_difference "Experience.count", 1 do
        post curator_experiences_path, params: {
          experience: {
            title: "Admin Direct Experience",
            description: "Created directly by admin",
            experience_category_id: @experience.experience_category_id
          }
        }
      end
    end

    assert_redirected_to curator_experience_path(Experience.last)

    # Verify experience was created
    experience = Experience.last
    assert_equal "Admin Direct Experience", experience.title

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "resource_created", activity.action
    assert_equal @admin, activity.user
    assert_equal experience, activity.recordable
    assert_equal "Experience", activity.metadata["type"]

    # Clean up
    experience.destroy
  end

  test "admin with flag updates experience directly without proposal" do
    login_as(@admin)

    assert_no_difference "ContentChange.count" do
      patch curator_experience_path(@experience), params: {
        experience: {
          title: "Updated Experience by Admin",
          description: "Updated by admin"
        }
      }
    end

    assert_redirected_to curator_experience_path(@experience)

    # Verify experience was updated directly
    @experience.reload
    assert_equal "Updated Experience by Admin", @experience.title

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "resource_updated", activity.action
    assert_equal @admin, activity.user
    assert_equal @experience, activity.recordable
  end

  test "admin with flag deletes experience directly without proposal" do
    login_as(@admin)
    experience_to_delete = Experience.create!(
      title: "Experience to Delete",
      description: "Will be deleted",
      experience_category: @experience.experience_category
    )

    assert_no_difference "ContentChange.count" do
      assert_difference "Experience.count", -1 do
        delete curator_experience_path(experience_to_delete)
      end
    end

    assert_redirected_to curator_experiences_path

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "resource_deleted", activity.action
    assert_equal @admin, activity.user
    assert_nil activity.recordable
    assert_equal "Experience", activity.metadata["type"]
    assert_equal "Experience to Delete", activity.metadata["title"]
  end

  # ==========================================================================
  # PlansController - Admin Direct CRUD Tests
  # ==========================================================================

  test "admin with flag creates plan directly without proposal" do
    login_as(@admin)

    assert_no_difference "ContentChange.count" do
      assert_difference "Plan.count", 1 do
        post curator_plans_path, params: {
          plan: {
            title: "Admin Direct Plan",
            city_name: "Tuzla",
            visibility: "public_plan"
          }
        }
      end
    end

    assert_redirected_to curator_plan_path(Plan.last)

    # Verify plan was created
    plan = Plan.last
    assert_equal "Admin Direct Plan", plan.title
    assert_equal "Tuzla", plan.city_name

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "resource_created", activity.action
    assert_equal @admin, activity.user
    assert_equal plan, activity.recordable
    assert_equal "Plan", activity.metadata["type"]

    # Clean up
    plan.destroy
  end

  test "admin with flag updates plan directly without proposal" do
    login_as(@admin)

    assert_no_difference "ContentChange.count" do
      patch curator_plan_path(@plan), params: {
        plan: {
          title: "Updated Plan by Admin",
          city_name: "Updated City"
        }
      }
    end

    assert_redirected_to curator_plan_path(@plan)

    # Verify plan was updated directly
    @plan.reload
    assert_equal "Updated Plan by Admin", @plan.title

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "resource_updated", activity.action
    assert_equal @admin, activity.user
    assert_equal @plan, activity.recordable
  end

  test "admin with flag deletes plan directly without proposal" do
    login_as(@admin)
    plan_to_delete = Plan.create!(
      title: "Plan to Delete",
      city_name: "Banja Luka",
      visibility: :public_plan,
      user: @admin
    )

    assert_no_difference "ContentChange.count" do
      assert_difference "Plan.count", -1 do
        delete curator_plan_path(plan_to_delete)
      end
    end

    assert_redirected_to curator_plans_path

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "resource_deleted", activity.action
    assert_equal @admin, activity.user
    assert_nil activity.recordable
    assert_equal "Plan", activity.metadata["type"]
    assert_equal "Plan to Delete", activity.metadata["title"]
  end

  # ==========================================================================
  # Curator still creates proposals (flag disabled)
  # ==========================================================================

  test "curator without flag still creates location proposals" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Location.count" do
        post curator_locations_path, params: {
          location: {
            name: "Curator Proposed Location",
            city: "Bijeljina",
            lat: 44.7597,
            lng: 19.2144,
            location_type: "place"
          }
        }
      end
    end

    assert_redirected_to curator_locations_path

    # Verify proposal was created
    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal "Location", proposal.changeable_class
    assert_equal @curator, proposal.user

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "proposal_created", activity.action
    assert_equal @curator, activity.user
    assert_equal proposal, activity.recordable

    # Clean up
    proposal.destroy
  end

  test "curator without flag still creates update proposals for locations" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      patch curator_location_path(@location), params: {
        location: {
          name: "Curator Updated Name"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)

    # Verify location was NOT updated
    @location.reload
    assert_not_equal "Curator Updated Name", @location.name

    # Verify proposal was created
    proposal = ContentChange.last
    assert_equal "update_content", proposal.change_type
    assert_equal @location, proposal.changeable

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_includes [ "proposal_updated", "proposal_contributed" ], activity.action

    # Clean up
    proposal.destroy
  end

  test "curator without flag still creates delete proposals for locations" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Location.count" do
        delete curator_location_path(@location)
      end
    end

    assert_redirected_to curator_locations_path

    # Verify location was NOT deleted
    assert Location.exists?(@location.id)

    # Verify delete proposal was created
    proposal = ContentChange.last
    assert_equal "delete_content", proposal.change_type
    assert_equal @location, proposal.changeable

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "proposal_deleted", activity.action

    # Clean up
    proposal.destroy
  end

  test "curator without flag still creates experience proposals" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Experience.count" do
        post curator_experiences_path, params: {
          experience: {
            title: "Curator Proposed Experience",
            description: "Proposed by curator",
            experience_category_id: @experience.experience_category_id
          }
        }
      end
    end

    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal "Experience", proposal.changeable_class

    # Clean up
    proposal.destroy
  end

  test "curator without flag still creates plan proposals" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Plan.count" do
        post curator_plans_path, params: {
          plan: {
            title: "Curator Proposed Plan",
            city_name: "Mostar",
            visibility: "public_plan"
          }
        }
      end
    end

    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal "Plan", proposal.changeable_class

    # Clean up
    proposal.destroy
  end

  # ==========================================================================
  # Admin without flag creates proposals
  # ==========================================================================

  test "admin without flag still creates location proposals" do
    login_as(@admin_without_flag)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Location.count" do
        post curator_locations_path, params: {
          location: {
            name: "Admin No Flag Proposed Location",
            city: "Prijedor",
            lat: 44.9799,
            lng: 16.7089,
            location_type: "place"
          }
        }
      end
    end

    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal @admin_without_flag, proposal.user

    # Verify CuratorActivity
    activity = CuratorActivity.last
    assert_equal "proposal_created", activity.action

    # Clean up
    proposal.destroy
  end

  test "admin without flag still creates update proposals" do
    login_as(@admin_without_flag)

    assert_difference "ContentChange.count", 1 do
      patch curator_location_path(@location), params: {
        location: {
          name: "Admin No Flag Update"
        }
      }
    end

    # Verify location was NOT updated
    @location.reload
    assert_not_equal "Admin No Flag Update", @location.name

    proposal = ContentChange.last
    assert_equal "update_content", proposal.change_type

    # Clean up
    proposal.destroy
  end

  test "admin without flag still creates delete proposals" do
    login_as(@admin_without_flag)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Location.count" do
        delete curator_location_path(@location)
      end
    end

    # Verify location was NOT deleted
    assert Location.exists?(@location.id)

    proposal = ContentChange.last
    assert_equal "delete_content", proposal.change_type

    # Clean up
    proposal.destroy
  end

  test "admin without flag still creates experience proposals" do
    login_as(@admin_without_flag)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Experience.count" do
        post curator_experiences_path, params: {
          experience: {
            title: "Admin No Flag Experience",
            description: "Proposed",
            experience_category_id: @experience.experience_category_id
          }
        }
      end
    end

    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal @admin_without_flag, proposal.user

    # Clean up
    proposal.destroy
  end

  test "admin without flag still creates plan proposals" do
    login_as(@admin_without_flag)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Plan.count" do
        post curator_plans_path, params: {
          plan: {
            title: "Admin No Flag Plan",
            city_name: "Livno",
            visibility: "public_plan"
          }
        }
      end
    end

    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal @admin_without_flag, proposal.user

    # Clean up
    proposal.destroy
  end

  # ==========================================================================
  # Edge Cases and Validation
  # ==========================================================================

  test "admin direct create with invalid data renders form" do
    login_as(@admin)

    assert_no_difference [ "Location.count", "ContentChange.count" ] do
      post curator_locations_path, params: {
        location: {
          name: "", # Invalid - blank name
          city: "Test"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "admin direct update with invalid data renders form" do
    login_as(@admin)

    patch curator_location_path(@location), params: {
      location: {
        name: "" # Invalid - blank name
      }
    }

    assert_response :unprocessable_entity

    # Verify location was not updated
    @location.reload
    assert_not_equal "", @location.name
  end

  test "admin_direct_crud? helper method works correctly" do
    # Admin with flag
    login_as(@admin)
    get curator_locations_path
    assert_response :success
    # The helper is called internally, we're just verifying no errors

    # Admin without flag
    login_as(@admin_without_flag)
    get curator_locations_path
    assert_response :success

    # Curator
    login_as(@curator)
    get curator_locations_path
    assert_response :success
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
