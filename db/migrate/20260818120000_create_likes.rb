class CreateLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :likeable, null: false, polymorphic: true
      t.timestamps
    end

    # Enforced here, not in the model: two simultaneous taps race a validation.
    add_index :likes, [ :user_id, :likeable_type, :likeable_id ], unique: true,
              name: "index_likes_on_user_and_likeable"

    add_column :moments, :likes_count, :integer, null: false, default: 0
  end
end
