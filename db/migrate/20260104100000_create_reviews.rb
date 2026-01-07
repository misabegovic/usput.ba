class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :reviewable, polymorphic: true, null: false
      t.integer :rating, null: false
      t.text :comment
      t.string :author_name
      t.string :author_email

      t.timestamps
    end

    add_index :reviews, [:reviewable_type, :reviewable_id, :created_at], name: "index_reviews_on_reviewable_and_created_at"
    add_index :reviews, :rating
  end
end
