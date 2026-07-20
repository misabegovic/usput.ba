require "test_helper"

# SPEC §3/§8 — the import pipeline on the real dataset: DATA_AS_OF guard,
# degenerate-ring buffering, sanity gates. This is the slowest test in the
# suite by design — it exercises the exact path a fresh clone runs.
class MineDataImportTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def run_import(env = {})
    Rake::Task["mine_data:import"].reenable
    old = {}
    env.each { |k, v| old[k] = ENV[k]; ENV[k] = v }
    capture_io { Rake::Task["mine_data:import"].invoke }
  ensure
    env.each_key { |k| ENV[k] = old[k] }
  end

  setup do
    # Load only the mine_data tasks — Rails.application.load_tasks would pull
    # every lib/tasks file into the SimpleCov denominator.
    unless Rake::Task.task_defined?("mine_data:import")
      Rake::Task.define_task(:environment)
      load Rails.root.join("lib/tasks/mine_data.rake")
    end
  end

  test "import without DATA_AS_OF aborts" do
    assert_raises(SystemExit) { run_import("DATA_AS_OF" => nil) }
  end

  test "full import loads all layers, buffers degenerates and passes sanity gates" do
    run_import("DATA_AS_OF" => "2024-07-31")

    assert_operator MineArea.suspected.count, :>=, 10_000
    assert_equal Date.new(2024, 7, 31), MineArea.maximum(:data_as_of)
    assert_equal %w[cleared incident lifted suspected], MineArea.distinct.pluck(:kind).sort

    conn = ActiveRecord::Base.connection
    invalid = conn.select_value("SELECT COUNT(*) FROM mine_areas WHERE NOT ST_IsValid(geom::geometry)").to_i
    assert_equal 0, invalid

    # Degenerate rings became real areas (buffered polygons), not points:
    # every suspected geometry must have a positive area or be a surface.
    zero_area = conn.select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM mine_areas
      WHERE kind = 'suspected'
        AND ST_Area(geom) <= 0
    SQL
    assert_equal 0, zero_area, "degenerate rings must be buffered into areas, never imported flat"

    # Import is idempotent: second run replaces, not duplicates.
    before = MineArea.count
    run_import("DATA_AS_OF" => "2024-07-31")
    assert_equal before, MineArea.count
  end

  test "import aborts when the dataset fails sanity gates" do
    dir = Rails.root.join("tmp/mine_sanity_test")
    FileUtils.mkdir_p(dir)
    tiny = {
      "type" => "FeatureCollection",
      "features" => [
        { "type" => "Feature", "properties" => { "fileId" => "0000-I" },
          "geometry" => { "type" => "Polygon",
                          "coordinates" => [ [ [ 17.0, 44.0 ], [ 17.01, 44.0 ], [ 17.01, 44.01 ], [ 17.0, 44.0 ] ] ] } }
      ]
    }.to_json
    %w[suspect_areas_original cleared_areas_original lifted_minefields incidents].each do |name|
      File.write(dir.join("#{name}.geojson"), tiny)
    end

    err = assert_raises(SystemExit) do
      run_import("DATA_AS_OF" => "2024-07-31", "MINE_DATA_DIR" => dir.to_s)
    end
    assert_match(/sanity/, err.message)
  ensure
    FileUtils.rm_rf(dir)
  end

  test "audit_existing lists blocked locations without deleting them" do
    require_relative "../support/mine_checker_fixtures"
    points = MineCheckerFixtures.install!
    clear = Location.new(name: "Audit čisto", uuid: SecureRandom.uuid,
                         lat: points[:clear][:lat], lng: points[:clear][:lon])
    clear.save!(validate: false)
    inside = Location.new(name: "Audit unutra", uuid: SecureRandom.uuid,
                          lat: points[:inside][:lat], lng: points[:inside][:lon])
    inside.save!(validate: false)

    Rake::Task["mine_data:audit_existing"].reenable
    out, = capture_io { Rake::Task["mine_data:audit_existing"].invoke }

    assert_match("Location##{inside.id}", out)
    refute_match("Location##{clear.id}", out)
    assert Location.exists?(inside.id), "audit must never delete content"
  ensure
    inside&.destroy
    clear&.destroy
  end
end
