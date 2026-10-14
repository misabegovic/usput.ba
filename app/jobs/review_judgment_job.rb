# Asks Jev about one review, after the request that submitted it has returned.
# ReviewModeration never raises, so there is nothing to retry: a failed call
# is a named skip that holds the review for a curator.
class ReviewJudgmentJob < ApplicationJob
  queue_as :default

  def perform(review_id)
    review = Review.find_by(id: review_id)
    return unless review

    ReviewModeration.apply(review, ReviewModeration.screen(review))
  end
end
