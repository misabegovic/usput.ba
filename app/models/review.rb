class Review < ApplicationRecord
  include Identifiable

  # Jev sorts a submitted review into three bands (wiki/decisions/jev-decides-reviews.md):
  # approved is public, held waits for a curator, rejected is hidden. A review
  # waits as pending only while Jev has not answered. The author always sees
  # their own, whatever its state.
  enum :moderation_status, {
    pending: "pending", approved: "approved", held: "held", rejected: "rejected"
  }, validate: true

  belongs_to :reviewable, polymorphic: true
  belongs_to :user, optional: true

  validates :rating, presence: true,
                     numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :comment, length: { maximum: 1000 }
  validates :author_name, length: { maximum: 100 }

  after_save :update_reviewable_rating
  after_destroy :update_reviewable_rating

  scope :recent, -> { order(created_at: :desc) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  scope :with_comments, -> { where.not(comment: [ nil, "" ]) }

  # What a reader may see: every approved review, and their own in any state.
  scope :visible_to, ->(user) {
    user ? where(moderation_status: :approved).or(where(user_id: user.id)) : approved
  }

  def author_label
    user&.username || author_name.presence
  end

  private

  # Ratings and counts come from approved reviews only, so a review waiting
  # for a curator, or one Jev turned away, never moves a place's score.
  def update_reviewable_rating
    return unless reviewable

    approved = reviewable.reviews.approved
    reviewable.update_columns(average_rating: (approved.average(:rating) || 0).round(2),
                              reviews_count: approved.count)
  end
end
