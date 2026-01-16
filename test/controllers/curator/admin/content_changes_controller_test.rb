# frozen_string_literal: true

require "test_helper"

class Curator::Admin::ContentChangesControllerTest < ActionDispatch::IntegrationTest
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
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @content_change = ContentChange.create!(
      user: @curator,
      change_type: :update_content,
      changeable: @location,
      original_data: { "name" => "Test Location", "description" => "Old description" },
      proposed_data: { "name" => "Test Location", "description" => "New improved description" }
    )
  end

  teardown do
    ContentChange.destroy_all
    @location&.destroy
    @admin&.destroy
    @curator&.destroy
  end

  # Index tests
  test "index requires admin" do
    login_as(@curator)
    get curator_admin_content_changes_path
    assert_redirected_to curator_root_path
  end

  test "index shows all content changes" do
    login_as(@admin)
    get curator_admin_content_changes_path
    assert_response :success
  end

  test "index filters by status" do
    login_as(@admin)
    get curator_admin_content_changes_path(status: "pending")
    assert_response :success
  end

  test "index filters by change type" do
    login_as(@admin)
    get curator_admin_content_changes_path(type: "update_content")
    assert_response :success
  end

  test "index filters by content type" do
    login_as(@admin)
    get curator_admin_content_changes_path(content_type: "Location")
    assert_response :success
  end

  # Show tests
  test "show displays content change details" do
    login_as(@admin)
    get curator_admin_content_change_path(@content_change)
    assert_response :success
  end

  # Approve tests
  test "approve requires admin" do
    login_as(@curator)
    post approve_curator_admin_content_change_path(@content_change)
    assert_redirected_to curator_root_path
  end

  test "approve approves pending content change" do
    login_as(@admin)
    post approve_curator_admin_content_change_path(@content_change)
    assert_redirected_to curator_admin_content_changes_path

    @content_change.reload
    assert @content_change.approved?
    assert_equal @admin, @content_change.reviewed_by

    @location.reload
    assert_equal "New improved description", @location.description
  end

  test "approve records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      post approve_curator_admin_content_change_path(@content_change)
    end

    activity = CuratorActivity.last
    assert_equal "approve_content_change", activity.action
    assert_equal @admin, activity.user
  end

  test "approve fails for already reviewed content change" do
    @content_change.update!(status: :approved, reviewed_by: @admin, reviewed_at: Time.current)

    login_as(@admin)
    post approve_curator_admin_content_change_path(@content_change)
    assert_redirected_to curator_admin_content_changes_path
    assert_match /already.*reviewed/i, flash[:alert]
  end

  test "approve shows error when approval fails" do
    login_as(@admin)

    # Create a mock that returns false for approve!
    mock_change = @content_change
    mock_change.define_singleton_method(:approve!) { |*_args, **_kwargs| false }

    ContentChange.stub(:find, ->(_id) { mock_change }) do
      post approve_curator_admin_content_change_path(@content_change)
    end

    assert_redirected_to curator_admin_content_change_path(@content_change)
    assert_match /failed/i, flash[:alert]
  end

  # Reject tests
  test "reject requires admin" do
    login_as(@curator)
    post reject_curator_admin_content_change_path(@content_change)
    assert_redirected_to curator_root_path
  end

  test "reject rejects pending content change" do
    login_as(@admin)
    post reject_curator_admin_content_change_path(@content_change), params: { admin_notes: "Not accurate" }
    assert_redirected_to curator_admin_content_changes_path

    @content_change.reload
    assert @content_change.rejected?
    assert_equal @admin, @content_change.reviewed_by
    assert_equal "Not accurate", @content_change.admin_notes

    @location.reload
    assert_nil @location.description
  end

  test "reject records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      post reject_curator_admin_content_change_path(@content_change)
    end

    activity = CuratorActivity.last
    assert_equal "reject_content_change", activity.action
  end

  test "reject fails for already reviewed content change" do
    @content_change.update!(status: :rejected, reviewed_by: @admin, reviewed_at: Time.current)

    login_as(@admin)
    post reject_curator_admin_content_change_path(@content_change)
    assert_redirected_to curator_admin_content_changes_path
    assert_match /already.*reviewed/i, flash[:alert]
  end

  private

  def login_as(user)
    post login_path, params: {
      username: user.username,
      password: "password123"
    }
  end
end
