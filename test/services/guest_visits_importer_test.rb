# frozen_string_literal: true

require "test_helper"

# Check-ins made without an account are held on the device and replayed here at
# sign-in. The replay has to be safe to run twice, has to join a walk already in
# progress rather than start a second one, and has to survive a payload the
# device (or anyone posting as it) got wrong.
class GuestVisitsImporterTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "returning", password: "password123")
    @near = Location.create!(name: "Guest Fort", city: "Sarajevo", lat: 43.85, lng: 18.41)
    @other = Location.create!(name: "Guest Bridge", city: "Mostar", lat: 43.34, lng: 17.81)
  end

  teardown do
    @user&.destroy
    [ @near, @other ].each { |location| location&.destroy }
  end

  test "a guest's check-ins become visits on the explore plan" do
    payload = [ { "id" => @near.uuid }, { "id" => @other.uuid } ].to_json

    importer = GuestVisitsImporter.new(user: @user, payload: payload).call

    assert importer.success?
    assert_equal 2, importer.imported_count
    plan = Plan.explore_bosnia_for(@user)
    assert_equal [ @near.id, @other.id ].sort, @user.plan_visits.where(plan: plan).pluck(:location_id).sort
  end

  test "replaying the same payload adds nothing and raises nothing" do
    payload = [ { "id" => @near.uuid } ].to_json
    GuestVisitsImporter.new(user: @user, payload: payload).call

    assert_no_difference "PlanVisit.count" do
      importer = GuestVisitsImporter.new(user: @user, payload: payload).call
      assert importer.success?
      assert_equal 0, importer.imported_count
    end
  end

  test "an explore plan already opened is joined, not restarted" do
    existing = Plan.explore_bosnia_for(@user)

    assert_no_difference "Plan.count" do
      GuestVisitsImporter.new(user: @user, payload: [ { "id" => @other.uuid } ].to_json).call
    end

    assert_equal [ @other.id ], @user.plan_visits.where(plan: existing).pluck(:location_id)
  end

  # The device's list is the one check-in path that cannot re-verify the 100 m
  # gate. An account holding visits has claimed its walk and the server is
  # authoritative from then on, or signing out and back in would let a traveller
  # write visits for places nothing ever stood near.
  test "an account that already holds a visit imports nothing more" do
    @user.plan_visits.create!(plan: Plan.explore_bosnia_for(@user), location: @near)

    importer = GuestVisitsImporter.new(user: @user, payload: [ { "id" => @other.uuid } ].to_json).call

    assert importer.success?
    assert_equal 0, importer.imported_count
    assert_equal [ @near.id ], @user.plan_visits.pluck(:location_id)
  end

  test "a place the traveller already visited is not duplicated" do
    plan = Plan.explore_bosnia_for(@user)
    @user.plan_visits.create!(plan: plan, location: @near)

    importer = GuestVisitsImporter.new(user: @user, payload: [ { "id" => @near.uuid } ].to_json).call

    assert importer.success?
    assert_equal 1, @user.plan_visits.where(plan: plan, location: @near).count
  end

  test "duplicates within one payload collapse" do
    payload = [ { "id" => @near.uuid }, { "id" => @near.uuid } ].to_json

    importer = GuestVisitsImporter.new(user: @user, payload: payload).call

    assert_equal 1, importer.imported_count
    assert_equal 1, @user.plan_visits.where(location: @near).count
  end

  test "unknown, malformed and empty payloads are dropped without raising" do
    [ nil, "", "not json", "{}", [].to_json, [ { "id" => "no-such-uuid" } ].to_json,
      [ { "id" => nil }, [ "nested" ], 42 ].to_json ].each do |payload|
      importer = GuestVisitsImporter.new(user: @user, payload: payload).call

      assert importer.success?, "expected #{payload.inspect} to be handled"
      assert_equal 0, importer.imported_count
    end

    assert_equal 0, @user.plan_visits.count
  end

  test "a payload of bare uuid strings is accepted" do
    importer = GuestVisitsImporter.new(user: @user, payload: [ @near.uuid ].to_json).call

    assert_equal 1, importer.imported_count
  end

  test "an oversized payload is capped, and the cap counts distinct places" do
    padding = Array.new(GuestVisitsImporter::MAX_VISITS) { |i| "padding-uuid-#{i}" }
    payload = (padding + [ @near.uuid ]).to_json

    importer = GuestVisitsImporter.new(user: @user, payload: payload).call

    assert importer.success?
    # The real uuid sat past the cap, so it never reached the query.
    assert_equal 0, importer.imported_count
  end

  test "repetition does not consume the cap" do
    payload = (Array.new(GuestVisitsImporter::MAX_VISITS, "padding-uuid") + [ @near.uuid ]).to_json

    importer = GuestVisitsImporter.new(user: @user, payload: payload).call

    # Deduplication happens before the cap, so one uuid repeated 500 times costs
    # one slot rather than all of them.
    assert_equal 1, importer.imported_count
  end

  test "the replay costs a fixed number of queries however long the walk" do
    uuids = [ @near.uuid, @other.uuid ]
    Plan.explore_bosnia_for(@user) # created on first sign-in either way; not per visit

    one = count_queries { GuestVisitsImporter.new(user: @user, payload: [ uuids.first ].to_json).call }
    PlanVisit.where(user: @user).destroy_all
    two = count_queries { GuestVisitsImporter.new(user: @user, payload: uuids.to_json).call }

    assert_equal one, two, "the importer must not query per visit"
  end

  private

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(BEGIN|COMMIT)/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
