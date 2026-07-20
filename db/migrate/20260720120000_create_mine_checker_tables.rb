# Mine Checker Phase 1 (docs/mine_checker/SPEC.md §4, §6).
#
# mine_areas holds the EUFOR MICC / BHMAC-derived layers. `geography` (not
# geometry) so ST_DWithin works in meters without reprojection. All four
# layers are imported, but ONLY kind='suspected' participates in verdicts —
# cleared/lifted/incident are informational (Phase 2 / admin insight) and
# must never soften a verdict.
#
# mine_check_audits records every check (blocked and passed alike); `matches`
# details never surface to end users — internal audit only.
class CreateMineCheckerTables < ActiveRecord::Migration[8.1]
  def change
    enable_extension "postgis" unless extension_enabled?("postgis")

    create_table :mine_areas do |t|
      t.string :kind, null: false # suspected | cleared | lifted | incident
      t.column :geom, "geography(Geometry,4326)", null: false
      t.string :source, null: false
      t.string :file_id # JOG sheet, e.g. "2585-III"
      t.date :data_as_of, null: false
      t.datetime :imported_at, null: false
      t.timestamps
    end
    add_index :mine_areas, :geom, using: :gist
    add_index :mine_areas, :kind

    create_table :mine_check_audits do |t|
      t.string :content_type
      t.bigint :content_id
      t.string :verdict, null: false
      t.jsonb :matches, null: false, default: []
      t.date :data_as_of
      t.datetime :created_at, null: false
    end
    add_index :mine_check_audits, [ :content_type, :content_id ]
    add_index :mine_check_audits, :verdict
  end
end
