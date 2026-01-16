# frozen_string_literal: true

require "test_helper"

class Curator::Admin::CuratorApplicationsControllerTest < ActionDispatch::IntegrationTest
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
    @applicant = User.create!(
      username: "applicant_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :basic
    )

    @application = CuratorApplication.create!(
      user: @applicant,
      motivation: "I want to help contribute to the platform with local knowledge about Bosnia and Herzegovina." * 2
    )
  end

  teardown do
    CuratorApplication.destroy_all
    @admin&.destroy
    @curator&.destroy
    @applicant&.destroy
  end

  # Index tests
  test "index requires admin" do
    login_as(@curator)
    get curator_admin_curator_applications_path
    assert_redirected_to curator_root_path
  end

  test "index shows all applications" do
    login_as(@admin)
    get curator_admin_curator_applications_path
    assert_response :success
  end

  test "index filters by status" do
    login_as(@admin)
    get curator_admin_curator_applications_path(status: "pending")
    assert_response :success
  end

  # Show tests
  test "show displays application details" do
    login_as(@admin)
    get curator_admin_curator_application_path(@application)
    assert_response :success
  end

  # Approve tests
  test "approve requires admin" do
    login_as(@curator)
    post approve_curator_admin_curator_application_path(@application)
    assert_redirected_to curator_root_path
  end

  test "approve approves pending application" do
    login_as(@admin)
    post approve_curator_admin_curator_application_path(@application)
    assert_redirected_to curator_admin_curator_applications_path

    @application.reload
    assert @application.approved?
    assert_equal @admin, @application.reviewed_by

    @applicant.reload
    assert @applicant.curator?
  end

  test "approve records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      post approve_curator_admin_curator_application_path(@application)
    end

    activity = CuratorActivity.last
    assert_equal "approve_curator_application", activity.action
    assert_equal @admin, activity.user
  end

  test "approve fails for already reviewed application" do
    @application.update!(status: :approved, reviewed_by: @admin, reviewed_at: Time.current)
    @applicant.update!(user_type: :curator)

    login_as(@admin)
    post approve_curator_admin_curator_application_path(@application)
    assert_redirected_to curator_admin_curator_applications_path
    assert_match /already.*reviewed/i, flash[:alert]
  end

  # Reject tests
  test "reject requires admin" do
    login_as(@curator)
    post reject_curator_admin_curator_application_path(@application)
    assert_redirected_to curator_root_path
  end

  test "reject rejects pending application" do
    login_as(@admin)
    post reject_curator_admin_curator_application_path(@application), params: { admin_notes: "Not enough experience" }
    assert_redirected_to curator_admin_curator_applications_path

    @application.reload
    assert @application.rejected?
    assert_equal @admin, @application.reviewed_by
    assert_equal "Not enough experience", @application.admin_notes

    @applicant.reload
    assert @applicant.basic?
  end

  test "reject records curator activity" do
    login_as(@admin)

    assert_difference "CuratorActivity.count", 1 do
      post reject_curator_admin_curator_application_path(@application)
    end

    activity = CuratorActivity.last
    assert_equal "reject_curator_application", activity.action
  end

  test "reject fails for already reviewed application" do
    @application.update!(status: :rejected, reviewed_by: @admin, reviewed_at: Time.current)

    login_as(@admin)
    post reject_curator_admin_curator_application_path(@application)
    assert_redirected_to curator_admin_curator_applications_path
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
