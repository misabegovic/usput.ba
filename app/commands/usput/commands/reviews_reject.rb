# frozen_string_literal: true

module Usput
  module Commands
    class ReviewsReject < Command
      named "reviews.reject", "Reject a review: only its author sees it", effect: :decides
      param :id, :string, "The review's id (uuid)", required: true

      def call
        review = find!(Review, arg(:id), "review")
        allow!(ReviewPolicy.new(actor, review).moderate?)

        changed = Decisions.moderate(review, :rejected, by: actor)
        Serialize.review(review.reload).merge(changed:)
      end
    end
  end
end
