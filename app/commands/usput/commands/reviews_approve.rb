# frozen_string_literal: true

module Usput
  module Commands
    class ReviewsApprove < Moderate
      moderates :review, :approved, "Approve a review: it is public and counts in the rating"
    end
  end
end
