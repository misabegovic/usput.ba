# frozen_string_literal: true

require "test_helper"

# The commands bin/usput and the MCP server share: what each answers, and
# whom each refuses.
class Usput::CommandsTest < ActiveSupport::TestCase
  setup do
    @traveller = person(:basic)
    @curator = person(:curator)
    @admin = person(:admin)
    @live = Location.create!(name: "Vrelo Bosne", city: "Ilidža", lat: 43.8186, lng: 18.2683, tags: [ "izvor" ])
    @retired = Location.create!(name: "Stara pilana", city: "Ilidža", lat: 43.8200, lng: 18.2700, archived_at: Time.current)
  end

  test "places.list shows live places and retired ones only to curators" do
    names = run_as(nil, "places.list", city: "Ilidža").pluck(:name)

    assert_includes names, "Vrelo Bosne"
    assert_not_includes names, "Stara pilana"
    assert_raises(Usput::Command::Denied) { run_as(@traveller, "places.list", archived: "true") }
    assert_equal [ "Stara pilana" ], run_as(@curator, "places.list", archived: true, city: "Ilidža").pluck(:name)
  end

  test "places.list filters by tag and coerces its limit" do
    assert_equal [ @live.uuid ], run_as(nil, "places.list", tag: "izvor", limit: "5").pluck(:id)
  end

  test "places.show hides a retired place from anyone but a curator" do
    assert_equal "Vrelo Bosne", run_as(nil, "places.show", id: @live.uuid)[:name]
    assert_raises(Usput::Command::Denied) { run_as(@traveller, "places.show", id: @retired.uuid) }
    assert run_as(@curator, "places.show", id: @retired.uuid)[:archived]
  end

  test "places.archive is a curator's decision, recorded once" do
    assert_raises(Usput::Command::Denied) { run_as(@traveller, "places.archive", id: @live.uuid) }

    result = run_as(@curator, "places.archive", id: @live.uuid)

    assert result[:changed]
    assert @live.reload.archived?
    assert_instance_of PlaceArchived, DecisionLog.history(@live).last
    assert_not run_as(@curator, "places.archive", id: @live.uuid)[:changed]
    assert_equal 1, DecisionLog.history(@live).size

    run_as(@curator, "places.restore", id: @live.uuid)
    assert_not @live.reload.archived?
  end

  test "the moments queue and its decisions are a curator's" do
    moment = public_moment

    assert_raises(Usput::Command::Denied) { run_as(@traveller, "moments.queue") }
    assert_equal [ moment.uuid ], run_as(@curator, "moments.queue").pluck(:id)

    run_as(@curator, "moments.approve", id: moment.uuid)

    assert moment.reload.approved?
    assert_instance_of MomentApproved, DecisionLog.history(moment).last
    assert_empty run_as(@curator, "moments.queue")
  end

  test "a curator decides a held review and the overturn is recorded" do
    review = @live.reviews.create!(rating: 2, comment: "Hladno", user: @traveller, moderation_status: :held, jev_band: "held")

    assert_equal [ review.uuid ], run_as(@curator, "reviews.queue").pluck(:id)
    run_as(@curator, "reviews.reject", id: review.uuid)

    assert review.reload.rejected?
    decision = DecisionLog.history(review).last
    assert_instance_of ReviewRejected, decision
    assert_equal({ "decided_by" => "curator", "overturned" => true }, decision.data.stringify_keys.slice("decided_by", "overturned"))
  end

  test "reviews.judge shows Jev's band and records nothing" do
    review = @live.reviews.create!(rating: 5, comment: "Divno", user: @traveller)
    reading = ReviewModeration::Result.new(band: :approved, answers: { "abusive" => 0.01, "spam" => 0.02 },
                                           model: "jev-1.13.0", skip: nil)

    result = ReviewModeration.stub(:screen, reading) { run_as(@curator, "reviews.judge", id: review.uuid) }

    assert_equal "approved", result[:band]
    assert_not result[:recorded]
    assert_nil review.reload.judged_at
    assert_empty DecisionLog.history(review)
  end

  test "plans.show refuses a private plan to anyone but its owner" do
    plan = Plan.create!(title: "Moj vikend", city_name: "Ilidža", visibility: :private_plan, user: @traveller)
    plan.add_location(@live, day_number: 1)
    plan.add_location(@retired, day_number: 1)

    assert_raises(Usput::Command::Denied) { run_as(@curator, "plans.show", id: plan.uuid) }
    days = run_as(@traveller, "plans.show", id: plan.uuid)[:days]
    assert_equal [ { day: 1, experiences: [], stops: [ @live.uuid ] } ], days
  end

  test "search answers with public ids, never database ids" do
    result = run_as(nil, "search", query: "Vrelo")

    assert_includes result, { type: "location", id: @live.uuid, title: "Vrelo Bosne", city: "Ilidža", rating: 0.0 }
  end

  test "history reads a record's stream, for curators" do
    Decisions.archive(@live, by: @admin)

    assert_raises(Usput::Command::Denied) { run_as(@traveller, "history", kind: "place", id: @live.uuid) }
    events = run_as(@curator, "history", kind: "place", id: @live.uuid)
    assert_equal [ "PlaceArchived" ], events.pluck(:event)
  end

  test "doctor answers yes and no for admins only" do
    assert_raises(Usput::Command::Denied) { run_as(@curator, "doctor") }

    report = run_as(@admin, "doctor")

    assert report[:database][:connected]
    assert_includes [ true, false ], report[:keys][:jev]
  end

  test "an unknown parameter, a missing one and a wrong type are refused by name" do
    {
      [ "places.list", { colour: "red" } ] => /unknown parameter colour/,
      [ "places.show", {} ] => /id is required/,
      [ "places.list", { limit: "many" } ] => /limit must be integer/,
      [ "moments.queue", { status: "lost" } ] => /status must be one of/
    }.each do |(name, args), message|
      error = assert_raises(Usput::Command::Invalid) { run_as(@curator, name, **args) }
      assert_match message, error.message
    end
  end

  test "every command is named, summarised and described as a JSON schema" do
    Usput::Commands.all.each do |command|
      assert_match(/\A[a-z]+(\.[a-z]+)?\z/, command.command_name)
      assert command.summary.present?, command.command_name
      assert_equal command.params.map { |param| param.name.to_s }.sort, command.input_schema[:properties].keys.sort
    end
  end

  private

  def run_as(actor, name, **args)
    Usput::Commands.find(name).call(actor:, **args)
  end

  def person(role)
    User.create!(username: "cmd_#{role}", email: "cmd_#{role}@example.com", password: "password123", user_type: role).tap(&:confirm)
  end

  def public_moment
    plan = Plan.explore_bosnia_for(@traveller)
    @traveller.plan_visits.create!(plan:, location: @live)
    moment = @traveller.moments.build(plan:, location: @live)
    moment.photo.attach(io: File.open(file_fixture("test_image.jpg")), filename: "m.jpg", content_type: "image/jpeg")
    moment.save!
    moment.update!(visibility: :public_moment)
    moment
  end
end
