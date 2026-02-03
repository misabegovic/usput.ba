# frozen_string_literal: true

require "test_helper"

class Curator::AudioToursControllerTest < ActionDispatch::IntegrationTest
  # Disable parallel tests for this file to avoid database conflicts
  parallelize(workers: 1)

  setup do
    # Use unique random values to prevent collisions
    @random_suffix = SecureRandom.hex(8)

    @curator = User.create!(
      username: "test_curator_#{@random_suffix}",
      password: "password123",
      user_type: :curator
    )
    @other_curator = User.create!(
      username: "other_curator_#{@random_suffix}",
      password: "password123",
      user_type: :curator
    )
    @admin = User.create!(
      username: "admin_user_#{@random_suffix}",
      password: "password123",
      user_type: :admin
    )
    @basic_user = User.create!(
      username: "basic_user_#{@random_suffix}",
      password: "password123",
      user_type: :basic
    )

    # Use unique coordinates to avoid validation failures
    @lat_base = 43.8563 + rand * 0.001
    @lng_base = 18.4131 + rand * 0.001

    @location = Location.create!(
      name: "Test Location #{@random_suffix}",
      city: "Sarajevo",
      lat: @lat_base,
      lng: @lng_base,
      location_type: :place
    )

    @other_location = Location.create!(
      name: "Other Location #{@random_suffix}",
      city: "Mostar",
      lat: @lat_base + 0.01,
      lng: @lng_base + 0.01,
      location_type: :place
    )

    @audio_tour = AudioTour.create!(
      location: @location,
      locale: "bs",
      script: "Ovo je testni audio tour za Sarajevo #{@random_suffix}.",
      word_count: 10,
      duration: "2 min"
    )

    @other_audio_tour = AudioTour.create!(
      location: @other_location,
      locale: "en",
      script: "This is a test audio tour for Mostar #{@random_suffix}.",
      word_count: 15,
      duration: "3 min"
    )
  end

  # ==========================================================================
  # Authentication Tests
  # ==========================================================================

  test "index requires login" do
    get curator_audio_tours_path
    assert_redirected_to login_path
  end

  test "show requires login" do
    get curator_audio_tour_path(@audio_tour)
    assert_redirected_to login_path
  end

  test "new requires login" do
    get new_curator_audio_tour_path
    assert_redirected_to login_path
  end

  test "create requires login" do
    post curator_audio_tours_path, params: {
      audio_tour: { location_id: @location.id, locale: "de", script: "Test" }
    }
    assert_redirected_to login_path
  end

  test "edit requires login" do
    get edit_curator_audio_tour_path(@audio_tour)
    assert_redirected_to login_path
  end

  test "update requires login" do
    patch curator_audio_tour_path(@audio_tour), params: {
      audio_tour: { script: "Updated script" }
    }
    assert_redirected_to login_path
  end

  test "destroy requires login" do
    delete curator_audio_tour_path(@audio_tour)
    assert_redirected_to login_path
  end

  # ==========================================================================
  # Authorization Tests - Basic User Cannot Access
  # ==========================================================================

  test "index requires curator role" do
    login_as(@basic_user)
    get curator_audio_tours_path
    assert_redirected_to root_path
  end

  test "show requires curator role" do
    login_as(@basic_user)
    get curator_audio_tour_path(@audio_tour)
    assert_redirected_to root_path
  end

  test "new requires curator role" do
    login_as(@basic_user)
    get new_curator_audio_tour_path
    assert_redirected_to root_path
  end

  test "create requires curator role" do
    login_as(@basic_user)
    post curator_audio_tours_path, params: {
      audio_tour: { location_id: @location.id, locale: "de", script: "Test" }
    }
    assert_redirected_to root_path
  end

  test "edit requires curator role" do
    login_as(@basic_user)
    get edit_curator_audio_tour_path(@audio_tour)
    assert_redirected_to root_path
  end

  test "update requires curator role" do
    login_as(@basic_user)
    patch curator_audio_tour_path(@audio_tour), params: {
      audio_tour: { script: "Updated script" }
    }
    assert_redirected_to root_path
  end

  test "destroy requires curator role" do
    login_as(@basic_user)
    delete curator_audio_tour_path(@audio_tour)
    assert_redirected_to root_path
  end

  # ==========================================================================
  # Spam Block Tests
  # ==========================================================================

  test "spam blocked curator cannot access index" do
    @curator.update!(
      spam_blocked_at: Time.current,
      spam_blocked_until: 1.hour.from_now,
      spam_block_reason: "Testing spam block"
    )

    login_as(@curator)
    get curator_audio_tours_path
    assert_redirected_to root_path
    # Flash message mentions being blocked due to high activity
    assert_match(/blocked/i, flash[:alert])
  end

  test "spam blocked curator cannot create proposals" do
    @curator.update!(
      spam_blocked_at: Time.current,
      spam_blocked_until: 1.hour.from_now,
      spam_block_reason: "Testing spam block"
    )

    login_as(@curator)
    post curator_audio_tours_path, params: {
      audio_tour: { location_id: @location.id, locale: "de", script: "Test" }
    }
    assert_redirected_to root_path
  end

  # ==========================================================================
  # Index Action Tests
  # ==========================================================================

  test "curator can access index" do
    login_as(@curator)
    get curator_audio_tours_path
    assert_response :success
  end

  test "admin can access index" do
    login_as(@admin)
    get curator_audio_tours_path
    assert_response :success
  end

  test "index shows audio tours list" do
    login_as(@curator)
    get curator_audio_tours_path
    assert_response :success
    # Check page contains audio tour info
    assert_match @location.name, response.body
  end

  test "index filters by locale" do
    login_as(@curator)
    get curator_audio_tours_path, params: { locale: "bs" }
    assert_response :success
  end

  test "index filters by location_id" do
    login_as(@curator)
    get curator_audio_tours_path, params: { location_id: @location.id }
    assert_response :success
  end

  test "index filters by search term" do
    login_as(@curator)
    get curator_audio_tours_path, params: { search: "Sarajevo" }
    assert_response :success
  end

  test "index paginates results" do
    login_as(@curator)
    get curator_audio_tours_path, params: { page: 1 }
    assert_response :success
  end

  # ==========================================================================
  # Show Action Tests
  # ==========================================================================

  test "curator can view audio tour" do
    login_as(@curator)
    get curator_audio_tour_path(@audio_tour)
    assert_response :success
  end

  test "admin can view audio tour" do
    login_as(@admin)
    get curator_audio_tour_path(@audio_tour)
    assert_response :success
  end

  test "show displays audio tour details" do
    login_as(@curator)
    get curator_audio_tour_path(@audio_tour)
    assert_response :success
    assert_match @audio_tour.script, response.body
  end

  test "show returns 404 for non-existent audio tour" do
    login_as(@curator)
    get curator_audio_tour_path(id: 999999)
    # BaseController has rescue_from RecordNotFound that redirects to index
    assert_redirected_to curator_audio_tours_path
    assert_equal "Audio tours not found.", flash[:alert]
  end

  # ==========================================================================
  # New Action Tests
  # ==========================================================================

  test "curator can access new form" do
    login_as(@curator)
    get new_curator_audio_tour_path
    assert_response :success
  end

  test "admin can access new form" do
    login_as(@admin)
    get new_curator_audio_tour_path
    assert_response :success
  end

  test "new form displays form elements" do
    login_as(@curator)
    get new_curator_audio_tour_path
    assert_response :success
    # Check form elements are present
    assert_select "form"
  end

  test "new form preselects location when location_id param provided" do
    login_as(@curator)
    get new_curator_audio_tour_path, params: { location_id: @other_location.id }
    assert_response :success
    # Check that the page loads successfully with the param
    assert_select "form"
  end

  # ==========================================================================
  # Create Action Tests
  # ==========================================================================

  test "create creates a proposal instead of direct audio tour" do
    login_as(@curator)

    initial_audio_tour_count = AudioTour.count
    initial_content_change_count = ContentChange.count

    post curator_audio_tours_path, params: {
      audio_tour: {
        location_id: @other_location.id,
        locale: "de",
        script: "Dies ist ein deutscher Audio-Tour.",
        word_count: 8,
        duration: "1 min"
      }
    }

    assert_redirected_to curator_audio_tours_path

    # AudioTour count should not change (not created directly)
    assert_equal initial_audio_tour_count, AudioTour.count
    # ContentChange count should increase by 1
    assert_equal initial_content_change_count + 1, ContentChange.count

    proposal = ContentChange.order(created_at: :desc).first
    assert_equal "create_content", proposal.change_type
    assert_equal "AudioTour", proposal.changeable_class
    assert_equal @curator, proposal.user
    assert_equal @other_location.id.to_s, proposal.proposed_data["location_id"].to_s
    assert_equal "de", proposal.proposed_data["locale"]
  end

  test "create records curator activity" do
    login_as(@curator)

    initial_activity_count = CuratorActivity.where(user: @curator).count

    post curator_audio_tours_path, params: {
      audio_tour: {
        location_id: @location.id,
        locale: "fr",
        script: "Tour audio en francais."
      }
    }

    assert_equal initial_activity_count + 1, CuratorActivity.where(user: @curator).count

    activity = CuratorActivity.where(user: @curator).order(created_at: :desc).first
    assert_equal "proposal_created", activity.action
    assert_equal @curator, activity.user
    assert_equal "AudioTour", activity.metadata["type"]
  end

  test "create with valid params redirects to index" do
    login_as(@curator)

    post curator_audio_tours_path, params: {
      audio_tour: {
        location_id: @location.id,
        locale: "it",
        script: "Tour audio in italiano."
      }
    }

    assert_redirected_to curator_audio_tours_path
  end

  # ==========================================================================
  # Edit Action Tests
  # ==========================================================================

  test "curator can access edit form" do
    login_as(@curator)
    get edit_curator_audio_tour_path(@audio_tour)
    assert_response :success
  end

  test "admin can access edit form" do
    login_as(@admin)
    get edit_curator_audio_tour_path(@audio_tour)
    assert_response :success
  end

  test "edit form shows current audio tour data" do
    login_as(@curator)
    get edit_curator_audio_tour_path(@audio_tour)
    assert_response :success
    # Check form contains audio tour data
    assert_match @audio_tour.script, response.body
  end

  # ==========================================================================
  # Update Action Tests
  # ==========================================================================

  test "update creates a proposal instead of direct update" do
    login_as(@curator)

    original_script = @audio_tour.script
    initial_content_change_count = ContentChange.count

    patch curator_audio_tour_path(@audio_tour), params: {
      audio_tour: {
        location_id: @audio_tour.location_id,
        locale: @audio_tour.locale,
        script: "Updated script for testing.",
        word_count: 5,
        duration: "1 min"
      }
    }

    # Original audio tour should not be modified
    @audio_tour.reload
    assert_equal original_script, @audio_tour.script

    assert_redirected_to curator_audio_tour_path(@audio_tour)

    # ContentChange count should increase by 1
    assert_equal initial_content_change_count + 1, ContentChange.count

    proposal = ContentChange.order(created_at: :desc).first
    assert_equal "update_content", proposal.change_type
    assert_equal @audio_tour, proposal.changeable
    assert_equal @curator, proposal.user
    assert_equal "Updated script for testing.", proposal.proposed_data["script"]
  end

  test "update records curator activity" do
    login_as(@curator)

    initial_activity_count = CuratorActivity.where(user: @curator).count

    patch curator_audio_tour_path(@audio_tour), params: {
      audio_tour: {
        script: "New script content."
      }
    }

    assert_equal initial_activity_count + 1, CuratorActivity.where(user: @curator).count

    activity = CuratorActivity.where(user: @curator).order(created_at: :desc).first
    assert_includes %w[proposal_updated proposal_contributed], activity.action
    assert_equal @curator, activity.user
    assert_equal "AudioTour", activity.metadata["type"]
  end

  test "update to existing pending proposal adds contribution" do
    # First curator creates a proposal
    proposal = ContentChange.find_or_create_for_update(
      changeable: @audio_tour,
      user: @other_curator,
      original_data: @audio_tour.attributes.slice("location_id", "locale", "script", "word_count", "duration"),
      proposed_data: { "script" => "Other curator's script" }
    )

    login_as(@curator)

    initial_content_change_count = ContentChange.count

    # Second curator updates the same audio tour
    patch curator_audio_tour_path(@audio_tour), params: {
      audio_tour: {
        script: "My contribution to the proposal."
      }
    }

    assert_redirected_to curator_audio_tour_path(@audio_tour)

    # No new ContentChange should be created
    assert_equal initial_content_change_count, ContentChange.count

    # Contribution should be added
    proposal.reload
    assert proposal.contributions.exists?(user: @curator)
  end

  test "update redirects to show page" do
    login_as(@curator)

    patch curator_audio_tour_path(@audio_tour), params: {
      audio_tour: {
        script: "Another updated script."
      }
    }

    assert_redirected_to curator_audio_tour_path(@audio_tour)
  end

  # ==========================================================================
  # Destroy Action Tests
  # ==========================================================================

  test "destroy creates a delete proposal instead of deleting directly" do
    login_as(@curator)

    initial_audio_tour_count = AudioTour.count
    initial_content_change_count = ContentChange.count

    delete curator_audio_tour_path(@audio_tour)

    assert_redirected_to curator_audio_tours_path

    # AudioTour count should not change (not deleted directly)
    assert_equal initial_audio_tour_count, AudioTour.count
    # ContentChange count should increase by 1
    assert_equal initial_content_change_count + 1, ContentChange.count

    proposal = ContentChange.order(created_at: :desc).first
    assert_equal "delete_content", proposal.change_type
    assert_equal @audio_tour, proposal.changeable
    assert_equal @curator, proposal.user
  end

  test "destroy records curator activity" do
    login_as(@curator)

    initial_activity_count = CuratorActivity.where(user: @curator).count

    delete curator_audio_tour_path(@audio_tour)

    assert_equal initial_activity_count + 1, CuratorActivity.where(user: @curator).count

    activity = CuratorActivity.where(user: @curator).order(created_at: :desc).first
    assert_equal "proposal_deleted", activity.action
    assert_equal @curator, activity.user
    assert_equal "AudioTour", activity.metadata["type"]
  end

  test "destroy redirects to index page" do
    login_as(@curator)

    delete curator_audio_tour_path(@audio_tour)
    assert_redirected_to curator_audio_tours_path
  end

  test "destroy to existing pending update proposal converts to delete" do
    # First curator creates an update proposal
    proposal = ContentChange.find_or_create_for_update(
      changeable: @audio_tour,
      user: @other_curator,
      original_data: @audio_tour.attributes.slice("location_id", "locale", "script", "word_count", "duration"),
      proposed_data: { "script" => "Updated by other curator" }
    )

    login_as(@curator)

    initial_content_change_count = ContentChange.count

    # Request deletion
    delete curator_audio_tour_path(@audio_tour)

    # No new ContentChange should be created
    assert_equal initial_content_change_count, ContentChange.count

    proposal.reload
    assert_equal "delete_content", proposal.change_type
  end

  # ==========================================================================
  # Edge Cases and Additional Tests
  # ==========================================================================

  test "curator can work with audio tour without script" do
    audio_tour_no_script = AudioTour.create!(
      location: @other_location,
      locale: "hr"
    )

    login_as(@curator)
    get curator_audio_tour_path(audio_tour_no_script)
    assert_response :success
  end

  test "multiple curators can create proposals for different audio tours" do
    # First curator creates proposal for one audio tour
    login_as(@curator)
    post curator_audio_tours_path, params: {
      audio_tour: {
        location_id: @location.id,
        locale: "nl",
        script: "Dutch tour"
      }
    }
    logout

    # Second curator creates proposal for another audio tour
    login_as(@other_curator)
    post curator_audio_tours_path, params: {
      audio_tour: {
        location_id: @other_location.id,
        locale: "pl",
        script: "Polish tour"
      }
    }

    # Both proposals should exist
    assert ContentChange.where(changeable_class: "AudioTour", user: @curator).exists?
    assert ContentChange.where(changeable_class: "AudioTour", user: @other_curator).exists?
  end

  test "admin can perform all actions" do
    login_as(@admin)

    # Index
    get curator_audio_tours_path
    assert_response :success

    # Show
    get curator_audio_tour_path(@audio_tour)
    assert_response :success

    # New
    get new_curator_audio_tour_path
    assert_response :success

    # Create proposal
    post curator_audio_tours_path, params: {
      audio_tour: {
        location_id: @location.id,
        locale: "es",
        script: "Spanish tour"
      }
    }
    assert_redirected_to curator_audio_tours_path

    # Edit
    get edit_curator_audio_tour_path(@audio_tour)
    assert_response :success

    # Update proposal
    patch curator_audio_tour_path(@audio_tour), params: {
      audio_tour: { script: "Admin updated script" }
    }
    assert_redirected_to curator_audio_tour_path(@audio_tour)
  end

  test "strong parameters only allow permitted attributes" do
    login_as(@curator)

    # Try to include unpermitted attributes
    post curator_audio_tours_path, params: {
      audio_tour: {
        location_id: @location.id,
        locale: "de",
        script: "Test",
        id: 999,
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        malicious_field: "hacked"
      }
    }

    proposal = ContentChange.order(created_at: :desc).first
    # Only permitted fields should be in proposed_data
    permitted_keys = %w[location_id locale script word_count duration]
    proposal.proposed_data.keys.each do |key|
      assert_includes permitted_keys, key
    end
    assert_nil proposal.proposed_data["id"]
    assert_nil proposal.proposed_data["created_at"]
    assert_nil proposal.proposed_data["malicious_field"]
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end

  def logout
    delete logout_path
  end
end
