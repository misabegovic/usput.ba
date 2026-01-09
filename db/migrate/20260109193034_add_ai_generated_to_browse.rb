class AddAiGeneratedToBrowse < ActiveRecord::Migration[8.1]
  def change
    add_column :browses, :ai_generated, :boolean, default: true, null: false
    add_index :browses, :ai_generated
  end
end
