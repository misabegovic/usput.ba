require "test_helper"
require_relative "../support/static_artifacts"

# SPEC §6/§8 — the hard-block validation on Location. The user-facing error
# must never reveal geometry or internal details.
class LocationMineCheckTest < ActiveSupport::TestCase
  setup do
    @dir = Rails.root.join("tmp/location_mine_test").to_s
    @points = StaticArtifacts.install!(dir: @dir)
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "creating a location inside a suspected area is invalid" do
    location = Location.new(name: "Test tačka", lat: @points[:inside][:lat], lng: @points[:inside][:lon])
    assert_not location.valid?
    message = location.errors[:base].join(" ")
    assert_match(/sigurnosnih|safety/i, message)
    refute_match(/\d+(\.\d+)?\s*m\b/, message)
    refute_match(/band|danger/i, message)
  end

  test "creating a clear location passes and is audited" do
    location = Location.new(name: "Čista tačka", lat: @points[:clear][:lat], lng: @points[:clear][:lon])
    assert_difference -> { MineCheckAudit.count }, 1 do
      assert location.valid?, location.errors.full_messages.join("; ")
    end
    assert_equal "no_known_intersections", MineCheckAudit.order(:id).last.verdict
  end

  test "old data does not block a clear location" do
    travel_to Date.current + MineChecker::Config.staleness_days.days + 1.day do
      location = Location.new(name: "Stariji podaci", lat: @points[:clear][:lat], lng: @points[:clear][:lon])
      assert location.valid?, location.errors.full_messages.join("; ")
    end
  end

  test "missing artifacts block creation (fail-closed)" do
    ENV["MINE_STATIC_DIR"] = Rails.root.join("tmp/missing_for_location").to_s
    MineChecker::StaticIndex.reset!
    location = Location.new(name: "Bez podataka", lat: @points[:clear][:lat], lng: @points[:clear][:lon])
    assert_not location.valid?
    assert_match(/BHMAC/, location.errors[:base].join(" "))
  end

  test "locations without coordinates skip the check" do
    location = Location.new(name: "Bez koordinata")
    assert_no_difference -> { MineCheckAudit.count } do
      location.valid?
    end
    assert_empty location.errors[:base].grep(/sigurnosnih|safety|BHMAC/)
  end

  test "location outside BiH is out of coverage and not blocked by the mine check" do
    location = Location.new(name: "Jadran", lat: 42.0, lng: 14.5)
    location.valid?
    assert_empty location.errors[:base].grep(/sigurnosnih|safety|BHMAC/)
  end
end
