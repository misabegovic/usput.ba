class Review < ApplicationRecord
  include Identifiable

  belongs_to :reviewable, polymorphic: true, counter_cache: :reviews_count
  belongs_to :user, optional: true

  validates :rating, presence: true,
                     numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :comment, length: { maximum: 1000 }
  validates :author_name, length: { maximum: 100 }

  after_save :update_reviewable_average_rating
  after_destroy :update_reviewable_average_rating

  scope :recent, -> { order(created_at: :desc) }
  scope :by_rating, ->(rating) { where(rating: rating) }
  scope :with_comments, -> { where.not(comment: [nil, ""]) }

  private

  def update_reviewable_average_rating
    return unless reviewable

    avg = reviewable.reviews.average(:rating) || 0
    reviewable.update_column(:average_rating, avg.round(2))
  end
end
