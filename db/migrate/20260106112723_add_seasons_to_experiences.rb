class AddSeasonsToExperiences < ActiveRecord::Migration[8.1]
  def change
    add_column :experiences, :seasons, :jsonb, default: []

    add_index :experiences, :seasons, using: :gin
  end
end
