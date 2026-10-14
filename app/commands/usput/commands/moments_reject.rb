# frozen_string_literal: true

module Usput
  module Commands
    class MomentsReject < Moderate
      moderates :moment, :rejected, "Reject a public moment: it comes down"
    end
  end
end
