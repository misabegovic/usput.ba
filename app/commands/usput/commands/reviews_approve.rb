# frozen_string_literal: true

module Usput
  module Commands
    class ReviewsApprove < Command
      named "reviews.approve", "Approve a review: it is public and counts in the rating", effect: :decides
      param :id, :string, "The review's id (uuid)", required: true

      def call
        review = find!(Review, arg(:id), "review")
        allow!(ReviewPolicy.new(actor, review).moderate?)

        changed = Decisions.moderate(review, :approved, by: actor)
        Serialize.review(review.reload).merge(changed:)
      end
    end
  end
end
