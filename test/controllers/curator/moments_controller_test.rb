# frozen_string_literal: true

require "test_helper"

class Curator::MomentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @curator = User.create!(username: "mod_curator", password: "password123", user_type: :curator)
    @user = User.create!(username: "mom_sharer", password: "password123")
    @location = Location.create!(name: "Mod Loc", city: "Sarajevo", lat: 43.85, lng: 18.41)
    @plan = Plan.create!(title: "Mod Trip", city_name: "Sarajevo", visibility: :private_plan, user: @user)
    @moment = build_public_pending_moment
  end

  teardown do
    Moment.destroy_all
    @plan&.destroy
    @location&.destroy
    @user&.destroy
    @curator&.destroy
  end

  test "the queue lists a pending public moment with review actions" do
    login_as(@curator)

    get curator_moments_path

    assert_response :success
    assert_select "form[action=?]", approve_curator_moment_path(@moment)
    assert_select "form[action=?]", reject_curator_moment_path(@moment)
  end

  test "a curator approves a moment" do
    login_as(@curator)

    post approve_curator_moment_path(@moment)

    assert @moment.reload.approved?
  end

  test "a curator rejects a moment" do
    login_as(@curator)

    post reject_curator_moment_path(@moment)

    assert @moment.reload.rejected?
  end

  test "an approved moment can be reverted — it offers reject, not approve" do
    @moment.update!(moderation_status: :approved)
    login_as(@curator)

    get curator_moments_path(status: "approved")

    assert_response :success
    assert_select "form[action=?]", approve_curator_moment_path(@moment), count: 0
    assert_select "form[action=?]", reject_curator_moment_path(@moment), count: 1
  end

  test "a rejected moment can be re-approved — it offers approve, not reject" do
    @moment.update!(moderation_status: :rejected)
    login_as(@curator)

    get curator_moments_path(status: "rejected")

    assert_response :success
    assert_select "form[action=?]", approve_curator_moment_path(@moment), count: 1
    assert_select "form[action=?]", reject_curator_moment_path(@moment), count: 0
  end

  test "reverting an approved moment pulls it back out of search" do
    @moment.update!(moderation_status: :approved)
    assert Browse.exists?(browsable: @moment), "approved public moment should be indexed"
    login_as(@curator)

    post reject_curator_moment_path(@moment)

    assert @moment.reload.rejected?
    assert_not Browse.exists?(browsable: @moment), "un-approving must remove it from search"
  end

  test "re-approving a rejected moment puts it back into search" do
    @moment.update!(moderation_status: :rejected)
    assert_not Browse.exists?(browsable: @moment)
    login_as(@curator)

    post approve_curator_moment_path(@moment)

    assert @moment.reload.approved?
    assert Browse.exists?(browsable: @moment), "re-approving must re-index it"
  end

  test "a non-curator cannot reach the moderation queue" do
    login_as(@user)

    get curator_moments_path

    assert_not_equal 200, response.status
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def build_public_pending_moment
    moment = @user.moments.build(plan: @plan, location: @location)
    moment.photo.attach(
      io: File.open("test/fixtures/files/test_image.jpg"),
      filename: "mod.jpg",
      content_type: "image/jpeg"
    )
    moment.save!
    moment.update!(visibility: :public_moment)
    moment
  end
end
