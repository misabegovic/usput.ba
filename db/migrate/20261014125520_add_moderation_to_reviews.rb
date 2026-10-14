# Jev reads each new review and sorts it into three bands; a review the
# public can see is "approved". Existing reviews were all public, so they
# start approved, and so does any review not submitted through the form.
class AddModerationToReviews < ActiveRecord::Migration[8.1]
  def change
    change_table :reviews, bulk: true do |t|
      t.string :moderation_status, null: false, default: "approved"
      t.jsonb :jev_answers
      t.string :jev_model
      t.string :jev_band
      t.string :jev_skip
      t.datetime :judged_at
    end
    add_index :reviews, %i[reviewable_type reviewable_id moderation_status], name: "index_reviews_on_reviewable_and_status"
  end
end
