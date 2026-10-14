# frozen_string_literal: true

module Usput
  module Commands
    class ReviewsReject < Moderate
      moderates :review, :rejected, "Reject a review: only its author sees it"
    end
  end
end
