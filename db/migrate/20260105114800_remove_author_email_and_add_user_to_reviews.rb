class RemoveAuthorEmailAndAddUserToReviews < ActiveRecord::Migration[8.1]
  def change
    remove_column :reviews, :author_email, :string
    add_reference :reviews, :user, null: true, foreign_key: true
  end
end
