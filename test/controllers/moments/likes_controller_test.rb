# frozen_string_literal: true

require "test_helper"

class Moments::LikesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(username: "heart_owner", password: "password123")
    @reader = User.create!(username: "heart_reader", password: "password123")
    @location = Location.create!(name: "Heart Location", city: "Trebinje", lat: 42.71, lng: 18.34)
    @plan = Plan.create!(title: "Heart Plan", city_name: "Trebinje", visibility: :private_plan, user: @owner)
    @moment = moment_for(visibility: :public_moment, moderation: :approved)
  end

  teardown do
    Like.destroy_all
    Moment.destroy_all
    @plan&.destroy
    @location&.destroy
    @owner&.destroy
    @reader&.destroy
  end

  test "a signed-in traveller likes a public moment" do
    login_as(@reader)

    assert_difference -> { @moment.reload.likes_count }, 1 do
      post moment_like_path(@moment, context: "moments"), as: :turbo_stream
    end

    assert_response :success
  end

  test "liking twice is still one like" do
    login_as(@reader)
    post moment_like_path(@moment, context: "moments"), as: :turbo_stream

    assert_no_difference -> { @moment.reload.likes_count } do
      post moment_like_path(@moment, context: "moments"), as: :turbo_stream
    end
  end

  test "a like is taken back" do
    login_as(@reader)
    post moment_like_path(@moment, context: "moments"), as: :turbo_stream

    assert_difference -> { @moment.reload.likes_count }, -1 do
      delete moment_like_path(@moment, context: "moments"), as: :turbo_stream
    end
  end

  # The UI never sends a guest here — their heart is a plain link into sign-in.
  # Reaching it anyway must redirect in a way Turbo can follow, or the control
  # the request came from reads "Content missing".
  test "a guest reaching the action is redirected with a status Turbo follows" do
    assert_no_difference -> { @moment.reload.likes_count } do
      post moment_like_path(@moment, context: "moments"), as: :turbo_stream
    end

    assert_response :see_other
    assert_redirected_to login_path
  end

  test "a private moment cannot be liked" do
    private_moment = moment_for(visibility: :private_moment, moderation: :approved)
    login_as(@reader)

    assert_no_difference -> { Like.count } do
      post moment_like_path(private_moment, context: "moments"), as: :turbo_stream
    end

    assert_response :not_found
  end

  test "a moment awaiting a curator cannot be liked" do
    pending_moment = moment_for(visibility: :public_moment, moderation: :pending)
    login_as(@reader)

    assert_no_difference -> { Like.count } do
      post moment_like_path(pending_moment, context: "moments"), as: :turbo_stream
    end

    assert_response :not_found
  end

  private

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def moment_for(visibility:, moderation:)
    moment = @owner.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: StringIO.new("fake image data"), filename: "heart.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update_columns(visibility: Moment.visibilities[visibility],
                          moderation_status: Moment.moderation_statuses[moderation])
    moment.reload
  end
end
