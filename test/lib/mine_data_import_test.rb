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
    Rails.application.load_tasks unless Rake::Task.task_defined?("mine_data:import")
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
end
