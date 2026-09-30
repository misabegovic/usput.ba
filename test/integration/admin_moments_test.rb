# frozen_string_literal: true

require "test_helper"

# The moments queue in the admin: travellers publish, curators decide.
class AdminMomentsTest < ActionDispatch::IntegrationTest
  setup do
    @traveller = User.create!(username: "moments_traveller", email: "moments_traveller@example.com", password: "password123")
    @place = Location.create!(name: "Vrelo Bosne", city: "Ilidža", lat: 43.8186, lng: 18.2696)
    @plan = Plan.create!(title: "Ilidža day", city_name: "Ilidža", user: @traveller)
    @moment = moment(public: true, note: "Swans at the spring")
  end

  test "the queue opens on the public moments waiting for a decision" do
    moment(public: false, note: "Just for me")
    moment(public: true, note: "Already fine").update!(moderation_status: :approved)
    sign_in person(:curator)

    get "/admin/resources/moments"

    assert_response :success
    assert_includes response.body, "Swans at the spring"
    assert_not_includes response.body, "Already fine"
    assert_not_includes response.body, "Just for me"
  end

  test "a private moment is not found even by its link" do
    private_moment = moment(public: false, note: "Just for me")
    sign_in person(:curator)

    get "/admin/resources/moments/#{private_moment.to_param}"

    assert_response :not_found
  end

  test "approving publishes the moment and puts it into search" do
    sign_in person(:curator)

    run_action("ApproveMoment", @moment)

    assert @moment.reload.approved?
    assert_includes Moment.publicly_visible, @moment
    assert Browse.exists?(browsable: @moment)
  end

  test "rejecting an approved moment takes it down and out of search" do
    @moment.update!(moderation_status: :approved)
    assert Browse.exists?(browsable: @moment)
    sign_in person(:curator)

    run_action("RejectMoment", @moment)

    assert @moment.reload.rejected?
    assert_not_includes Moment.publicly_visible, @moment
    assert_not Browse.exists?(browsable: @moment)
  end

  test "a rejected moment can be approved again" do
    @moment.update!(moderation_status: :rejected)
    sign_in person(:curator)

    run_action("ApproveMoment", @moment)

    assert @moment.reload.approved?
  end

  test "nobody edits or deletes a moment in the admin" do
    sign_in person(:admin)

    patch "/admin/resources/moments/#{@moment.to_param}", params: { moment: { note: "Changed" } }
    delete "/admin/resources/moments/#{@moment.to_param}"

    assert_equal "Swans at the spring", @moment.reload.note
  end

  test "a traveller cannot reach the queue" do
    sign_in @traveller.tap(&:confirm)

    get "/admin/resources/moments"

    assert_response :not_found
  end

  # === The photo ===

  test "the admin serves a public moment's photo itself, never a blob url" do
    sign_in person(:curator)

    get "/admin/resources/moments"
    src = "/admin/moment_photos/#{@moment.to_param}?size=thumb"
    assert_includes response.body, %(src="#{src}")
    assert_not_includes response.body, "/rails/active_storage/"

    get src
    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "a private moment's photo is not served to the admin" do
    private_moment = moment(public: false, note: "Just for me")
    sign_in person(:curator)

    get "/admin/moment_photos/#{private_moment.to_param}"

    assert_response :not_found
  end

  test "a traveller cannot fetch a photo through the admin" do
    sign_in @traveller.tap(&:confirm)

    get "/admin/moment_photos/#{@moment.to_param}"

    assert_response :not_found
  end

  test "the old curator queue is gone" do
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/curator/moments") }
  end

  private

  def moment(public:, note:)
    record = @traveller.moments.build(plan: @plan, location: @place, note: note)
    record.photo.attach(io: File.open("test/fixtures/files/real_image.jpg"), filename: "moment.jpg", content_type: "image/jpeg")
    record.save!
    record.update!(visibility: :public_moment) if public
    record
  end

  def run_action(action, record)
    post "/admin/resources/moments/actions/Avo::Actions::#{action}",
      params: { fields: { avo_resource_ids: record.to_param, avo_selected_all: "false" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def person(role)
    User.create!(username: "admin_moments_#{role}", email: "admin_moments_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end
end
