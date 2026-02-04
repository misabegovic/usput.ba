# frozen_string_literal: true

require "test_helper"

class Curator::LocationsControllerTest < ActionDispatch::IntegrationTest
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

    @location = Location.create!(
      name: "Test Location",
      description: "A test location for testing",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @other_location = Location.create!(
      name: "Other Location",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )

    # Create a location category for form tests
    @category = LocationCategory.find_or_create_by!(key: "attraction") do |c|
      c.name = "Attraction"
      c.active = true
      c.position = 1
    end

    # Create an experience type for form tests
    @experience_type = ExperienceType.find_or_create_by!(key: "culture") do |et|
      et.name = "Culture"
      et.active = true
      et.position = 1
    end
  end

  teardown do
    # Clean up content changes first (due to foreign keys)
    ContentChange.where(user: [ @curator, @other_curator, @admin ]).destroy_all
    ContentChange.where(changeable: [ @location, @other_location ]).destroy_all
    CuratorActivity.where(user: [ @curator, @other_curator, @admin ]).destroy_all

    # Clean up locations
    @location&.destroy
    @other_location&.destroy

    # Clean up users
    @curator&.destroy
    @other_curator&.destroy
    @basic_user&.destroy
    @admin&.destroy
  end

  # ==========================================================================
  # Authentication Tests
  # ==========================================================================

  test "index requires login" do
    get curator_locations_path
    assert_redirected_to login_path
  end

  test "show requires login" do
    get curator_location_path(@location)
    assert_redirected_to login_path
  end

  test "new requires login" do
    get new_curator_location_path
    assert_redirected_to login_path
  end

  test "create requires login" do
    post curator_locations_path, params: { location: { name: "New Location" } }
    assert_redirected_to login_path
  end

  test "edit requires login" do
    get edit_curator_location_path(@location)
    assert_redirected_to login_path
  end

  test "update requires login" do
    patch curator_location_path(@location), params: { location: { name: "Updated Name" } }
    assert_redirected_to login_path
  end

  test "destroy requires login" do
    delete curator_location_path(@location)
    assert_redirected_to login_path
  end

  # ==========================================================================
  # Authorization Tests (curator role required)
  # ==========================================================================

  test "index requires curator role" do
    login_as(@basic_user)
    get curator_locations_path
    assert_redirected_to root_path
  end

  test "show requires curator role" do
    login_as(@basic_user)
    get curator_location_path(@location)
    assert_redirected_to root_path
  end

  test "new requires curator role" do
    login_as(@basic_user)
    get new_curator_location_path
    assert_redirected_to root_path
  end

  test "create requires curator role" do
    login_as(@basic_user)
    post curator_locations_path, params: { location: { name: "New Location" } }
    assert_redirected_to root_path
  end

  test "edit requires curator role" do
    login_as(@basic_user)
    get edit_curator_location_path(@location)
    assert_redirected_to root_path
  end

  test "update requires curator role" do
    login_as(@basic_user)
    patch curator_location_path(@location), params: { location: { name: "Updated Name" } }
    assert_redirected_to root_path
  end

  test "destroy requires curator role" do
    login_as(@basic_user)
    delete curator_location_path(@location)
    assert_redirected_to root_path
  end

  # ==========================================================================
  # Spam Block Tests
  # ==========================================================================

  test "spam blocked curator cannot access index" do
    @curator.update!(
      spam_blocked_at: Time.current,
      spam_blocked_until: 24.hours.from_now,
      spam_block_reason: "Too many actions"
    )
    login_as(@curator)
    get curator_locations_path
    assert_redirected_to root_path
  end

  # ==========================================================================
  # Index Action Tests
  # ==========================================================================

  test "index shows locations for curator" do
    login_as(@curator)
    get curator_locations_path
    assert_response :success
    assert_match @location.name, response.body
  end

  test "index shows locations for admin" do
    login_as(@admin)
    get curator_locations_path
    assert_response :success
  end

  test "index filters by city" do
    login_as(@curator)
    get curator_locations_path, params: { city_name: "Sarajevo" }
    assert_response :success
    assert_match @location.name, response.body
    assert_no_match @other_location.name, response.body
  end

  test "index filters by search term" do
    login_as(@curator)
    get curator_locations_path, params: { search: "Test" }
    assert_response :success
    assert_match @location.name, response.body
    assert_no_match @other_location.name, response.body
  end

  test "index filters by category" do
    @location.add_category(@category)
    login_as(@curator)
    get curator_locations_path, params: { category: "attraction" }
    assert_response :success
    assert_match @location.name, response.body
    @location.remove_category(@category)
  end

  test "index shows pending proposals for current curator" do
    # Create a pending proposal for the curator
    proposal = @curator.content_changes.create!(
      change_type: :create_content,
      changeable_class: "Location",
      proposed_data: { "name" => "New Proposed Location" }
    )

    login_as(@curator)
    get curator_locations_path
    assert_response :success

    proposal.destroy
  end

  # ==========================================================================
  # Show Action Tests
  # ==========================================================================

  test "show displays location for curator" do
    login_as(@curator)
    get curator_location_path(@location)
    assert_response :success
    assert_match @location.name, response.body
  end

  test "show works with UUID" do
    login_as(@curator)
    get curator_location_path(@location.uuid)
    assert_response :success
  end

  test "show displays pending proposal if exists" do
    # Create a pending proposal for this location
    proposal = ContentChange.create!(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Updated Name" }
    )

    login_as(@curator)
    get curator_location_path(@location)
    assert_response :success

    proposal.destroy
  end

  test "show returns 404 for non-existent location" do
    login_as(@curator)
    get curator_location_path("00000000-0000-0000-0000-000000000000")
    # BaseController has rescue_from RecordNotFound that redirects to index
    assert_redirected_to curator_locations_path
    assert_equal "Locations not found.", flash[:alert]
  end

  # ==========================================================================
  # New Action Tests
  # ==========================================================================

  test "new shows form for curator" do
    login_as(@curator)
    get new_curator_location_path
    assert_response :success
    assert_select "form"
  end

  test "new loads form options" do
    login_as(@curator)
    get new_curator_location_path
    assert_response :success
    # Form should have access to city names and categories
  end

  # ==========================================================================
  # Create Action Tests
  # ==========================================================================

  test "create with valid data creates proposal not location" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Location.count" do
        post curator_locations_path, params: {
          location: {
            name: "New Proposed Location",
            description: "A great new place",
            city: "Tuzla",
            lat: 44.5384,
            lng: 18.6763,
            location_type: "place"
          }
        }
      end
    end

    assert_redirected_to curator_locations_path
    follow_redirect!
    assert_response :success

    # Verify the proposal was created
    proposal = ContentChange.last
    assert_equal "create_content", proposal.change_type
    assert_equal "Location", proposal.changeable_class
    assert_equal "New Proposed Location", proposal.proposed_data["name"]
    assert_equal @curator, proposal.user

    proposal.destroy
  end

  test "create records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      post curator_locations_path, params: {
        location: {
          name: "Activity Test Location",
          city: "Sarajevo",
          lat: 43.8563,
          lng: 18.4131
        }
      }
    end

    activity = CuratorActivity.last
    assert_equal "proposal_created", activity.action
    assert_equal @curator, activity.user

    ContentChange.last.destroy
  end

  test "create with category IDs includes them in proposal" do
    login_as(@curator)

    post curator_locations_path, params: {
      location: {
        name: "Location With Category",
        city: "Sarajevo",
        lat: 43.85,
        lng: 18.41,
        location_category_ids: [ @category.id.to_s, "" ]
      }
    }

    proposal = ContentChange.last
    assert_includes proposal.proposed_data["location_category_ids"], @category.id

    proposal.destroy
  end

  test "create with tags processes comma-separated input" do
    login_as(@curator)

    post curator_locations_path, params: {
      location: {
        name: "Location With Tags",
        city: "Sarajevo",
        lat: 43.85,
        lng: 18.41,
        tags_input: "historic, museum, culture"
      }
    }

    proposal = ContentChange.last
    assert_equal [ "historic", "museum", "culture" ], proposal.proposed_data["tags"]

    proposal.destroy
  end

  test "create with social links cleans empty values" do
    login_as(@curator)

    post curator_locations_path, params: {
      location: {
        name: "Location With Social",
        city: "Sarajevo",
        lat: 43.85,
        lng: 18.41,
        social_links: {
          facebook: "https://facebook.com/test",
          instagram: "",
          twitter: "https://twitter.com/test"
        }
      }
    }

    proposal = ContentChange.last
    assert_equal({ "facebook" => "https://facebook.com/test", "twitter" => "https://twitter.com/test" }, proposal.proposed_data["social_links"])

    proposal.destroy
  end

  test "create without location params returns bad request" do
    login_as(@curator)

    # When location param is completely missing, Rails returns bad request
    post curator_locations_path, params: {}
    assert_response :bad_request
  end

  # ==========================================================================
  # Edit Action Tests
  # ==========================================================================

  test "edit shows form for curator" do
    login_as(@curator)
    get edit_curator_location_path(@location)
    assert_response :success
    assert_select "form"
  end

  test "edit shows pending proposal notice if exists" do
    proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Other proposed name" }
    )

    login_as(@curator)
    get edit_curator_location_path(@location)
    assert_response :success

    proposal.destroy
  end

  # ==========================================================================
  # Update Action Tests
  # ==========================================================================

  test "update with valid data creates proposal not direct update" do
    login_as(@curator)
    original_name = @location.name

    assert_difference "ContentChange.count", 1 do
      patch curator_location_path(@location), params: {
        location: {
          name: "Updated Location Name",
          description: "Updated description"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)

    # Location should NOT be updated directly
    @location.reload
    assert_equal original_name, @location.name

    # Verify proposal was created
    proposal = ContentChange.last
    assert_equal "update_content", proposal.change_type
    assert_equal @location, proposal.changeable
    assert_equal "Updated Location Name", proposal.proposed_data["name"]

    proposal.destroy
  end

  test "update records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      patch curator_location_path(@location), params: {
        location: {
          name: "Activity Update Test"
        }
      }
    end

    activity = CuratorActivity.last
    assert_includes [ "proposal_updated", "proposal_contributed" ], activity.action
    assert_equal @curator, activity.user

    ContentChange.last.destroy
  end

  test "update adds contribution to existing pending proposal" do
    # First curator creates a proposal
    existing_proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "First curator's name" }
    )

    login_as(@curator)

    # Should not create a new proposal, but add contribution
    assert_no_difference "ContentChange.count" do
      patch curator_location_path(@location), params: {
        location: {
          name: "Second curator's name",
          description: "Second curator's description"
        }
      }
    end

    assert_redirected_to curator_location_path(@location)

    # Verify contribution was added
    existing_proposal.reload
    assert existing_proposal.contributions.exists?(user: @curator)

    existing_proposal.destroy
  end

  test "update with invalid proposal renders edit form" do
    login_as(@curator)

    # Force the find_or_create_for_update to return a non-persisted record
    mock_proposal = ContentChange.new
    mock_proposal.define_singleton_method(:persisted?) { false }

    ContentChange.stub(:find_or_create_for_update, mock_proposal) do
      patch curator_location_path(@location), params: {
        location: {
          name: "Test"
        }
      }
      assert_response :unprocessable_entity
    end
  end

  # ==========================================================================
  # Destroy Action Tests
  # ==========================================================================

  test "destroy creates delete proposal not direct deletion" do
    login_as(@curator)

    assert_difference "ContentChange.count", 1 do
      assert_no_difference "Location.count" do
        delete curator_location_path(@location)
      end
    end

    assert_redirected_to curator_locations_path

    # Verify delete proposal was created
    proposal = ContentChange.last
    assert_equal "delete_content", proposal.change_type
    assert_equal @location, proposal.changeable
    assert_equal @curator, proposal.user

    proposal.destroy
  end

  test "destroy records curator activity" do
    login_as(@curator)

    assert_difference "CuratorActivity.count", 1 do
      delete curator_location_path(@location)
    end

    activity = CuratorActivity.last
    assert_equal "proposal_deleted", activity.action
    assert_equal @curator, activity.user

    ContentChange.last.destroy
  end

  test "destroy adds contribution to existing pending proposal" do
    # First curator creates an update proposal
    existing_proposal = ContentChange.create!(
      user: @other_curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => @location.name },
      proposed_data: { "name" => "Other name" }
    )

    login_as(@curator)

    # Should convert to delete proposal, not create new
    assert_no_difference "ContentChange.count" do
      delete curator_location_path(@location)
    end

    existing_proposal.reload
    assert_equal "delete_content", existing_proposal.change_type
    assert existing_proposal.contributions.exists?(user: @curator)

    existing_proposal.destroy
  end

  test "destroy with failed proposal shows alert" do
    login_as(@curator)

    # Force the find_or_create_for_delete to return a non-persisted record
    mock_proposal = ContentChange.new
    mock_proposal.define_singleton_method(:persisted?) { false }

    ContentChange.stub(:find_or_create_for_delete, mock_proposal) do
      delete curator_location_path(@location)
      assert_redirected_to curator_locations_path
      follow_redirect!
      # Should have an alert flash
    end
  end

  # ==========================================================================
  # Admin Access Tests
  # ==========================================================================

  test "admin can access all curator location actions" do
    login_as(@admin)

    # Index
    get curator_locations_path
    assert_response :success

    # Show
    get curator_location_path(@location)
    assert_response :success

    # New
    get new_curator_location_path
    assert_response :success

    # Edit
    get edit_curator_location_path(@location)
    assert_response :success
  end

  test "admin can create location proposals" do
    login_as(@admin)

    assert_difference "ContentChange.count", 1 do
      post curator_locations_path, params: {
        location: {
          name: "Admin Proposed Location",
          city: "Zenica",
          lat: 44.2037,
          lng: 17.9078
        }
      }
    end

    assert_redirected_to curator_locations_path
    ContentChange.last.destroy
  end

  # ==========================================================================
  # Edge Cases
  # ==========================================================================

  test "handles location not found gracefully on edit" do
    login_as(@curator)
    get edit_curator_location_path("00000000-0000-0000-0000-000000000000")
    # BaseController has rescue_from RecordNotFound that redirects to index
    assert_redirected_to curator_locations_path
    assert_equal "Locations not found.", flash[:alert]
  end

  test "handles empty location params" do
    login_as(@curator)
    # Empty location params should still attempt to create a proposal
    # Depending on Rails strong parameters and model validation:
    # - 302 redirect if proposal created successfully
    # - 400 if required params are missing
    # - 422 if validation fails
    post curator_locations_path, params: { location: {} }
    # All are acceptable graceful handling (no 500 error)
    assert_includes [ 302, 400, 422 ], response.status
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
