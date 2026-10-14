# frozen_string_literal: true

module Usput
  module Commands
    class MomentsReject < Command
      named "moments.reject", "Reject a public moment: it comes down", effect: :decides
      param :id, :string, "The moment's id (uuid)", required: true

      def call
        moment = find!(MomentPolicy.visible(Moment), arg(:id), "moment")
        allow!(MomentPolicy.new(actor, moment).moderate?)

        changed = Decisions.moderate(moment, :rejected, by: actor)
        Serialize.moment(moment.reload).merge(changed:)
      end
    end
  end
end
