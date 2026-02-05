class CreateReviewFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :review_flags do |t|
      t.references :review, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :reason, null: false  # spam, inappropriate, inaccurate, other
      t.text :notes
      t.timestamps

      t.index [ :review_id, :user_id ], unique: true  # One flag per curator per review
    end
  end
end
