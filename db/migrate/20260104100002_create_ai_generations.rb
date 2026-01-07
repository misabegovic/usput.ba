class CreateAiGenerations < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_generations do |t|
      t.references :city, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.string :generation_type, null: false
      t.integer :locations_created, default: 0
      t.integer :experiences_created, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :ai_generations, :status
    add_index :ai_generations, :generation_type
    add_index :ai_generations, [ :city_id, :generation_type ], unique: true, where: "status IN (0, 1)"
  end
end
