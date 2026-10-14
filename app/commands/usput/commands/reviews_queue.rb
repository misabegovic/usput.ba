# frozen_string_literal: true

module Usput
  module Commands
    # The admin's reviews queue: opening on the reviews Jev held.
    class ReviewsQueue < Command
      named "reviews.queue", "Reviews Jev held for a curator, or in another state (curators)"
      param :status, :string, "held, pending, approved or rejected", default: "held",
                              enum: %w[held pending approved rejected]
      param :limit, :integer, "How many, at most 100", default: 20

      def call
        allow!(ReviewPolicy.new(actor).moderate?)

        Review.where(moderation_status: arg(:status)).includes(:user, :reviewable).order(:created_at).limit(limit)
              .map { |review| Serialize.review(review) }
      end
    end
  end
end
