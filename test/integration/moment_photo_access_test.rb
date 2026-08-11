# frozen_string_literal: true

require "test_helper"

# Moments are private: only their owner may ever see the photo.
#
# The listing was scoped through current_user.moments from the start, but the
# photo file was served by Active Storage's own global route, which never looks
# at the session. A signed blob URL is unguessable but not authorised — it is a
# bearer token, and anyone who obtained the link (browser history, a copied URL,
# a proxy log) could fetch the image forever. Verified before the fix: a request
# with no session at all returned 302 -> 200 image/jpeg.
#
# These tests exist to make that impossible to reintroduce.
class MomentPhotoAccessTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(username: "photo_owner", password: "password123")
    @stranger = User.create!(username: "photo_stranger", password: "password123")
    @location = Location.create!(name: "Photo Loc", city: "Mostar", lat: 43.34, lng: 17.81)
    @plan = Plan.create!(title: "Photo Plan", city_name: "Mostar", visibility: :public_plan, user: @owner)
    @moment = build_moment
  end

  teardown do
    Moment.destroy_all
    @plan&.destroy
    @location&.destroy
    @owner&.destroy
    @stranger&.destroy
  end

  test "the owner can fetch their own moment photo" do
    login_as(@owner)

    get photo_plan_moment_path(@plan, @moment)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "a guest cannot fetch a moment photo" do
    get photo_plan_moment_path(@plan, @moment)

    assert_redirected_to login_path
  end

  test "another logged-in user cannot fetch someone else's moment photo" do
    login_as(@stranger)

    get photo_plan_moment_path(@plan, @moment)

    # 404, not 403: a stranger must not learn that the moment exists
    assert_response :not_found
  end

  test "a stranger cannot fetch it even on a public plan they can otherwise see" do
    login_as(@stranger)

    get plan_path(@plan)
    assert_response :success, "the plan itself is public and readable"

    get photo_plan_moment_path(@plan, @moment)
    assert_response :not_found, "but its moments are not"
  end

  test "the plan page never leaks an Active Storage url for a moment" do
    login_as(@owner)

    get plan_path(@plan)

    assert_response :success
    assert_no_match %r{/rails/active_storage/}, response.body,
      "a moment photo must not be served from Active Storage's unauthenticated route"
  end

  test "the profile page never leaks an Active Storage url" do
    login_as(@owner)

    get profile_page_path

    assert_response :success
    assert_no_match %r{/rails/active_storage/}, response.body,
      "the moments card must not carry blob urls"
  end

  test "an unknown variant size falls back rather than processing arbitrary input" do
    login_as(@owner)

    get photo_plan_moment_path(@plan, @moment, size: "99999x99999")

    assert_response :success
  end

  test "a blob whose bytes are not an image is refused rather than 500ing" do
    junk = @owner.moments.build(plan: @plan, location: @location)
    junk.photo.attach(io: StringIO.new("not an image"), filename: "junk.jpg", content_type: "image/jpeg")
    junk.save!
    login_as(@owner)

    get photo_plan_moment_path(@plan, junk)

    assert_response :unprocessable_entity
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def build_moment
    moment = @owner.moments.build(plan: @plan, location: @location, note: "private moment")
    moment.photo.attach(
      io: File.open("test/fixtures/files/real_image.jpg"),
      filename: "secret.jpg",
      content_type: "image/jpeg"
    )
    moment.save!
    moment
  end
end
