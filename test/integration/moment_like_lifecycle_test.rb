# frozen_string_literal: true

require "test_helper"

# A like is not a feature on its own — it has to survive everything that already
# happens to the moment underneath it: unpublishing, curator rejection, the
# place being retired, and either party being deleted.
class MomentLikeLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    @author = User.create!(username: "life_author", password: "password123")
    @reader = User.create!(username: "life_reader", password: "password123")
    @location = Location.create!(name: "Life Falls", city: "Jajce", lat: 44.34, lng: 17.27)
    @plan = Plan.create!(title: "Life Plan", city_name: "Jajce", visibility: :private_plan, user: @author)
    @moment = public_moment
  end

  teardown do
    Moment.destroy_all
    Like.destroy_all
    @plan&.destroy
    @location&.destroy
    User.where(id: [ @author&.id, @reader&.id ].compact).destroy_all
  end

  test "unpublishing keeps the likes but takes the moment out of every public read" do
    @reader.likes.create!(likeable: @moment)

    @moment.update!(visibility: :private_moment)

    assert_equal 1, @moment.reload.likes_count, "the rows survive — the photo did not stop being liked"
    assert_not @moment.likeable?
    assert_nil Browse.find_by(browsable: @moment), "it leaves the index with everything else public"
  end

  test "a curator rejection makes a liked moment unlikeable without losing the count" do
    @reader.likes.create!(likeable: @moment)

    @moment.update!(moderation_status: :rejected)

    assert_equal 1, @moment.reload.likes_count
    assert_not @moment.likeable?
  end

  test "republishing keeps the likes but goes back through moderation first" do
    @reader.likes.create!(likeable: @moment)
    @moment.update!(visibility: :private_moment)
    @moment.update!(visibility: :public_moment)

    assert_equal 1, @moment.reload.likes_count, "the same photo returns with what it earned"
    assert @moment.pending?, "going public re-enters moderation, so the heart waits for a curator"
    assert_not @moment.likeable?

    @moment.update!(moderation_status: :approved)
    assert @moment.reload.likeable?
  end

  test "retiring the place keeps the moment and its likes, and the place link explains itself" do
    @reader.likes.create!(likeable: @moment)
    @location.update!(archived_at: Time.current)

    assert Moment.exists?(@moment.id), "memories outlive the container they were captured in"
    assert_equal 1, @moment.reload.likes_count

    get location_path(@location)
    assert_response :redirect, "a retired place explains itself rather than breaking the moment's link"
  end

  test "deleting the traveller who liked it decrements the count" do
    @reader.likes.create!(likeable: @moment)

    assert_difference -> { @moment.reload.likes_count }, -1 do
      User.find(@reader.id).destroy
    end
  end

  test "deleting the author takes the moment and every like on it" do
    @reader.likes.create!(likeable: @moment)

    assert_difference -> { Like.count }, -1 do
      User.find(@author.id).destroy
    end

    assert_not Moment.exists?(@moment.id)
  end

  test "an ordinary destroy is refused while a traveller holds a memory of the place" do
    @reader.likes.create!(likeable: @moment)

    assert_no_difference -> { Like.count } do
      assert_not @location.destroy
    end

    assert Location.exists?(@location.id), "archiving is the way out; destroy is not"
  end

  test "the opt-in cascade takes the moments and the likes on them" do
    @reader.likes.create!(likeable: @moment)

    assert_difference [ -> { Location.count }, -> { Moment.count }, -> { Like.count } ], -1 do
      @location.destroy_with_traveller_records!
    end

    @location = nil
  end

  test "the author can like their own moment once it is public" do
    assert @moment.likeable?

    assert_difference -> { @moment.reload.likes_count }, 1 do
      @author.likes.create!(likeable: @moment)
    end

    assert @moment.liked_by?(@author)
  end

  test "nobody can like a private moment, its author least of all" do
    private_one = @author.moments.build(plan: @plan, location: @location, note: "mine alone")
    private_one.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "mine.jpg",
                             content_type: "image/jpeg")
    private_one.save!

    assert_not private_one.likeable?, "no audience means no reaction, and no heart is rendered"
    assert_nil Moment.publicly_visible.find_by(id: private_one.id),
      "the like route resolves through publicly_visible, so it is not reachable to react to"
  end

  private

  def public_moment
    moment = @author.moments.build(plan: @plan, location: @location, note: "lifecycle")
    moment.photo.attach(io: File.open(file_fixture("real_image.jpg")), filename: "life.jpg",
                        content_type: "image/jpeg")
    moment.save!
    moment.update_columns(visibility: Moment.visibilities[:public_moment],
                          moderation_status: Moment.moderation_statuses[:approved])
    Browse.sync_record(moment.reload)
    moment
  end
end
