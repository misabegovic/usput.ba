# frozen_string_literal: true

module Usput
  module Commands
    # Approving and rejecting a moment or a review: one decision with two
    # outcomes, as in the admin. Decisions writes it and its event.
    class Moderate < Command
      SUBJECTS = {
        moment: { scope: -> { MomentPolicy.visible(Moment) }, policy: MomentPolicy },
        review: { scope: -> { Review.all }, policy: ReviewPolicy }
      }.freeze

      class << self
        attr_reader :subject, :status

        def moderates(subject, status, summary)
          @subject = subject
          @status = status
          named("#{subject}s.#{status == :approved ? 'approve' : 'reject'}", summary, effect: :decides)
          param :id, :string, "The #{subject}'s id (uuid)", required: true
        end
      end

      def call
        subject = SUBJECTS.fetch(self.class.subject)
        record = find!(subject[:scope].call, arg(:id), self.class.subject)
        allow!(subject[:policy].new(actor, record).moderate?)

        changed = Decisions.moderate(record, self.class.status, by: actor)
        Serialize.public_send(self.class.subject, record.reload).merge(changed:)
      end
    end
  end
end
