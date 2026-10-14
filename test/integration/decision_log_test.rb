# frozen_string_literal: true

require "test_helper"

# Every decision taken in the admin lands in Rails Event Store, in the
# stream of the record it was about, with who took it.
class DecisionLogTest < ActionDispatch::IntegrationTest
  setup do
    @admin = person(:admin)
    @curator = person(:curator)
    @traveller = person(:basic)
  end

  test "approving and then rejecting a moment leaves both decisions in its stream, in order" do
    place = Location.create!(name: "Vrelo Bosne", city: "Ilidža", lat: 43.8186, lng: 18.2696)
    plan = Plan.create!(title: "Ilidža day", city_name: "Ilidža", user: @traveller)
    @traveller.plan_visits.create!(plan: plan, location: place)
    moment = @traveller.moments.build(plan: plan, location: place, note: "Swans")
    moment.photo.attach(io: File.open("test/fixtures/files/real_image.jpg"), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(visibility: :public_moment)
    sign_in @curator

    run_action "moments", "ApproveMoment", moment
    run_action "moments", "RejectMoment", moment

    history = DecisionLog.history(moment)
    assert_equal [ MomentApproved, MomentRejected ], history.map(&:class)
    assert_equal({ "record" => moment.uuid, "by" => @curator.uuid }, history.first.data.stringify_keys)
  end

  test "archiving and restoring a place are recorded against the place" do
    place = Location.create!(name: "Stari most", city: "Mostar", lat: 43.3373, lng: 17.8150)
    sign_in @curator

    run_action "locations", "ArchiveLocation", place
    run_action "locations", "RestoreLocation", place

    assert_equal [ PlaceArchived, PlaceRestored ], DecisionLog.history(place).map(&:class)
  end

  test "a role change records the role it came from and the one it went to" do
    sign_in @admin

    run_action "users", "ChangeRole", @traveller, fields: { role: "curator" }

    change = DecisionLog.history(@traveller).sole
    assert_instance_of UserRoleChanged, change
    assert_equal({ "record" => @traveller.uuid, "by" => @admin.uuid, "from" => "basic", "to" => "curator" },
                 change.data.stringify_keys)
  end

  test "blocking and unblocking are recorded against the account" do
    sign_in @admin

    run_action "users", "BlockUser", @traveller
    run_action "users", "UnblockUser", @traveller

    assert_equal [ UserBlocked, UserUnblocked ], DecisionLog.history(@traveller).map(&:class)
  end

  test "a refused decision records nothing" do
    sign_in @admin

    run_action "users", "BlockUser", @admin

    assert_empty DecisionLog.history(@admin)
  end

  test "only an admin reaches the event browser" do
    get "/event-store"
    assert_redirected_to "/login"

    sign_in @curator
    get "/event-store"
    assert_response :not_found
    sign_out @curator

    sign_in @admin
    get "/event-store"
    follow_redirect!
    assert_response :success
  end

  private

  def run_action(resource, action, record, fields: {})
    post "/admin/resources/#{resource}/actions/Avo::Actions::#{action}",
      params: { fields: fields.merge(avo_resource_ids: record.to_param, avo_selected_all: "false") },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def person(role)
    User.create!(username: "decisions_#{role}", email: "decisions_#{role}@example.com",
                 password: "password123", user_type: role).tap(&:confirm)
  end
end
