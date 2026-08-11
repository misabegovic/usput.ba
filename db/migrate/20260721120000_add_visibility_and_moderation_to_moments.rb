class AddVisibilityAndModerationToMoments < ActiveRecord::Migration[8.1]
  def change
    # Visibility: 0 = private (default), 1 = public
    add_column :moments, :visibility, :integer, default: 0, null: false

    # Moderation for public moments: 0 = pending, 1 = approved, 2 = rejected
    add_column :moments, :moderation_status, :integer, default: 0, null: false

    # Community feed / Browse sync read approved public moments, newest first
    add_index :moments, [ :visibility, :moderation_status, :created_at ]
  end
end
