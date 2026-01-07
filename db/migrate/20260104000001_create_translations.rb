# frozen_string_literal: true

class CreateTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :translations do |t|
      t.references :translatable, polymorphic: true, null: false
      t.string :locale, null: false, limit: 10
      t.string :field_name, null: false, limit: 50
      t.text :value

      t.timestamps
    end

    add_index :translations, [ :translatable_type, :translatable_id, :locale, :field_name ],
              unique: true,
              name: "index_translations_uniqueness"
    add_index :translations, :locale
    add_index :translations, :field_name
  end
end
