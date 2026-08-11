class CreateMoments < ActiveRecord::Migration[8.1]
  def change
    create_table :moments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.text :note
      t.datetime :taken_at
      t.string :uuid, limit: 36, null: false

      t.timestamps
    end

    add_index :moments, :uuid, unique: true
    add_index :moments, [ :user_id, :plan_id, :location_id ]
  end
end
