class ReviewFlag < ApplicationRecord
  belongs_to :review
  belongs_to :user

  REASONS = %w[spam inappropriate inaccurate other].freeze

  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :user_id, uniqueness: { scope: :review_id, message: "has already flagged this review" }

  after_create :update_review_moderation_status

  private

  def update_review_moderation_status
    review.update!(moderation_status: :flagged) if review.unreviewed?
  end
end
