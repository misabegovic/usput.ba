# frozen_string_literal: true

module Usput
  module Commands
    class MomentsApprove < Command
      named "moments.approve", "Approve a public moment: the public sees it", effect: :decides
      param :id, :string, "The moment's id (uuid)", required: true

      def call
        moment = find!(MomentPolicy.visible(Moment), arg(:id), "moment")
        allow!(MomentPolicy.new(actor, moment).moderate?)

        changed = Decisions.moderate(moment, :approved, by: actor)
        Serialize.moment(moment.reload).merge(changed:)
      end
    end
  end
end
