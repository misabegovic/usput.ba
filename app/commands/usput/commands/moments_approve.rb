# frozen_string_literal: true

module Usput
  module Commands
    class MomentsApprove < Moderate
      moderates :moment, :approved, "Approve a public moment: the public sees it"
    end
  end
end
