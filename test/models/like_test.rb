# frozen_string_literal: true

require "test_helper"

class LikeTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(username: "like_owner", password: "password123")
    @reader = User.create!(username: "like_reader", password: "password123")
    @location = Location.create!(name: "Like Location", city: "Jajce", lat: 44.34, lng: 17.27)
    @plan = Plan.create!(title: "Like Plan", city_name: "Jajce", visibility: :private_plan, user: @owner)
    @moment = public_moment
  end

  teardown do
    Moment.destroy_all
    Like.destroy_all
    @plan&.destroy
    @location&.destroy
    # Loaded fresh: @owner caches the moment the test already destroyed.
    User.where(id: [ @owner&.id, @reader&.id ].compact).destroy_all
  end

  test "a like counts on the moment it points at" do
    assert_difference -> { @moment.reload.likes_count }, 1 do
      @reader.likes.create!(likeable: @moment)
    end
  end

  test "removing a like takes the count back down" do
    like = @reader.likes.create!(likeable: @moment)

    assert_difference -> { @moment.reload.likes_count }, -1 do
      like.destroy
    end
  end

  test "a like reaches the moment's search row" do
    # The helper publishes with update_columns, so the row the app would have
    # indexed on save does not exist yet.
    Browse.sync_record(@moment)

    assert_difference -> { Browse.find_by(browsable: @moment).reviews_count }, 1 do
      @reader.likes.create!(likeable: @moment)
    end
  end

  test "the same traveller cannot like one moment twice" do
    @reader.likes.create!(likeable: @moment)
    second = @reader.likes.build(likeable: @moment)

    assert_not second.valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      second.save(validate: false)
    end
  end

  test "two travellers liking the same moment both count" do
    @reader.likes.create!(likeable: @moment)
    @owner.likes.create!(likeable: @moment)

    assert_equal 2, @moment.reload.likes_count
  end

  test "liked_by? answers for the liker, the stranger and nobody" do
    @reader.likes.create!(likeable: @moment)

    assert @moment.liked_by?(@reader)
    assert_not @moment.liked_by?(@owner)
    assert_not @moment.liked_by?(nil)
  end

  test "destroying a moment takes its likes with it" do
    @reader.likes.create!(likeable: @moment)

    assert_difference -> { Like.count }, -1 do
      @moment.destroy
    end
  end

  test "only a public approved moment is likeable" do
    assert @moment.likeable?

    @moment.update_columns(moderation_status: Moment.moderation_statuses[:pending])
    assert_not @moment.reload.likeable?

    @moment.update_columns(visibility: Moment.visibilities[:private_moment],
                           moderation_status: Moment.moderation_statuses[:approved])
    assert_not @moment.reload.likeable?
  end

  private

  def public_moment
    moment = @owner.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: StringIO.new("fake image data"), filename: "like.jpg", content_type: "image/jpeg")
    moment.save!
    # Publishing re-enters moderation by design, so approval is set after.
    moment.update_columns(visibility: Moment.visibilities[:public_moment],
                          moderation_status: Moment.moderation_statuses[:approved])
    moment.reload
  end
end
