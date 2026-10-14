# frozen_string_literal: true

module Usput
  module Commands
    # Asks Jev about one review and shows the band, without recording or
    # deciding anything: for measuring the thresholds before enforce mode.
    class ReviewsJudge < Command
      named "reviews.judge", "Ask Jev about a review and show its band, recording nothing (curators)"
      param :id, :string, "The review's id (uuid)", required: true

      def call
        review = find!(Review, arg(:id), "review")
        allow!(ReviewPolicy.new(actor, review).moderate?)

        result = ReviewModeration.screen(review)
        { id: review.uuid, band: result.band.to_s, answers: result.answers, model: result.model, skip: result.skip,
          thresholds: ReviewModeration.config.slice(:approve_below, :reject_above), recorded: false }
      end
    end
  end
end
