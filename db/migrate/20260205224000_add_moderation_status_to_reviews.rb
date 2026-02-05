class AddModerationStatusToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :moderation_status, :integer, default: 0, null: false
    add_index :reviews, :moderation_status
  end
end
