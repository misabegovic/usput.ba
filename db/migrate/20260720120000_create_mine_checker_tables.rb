# Mine Checker audit log (docs/mine_checker/SPEC.md §6). Plain PostgreSQL —
# all spatial work happens in the static engine (precomputed artifacts);
# this table records every check for internal accountability. Match details
# never surface to end users.
class CreateMineCheckerTables < ActiveRecord::Migration[8.1]
  def change
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
