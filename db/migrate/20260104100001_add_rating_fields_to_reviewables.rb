class AddRatingFieldsToReviewables < ActiveRecord::Migration[8.1]
  def change
    # Add rating fields to locations
    add_column :locations, :average_rating, :decimal, precision: 3, scale: 2, default: 0.0
    add_column :locations, :reviews_count, :integer, default: 0
    add_index :locations, :average_rating
    add_index :locations, :reviews_count

    # Add rating fields to experiences
    add_column :experiences, :average_rating, :decimal, precision: 3, scale: 2, default: 0.0
    add_column :experiences, :reviews_count, :integer, default: 0
    add_index :experiences, :average_rating
    add_index :experiences, :reviews_count

    # Add rating and slug fields to plans
    add_column :plans, :average_rating, :decimal, precision: 3, scale: 2, default: 0.0
    add_column :plans, :reviews_count, :integer, default: 0
    add_index :plans, :average_rating
    add_index :plans, :reviews_count
  end
end
