class CreateLocales < ActiveRecord::Migration[8.1]
  def change
    create_table :locales do |t|
      t.string :code, limit: 10, null: false
      t.string :name, null: false
      t.string :native_name
      t.string :flag_emoji
      t.integer :position, default: 0
      t.boolean :active, default: true
      t.boolean :ai_supported, default: true

      t.timestamps
    end

    add_index :locales, :code, unique: true
    add_index :locales, :active
    add_index :locales, :position
  end
end
