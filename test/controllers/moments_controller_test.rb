# frozen_string_literal: true

require "test_helper"

class MomentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(username: "mem_owner", password: "password123")
    @stranger = User.create!(username: "mem_stranger", password: "password123")
    @location = Location.create!(name: "Moment Loc", city: "Sarajevo", lat: 43.8563, lng: 18.4131)
    @experience = Experience.create!(title: "Moment Exp", description: "desc")
    @experience.locations << @location
    @plan = Plan.create!(title: "Moment Trip", city_name: "Sarajevo", visibility: :public_plan, user: @owner)
    @plan.plan_experiences.create!(experience: @experience, day_number: 1)
  end

  teardown do
    Moment.destroy_all
    @plan&.destroy
    @experience&.destroy
    @location&.destroy
    @owner&.destroy
    @stranger&.destroy
  end

  test "create requires login" do
    assert_no_difference "Moment.count" do
      post plan_moments_path(@plan), params: moment_params
    end

    assert_redirected_to login_path
  end

  test "create attaches a moment to the plan location" do
    login_as(@owner)

    assert_difference "Moment.count", 1 do
      post plan_moments_path(@plan), params: moment_params
    end

    moment = Moment.last
    assert_equal @owner, moment.user
    assert_equal @plan, moment.plan
    assert_equal @location, moment.location
    assert moment.photo.attached?
  end

  test "create rejects a non-image upload" do
    login_as(@owner)

    assert_no_difference "Moment.count" do
      post plan_moments_path(@plan), params: moment_params(type: "text/plain")
    end
  end

  test "the plan page no longer renders moments (capture moved to the walk)" do
    login_as(@owner)
    post plan_moments_path(@plan), params: moment_params(note: "Owner's private moment")

    get plan_path(@plan)

    assert_response :success
    assert_no_match "Owner's private moment", response.body
  end

  test "destroy removes the owner's moment" do
    login_as(@owner)
    post plan_moments_path(@plan), params: moment_params
    moment = Moment.last

    assert_difference "Moment.count", -1 do
      delete plan_moment_path(@plan, moment)
    end
  end

  test "destroy from the browse band removes just that card" do
    login_as(@owner)
    post plan_moments_path(@plan), params: moment_params
    moment = Moment.last

    delete plan_moment_path(@plan, moment), params: { context: "browse" }, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.body
    assert_match ActionView::RecordIdentifier.dom_id(moment), response.body
    refute Moment.exists?(moment.id)
  end

  test "destroy cannot reach another user's moment" do
    login_as(@owner)
    post plan_moments_path(@plan), params: moment_params
    moment = Moment.last
    delete logout_path

    login_as(@stranger)

    assert_no_difference "Moment.count" do
      delete plan_moment_path(@plan, moment)
    end

    assert_response :not_found
  end

  test "create on the walk shows the error instead of silently doing nothing" do
    login_as(@owner)

    assert_no_difference "Moment.count" do
      post plan_moments_path(@plan), params: moment_params(type: "text/plain"), as: :turbo_stream
    end

    assert_response :success
    assert_match "JPEG", response.body
  end

  test "create refuses a private plan the user does not own" do
    private_plan = Plan.create!(title: "Private Trip", city_name: "Sarajevo", visibility: :private_plan, user: @owner)
    login_as(@stranger)

    assert_no_difference "Moment.count" do
      post plan_moments_path(private_plan), params: moment_params
    end

    assert_response :not_found
  ensure
    private_plan&.destroy
  end

  test "create allows a public plan the user does not own" do
    login_as(@stranger)

    assert_difference "Moment.count", 1 do
      post plan_moments_path(@plan), params: moment_params
    end

    assert_equal @stranger, Moment.last.user
  end

  test "the owner publishes a moment, which enters moderation" do
    login_as(@owner)
    post plan_moments_path(@plan), params: moment_params
    moment = Moment.last

    patch publish_plan_moment_path(@plan, moment)

    assert moment.reload.visibility_public_moment?
    assert moment.pending?, "a freshly published moment is pending review"
  end

  test "the owner unpublishes a moment back to private" do
    login_as(@owner)
    post plan_moments_path(@plan), params: moment_params
    moment = Moment.last
    moment.update!(visibility: :public_moment)

    patch unpublish_plan_moment_path(@plan, moment)

    assert moment.reload.visibility_private_moment?
  end

  test "a stranger cannot publish another traveller's moment" do
    login_as(@owner)
    post plan_moments_path(@plan), params: moment_params
    moment = Moment.last

    login_as(@stranger)
    patch publish_plan_moment_path(@plan, moment)

    assert moment.reload.visibility_private_moment?, "only the owner may publish"
  end

  test "a public moment's tile carries the link that opens it" do
    moment = publish_moment

    get location_moments_path(@location.uuid, context: "location")

    assert_response :success
    tile = css_select("[data-moment-id='#{moment.public_id}']").first
    assert_equal moment_url(moment), tile["data-moment-share-url"]
  end

  test "a private moment's tile carries no link to share" do
    login_as(@owner)
    moment = @owner.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: File.open(file_fixture("test_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!

    get location_moments_path(@location.uuid, context: "location")

    assert_response :success
    tile = css_select("[data-moment-id='#{moment.public_id}']").first
    assert_nil tile["data-moment-share-url"]
  end

  # Own and public are two scopes a traveller's own approved moment used to sit in
  # at once, so every count that added them together said one more than existed.
  test "a traveller's own public moment is counted once, not once per list" do
    publish_moment
    login_as(@owner)

    get location_moments_path(@location.uuid, context: "location")

    assert_response :success
    assert_equal 1, css_select("[data-moment-id]").size
    gallery = css_select("[data-photo-gallery-total-value]").first
    assert_equal "1", gallery["data-photo-gallery-total-value"]
  end

  # load_more sends "<resource>_page", so the gallery's loader asks for
  # moments_page. Reading only :page pinned every request to the first page.
  test "the gallery pages on the name its loader sends" do
    publish_moment
    login_as(@owner)

    get location_moments_path(@location.uuid, context: "location",
                              partial: "moments", moments_page: 2)

    assert_response :success
    assert_equal 0, css_select("[data-moment-id]").size
  end

  private

  def publish_moment
    moment = @owner.moments.build(plan: @plan, location: @location)
    moment.photo.attach(io: File.open(file_fixture("test_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(visibility: :public_moment)
    moment.update!(moderation_status: :approved)
    moment
  end

  def login_as(user)
    post login_path, params: { username: user.username, password: "password123" }
  end

  def moment_params(type: "image/jpeg", note: nil)
    {
      moment: {
        location_id: @location.uuid,
        note: note,
        photo: fixture_file_upload("test_image.jpg", type)
      }
    }
  end
end
