# frozen_string_literal: true

module Usput
  module Commands
    # The admin's moments queue: public moments, opening on those waiting.
    class MomentsQueue < Command
      named "moments.queue", "Public moments waiting for a curator, or in another state (curators)"
      param :status, :string, "pending, approved or rejected", default: "pending", enum: %w[pending approved rejected]
      param :limit, :integer, "How many, at most 100", default: 20

      def call
        allow!(MomentPolicy.new(actor).moderate?)

        MomentPolicy.visible(Moment).where(moderation_status: arg(:status))
                    .includes(:user, location: :locale_translations).order(:created_at).limit(limit)
                    .map { |moment| Serialize.moment(moment) }
      end
    end
  end
end
