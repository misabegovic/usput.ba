# frozen_string_literal: true

# Curator reviews/comments on content change proposals.
# Curators can recommend approval or rejection, but only admins can make final decision.
class CuratorReview < ApplicationRecord
  belongs_to :content_change
  belongs_to :user

  enum :recommendation, { neutral: 0, recommend_approve: 1, recommend_reject: 2 }

  validates :comment, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :content_change, presence: true
  validates :user, presence: true

  # Sanitize comment to prevent XSS
  before_save :sanitize_comment

  scope :recent, -> { order(created_at: :desc) }

  private

  def sanitize_comment
    return if comment.blank?
    self.comment = ActionController::Base.helpers.sanitize(comment, tags: %w[b i em strong br], attributes: [])
  end
end
