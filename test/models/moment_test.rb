# frozen_string_literal: true

require "test_helper"

class MomentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(username: "moment_owner", password: "password123")
    @other_user = User.create!(username: "moment_stranger", password: "password123")
    @location = Location.create!(name: "Moment Location", city: "Mostar", lat: 43.34, lng: 17.81)
    @plan = Plan.create!(title: "Moment Plan", city_name: "Mostar", visibility: :private_plan, user: @user)
  end

  teardown do
    @plan&.destroy
    @location&.destroy
    @user&.destroy
    @other_user&.destroy
  end

  test "valid moment is saved" do
    moment = build_moment

    assert moment.valid?
    assert moment.save
  end

  test "requires a photo" do
    moment = @user.moments.build(plan: @plan, location: @location)

    assert_not moment.valid?
    assert_includes moment.errors[:photo], "can't be blank"
  end

  test "rejects a non-image upload" do
    moment = build_moment(content_type: "application/pdf", filename: "not_a_photo.pdf")

    assert_not moment.valid?
    assert_includes moment.errors[:photo], "must be JPEG, PNG, GIF, or WebP"
  end

  test "rejects a note longer than 1000 characters" do
    moment = build_moment
    moment.note = "a" * 1001

    assert_not moment.valid?
  end

  test "generates a uuid and exposes it as the public id" do
    moment = build_moment
    moment.save!

    assert moment.uuid.present?
    assert_equal moment.uuid, moment.to_param
    assert_equal moment, Moment.find_by_public_id(moment.uuid)
  end

  test "the same location on two plans keeps two separate moments" do
    other_plan = Plan.create!(title: "Second Trip", city_name: "Mostar", visibility: :private_plan, user: @user)
    build_moment.save!
    build_moment(plan: other_plan).save!

    assert_equal 2, @user.moments.where(location: @location).count
  ensure
    other_plan&.destroy
  end

  # A moment is bound to the location, not to the itinerary that brought the
  # traveller there, so deleting the plan re-homes it instead of taking it.
  test "outlives its plan on the traveller's explore plan" do
    moment = build_moment
    moment.save!

    assert_no_difference "Moment.count" do
      @plan.destroy
    end

    assert_equal Plan.explore_bosnia_for(@user).id, moment.reload.plan_id
    assert_equal @location.id, moment.location_id
  end

  test "is destroyed with its user" do
    build_moment.save!

    assert_difference "Moment.count", -1 do
      @user.destroy
    end
  end

  test "another user's moments are not reachable through this user" do
    build_moment.save!

    assert_equal 0, @other_user.moments.count
  end

  test "a new moment is private and pending by default" do
    moment = build_moment
    moment.save!

    assert moment.visibility_private_moment?
    assert moment.pending?
  end

  test "publicly_visible returns only approved public moments" do
    build_moment.save! # private
    build_moment.tap { |m| m.update!(visibility: :public_moment) } # public, pending
    approved = build_moment.tap do |m|
      m.update!(visibility: :public_moment)
      m.update!(moderation_status: :approved)
    end

    assert_equal [ approved ], Moment.publicly_visible.to_a
  end

  test "going public re-enters moderation, even after a prior approval" do
    moment = build_moment
    moment.update!(visibility: :public_moment)
    moment.update!(moderation_status: :approved)
    assert moment.approved?

    moment.update!(visibility: :private_moment)
    moment.update!(visibility: :public_moment)

    assert moment.pending?, "going public again must require a fresh approval"
  end

  test "only an approved public moment is indexed in Browse" do
    private_m = build_moment.tap(&:save!)
    pending = build_moment.tap { |m| m.update!(visibility: :public_moment) }
    approved = build_moment.tap do |m|
      m.update!(visibility: :public_moment)
      m.update!(moderation_status: :approved)
    end

    assert Browse.exists?(browsable: approved)
    assert_not Browse.exists?(browsable: private_m)
    assert_not Browse.exists?(browsable: pending)
  end

  test "turning an indexed moment private removes it from Browse" do
    moment = build_moment
    moment.update!(visibility: :public_moment)
    moment.update!(moderation_status: :approved)
    assert Browse.exists?(browsable: moment)

    moment.update!(visibility: :private_moment)

    assert_not Browse.exists?(browsable: moment), "an unpublished moment must leave the index"
  end

  test "an approved public moment is found by searching its note" do
    moment = build_moment
    moment.note = "sunset kayak"
    moment.save!
    moment.update!(visibility: :public_moment)
    moment.update!(moderation_status: :approved)

    assert Browse.moments.smart_search("kayak").exists?(browsable: moment)
  end

  test "deleting a moment purges its photo file from storage (S3 in production)" do
    moment = build_moment
    moment.save!
    blob = moment.photo.blob
    assert blob.service.exist?(blob.key), "the file is in storage before delete"

    perform_enqueued_jobs { moment.destroy }

    assert_not ActiveStorage::Blob.exists?(id: blob.id), "the blob record must be removed"
    assert_not blob.service.exist?(blob.key), "the file must be deleted from storage"
  end

  test "deleting the plan leaves the moment's photo in storage" do
    moment = build_moment
    moment.save!
    blob = moment.photo.blob

    perform_enqueued_jobs { @plan.destroy }

    assert blob.service.exist?(blob.key), "deleting an itinerary must not purge a traveller's photo"
    assert moment.reload.photo.attached?
  end

  test "recent_own caps a traveller's collection at the newest slice" do
    made = (Moment::OWN_LIMIT + 3).times.map { build_moment.tap(&:save!) }

    recent = @user.moments.recent_own.to_a

    assert_equal Moment::OWN_LIMIT, recent.size
    assert_equal made.last(Moment::OWN_LIMIT).map(&:id).reverse, recent.map(&:id)
  end

  test "recent_public caps a place's shared moments and hides unapproved ones" do
    (Moment::PUBLIC_LIMIT + 2).times { publish(build_moment.tap(&:save!)) }
    pending = build_moment
    pending.visibility = :public_moment
    pending.save!

    shared = Moment.where(location: @location).recent_public.to_a

    assert_equal Moment::PUBLIC_LIMIT, shared.size
    assert_not_includes shared.map(&:id), pending.id
  end

  private

  def publish(moment)
    moment.update!(visibility: :public_moment)
    moment.update_column(:moderation_status, Moment.moderation_statuses[:approved])
    moment
  end

  def build_moment(plan: @plan, content_type: "image/jpeg", filename: "moment.jpg")
    moment = @user.moments.build(plan: plan, location: @location)
    moment.photo.attach(
      io: StringIO.new("fake image data"),
      filename: filename,
      content_type: content_type
    )
    moment
  end
end
