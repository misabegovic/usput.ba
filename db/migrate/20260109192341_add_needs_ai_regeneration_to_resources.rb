class AddNeedsAiRegenerationToResources < ActiveRecord::Migration[8.1]
  def change
    # Add dirty flag for AI regeneration to locations, experiences, and plans
    add_column :locations, :needs_ai_regeneration, :boolean, default: false, null: false
    add_column :experiences, :needs_ai_regeneration, :boolean, default: false, null: false
    add_column :plans, :needs_ai_regeneration, :boolean, default: false, null: false

    # Add indexes for efficient querying of dirty resources
    add_index :locations, :needs_ai_regeneration, where: "needs_ai_regeneration = true"
    add_index :experiences, :needs_ai_regeneration, where: "needs_ai_regeneration = true"
    add_index :plans, :needs_ai_regeneration, where: "needs_ai_regeneration = true"
  end
end
