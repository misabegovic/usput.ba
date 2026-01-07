class AddUserAndVisibilityToPlans < ActiveRecord::Migration[8.1]
  def change
    # Add user reference (nullable - public plans don't have users)
    add_reference :plans, :user, null: true, foreign_key: true

    # Visibility: 0 = private (default for user plans), 1 = public
    add_column :plans, :visibility, :integer, default: 0, null: false

    # Preferences stored as JSON (budget, interests, meat_lover, etc.)
    add_column :plans, :preferences, :jsonb, default: {}

    # Local ID from localStorage (UUID) for syncing
    add_column :plans, :local_id, :string

    # Make start_date and end_date nullable for user-generated plans
    change_column_null :plans, :start_date, true
    change_column_null :plans, :end_date, true

    # Add index for user's plans
    add_index :plans, [:user_id, :visibility], where: "user_id IS NOT NULL"
    add_index :plans, :local_id, unique: true, where: "local_id IS NOT NULL"
    add_index :plans, :visibility
  end
end
