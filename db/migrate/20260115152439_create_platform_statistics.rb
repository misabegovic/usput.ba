class CreatePlatformStatistics < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_statistics do |t|
      t.string :key, null: false
      t.jsonb :value, default: {}, null: false
      t.datetime :computed_at
      t.timestamps

      t.index :key, unique: true
    end
  end
end
