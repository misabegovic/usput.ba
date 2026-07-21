require "test_helper"
require_relative "../../support/mine_checker_fixtures"

# The no-database engine must agree with the PostGIS engine everywhere it
# matters, and where quantization forces a difference it must ALWAYS err
# toward the more dangerous band (conservative property).
class MineChecker::StaticIndexTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  SEVERITY = { "no_known" => 0, "caution" => 1, "danger" => 2 }.freeze

  def with_static_artifacts
    @points = MineCheckerFixtures.install!
    dir = Rails.root.join("tmp/static_index_test").to_s
    FileUtils.rm_rf(dir)
    old = ENV["MINE_STATIC_DIR"]
    ENV["MINE_STATIC_DIR"] = dir
    MineChecker::StaticIndex.reset!
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    load Rails.root.join("lib/tasks/mine_static.rake") unless Rake::Task.task_defined?("mine_static:build")
    Rake::Task["mine_static:build"].reenable
    capture_io { Rake::Task["mine_static:build"].invoke }
    MineChecker::StaticIndex.reset!
    yield MineChecker::StaticIndex.instance
  ensure
    ENV["MINE_STATIC_DIR"] = old
    MineChecker::StaticIndex.reset!
    FileUtils.rm_rf(dir)
  end

  test "static bands agree with the db engine on the fixture points" do
    with_static_artifacts do |index|
      assert index.available?
      assert_equal "danger", index.band_at(@points[:inside][:lat], @points[:inside][:lon])
      assert_equal "danger", index.band_at(@points[:near][:lat], @points[:near][:lon])
      assert_equal "no_known", index.band_at(@points[:clear][:lat], @points[:clear][:lon])
      assert_equal "out_of_coverage", index.band_at(42.0, 14.5)
    end
  end

  test "static engine is never milder than the db engine around the fixture polygon" do
    with_static_artifacts do |index|
      base = @points[:inside]
      regressions = []
      (-10..10).each do |dr|
        (-10..10).each do |dc|
          lat = base[:lat] + dr * 0.003
          lon = base[:lon] + dc * 0.003
          db = MineChecker::Bands.db_band_at(lat, lon)
          static = index.band_at(lat, lon)
          next if static == "out_of_coverage"

          regressions << [ lat, lon, db, static ] if SEVERITY.fetch(static, 0) < SEVERITY.fetch(db, 0)
        end
      end
      assert_empty regressions, "static must never report a milder band than db: #{regressions.first(5).inspect}"
    end
  end

  test "static board cells cover the db board cells at the fixture polygon" do
    with_static_artifacts do |index|
      lat = @points[:inside][:lat]
      lon = @points[:inside][:lon]
      dlat = 100 / 111_320.0
      dlon = 100 / (111_320.0 * Math.cos(lat * Math::PI / 180))
      south = lat - 7 * dlat
      west = lon - 7 * dlon
      static_cells = index.mine_cells(south: south, west: west, dlat: dlat, dlon: dlon, rows: 14, cols: 14)
      assert static_cells.any?, "board over the fixture polygon must contain static mine cells"

      db_cells = ActiveRecord::Base.connection.select_rows(ActiveRecord::Base.sanitize_sql([ <<~SQL, { south: south, west: west, dlat: dlat, dlon: dlon } ])).map { |r, c| [ r.to_i, c.to_i ] }
        SELECT r, c
        FROM generate_series(0, 13) AS r, generate_series(0, 13) AS c
        WHERE EXISTS (
          SELECT 1 FROM mine_areas
          WHERE kind = 'suspected'
            AND ST_Intersects(geom, ST_MakeEnvelope(
              :west + c * :dlon, :south + r * :dlat,
              :west + (c + 1) * :dlon, :south + (r + 1) * :dlat, 4326)::geography)
        )
      SQL
      missing = db_cells - static_cells
      assert_empty missing, "every db mine cell must also be a static mine cell (conservative): #{missing.inspect}"
    end
  end

  test "check endpoint honours the static engine" do
    with_static_artifacts do
      app = ActionDispatch::Integration::Session.new(Rails.application)
      app.post "/mine-check/check", params: { lat: @points[:inside][:lat], lon: @points[:inside][:lon], engine: "static" }, as: :json
      body = JSON.parse(app.response.body)
      assert_equal "static", body["engine"]
      assert_equal "danger", body["band"]
    end
  end

  test "static engine without artifacts fails closed" do
    old = ENV["MINE_STATIC_DIR"]
    ENV["MINE_STATIC_DIR"] = Rails.root.join("tmp/definitely_missing_static").to_s
    MineChecker::StaticIndex.reset!
    assert_equal "unavailable", MineChecker::StaticIndex.instance.band_at(44.0, 17.5)
  ensure
    ENV["MINE_STATIC_DIR"] = old
    MineChecker::StaticIndex.reset!
  end
end
