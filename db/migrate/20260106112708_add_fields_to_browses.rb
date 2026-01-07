class AddFieldsToBrowses < ActiveRecord::Migration[8.1]
  def change
    add_column :browses, :budget, :integer
    add_column :browses, :category_keys, :jsonb, default: []
    add_column :browses, :seasons, :jsonb, default: []

    add_index :browses, :budget
    add_index :browses, :category_keys, using: :gin
    add_index :browses, :seasons, using: :gin
  end
end
