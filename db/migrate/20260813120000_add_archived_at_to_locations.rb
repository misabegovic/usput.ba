class AddArchivedAtToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :archived_at, :datetime

    # Archived places are the minority and the only rows the curator's retired
    # filter asks for; the traveller-facing scopes ask for the complement.
    add_index :locations, :archived_at, where: "archived_at IS NOT NULL"
  end
end
