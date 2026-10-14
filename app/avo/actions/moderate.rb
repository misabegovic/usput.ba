# Approving and rejecting are one decision with two outcomes, for moments and
# for reviews alike. What the decision writes lives in Decisions, which the
# usput commands share; this action only picks the records and reports.
class Avo::Actions::Moderate < Avo::BaseAction
  class << self
    attr_reader :outcome

    def decides(status, policy:, label:)
      @outcome = { status:, policy:, label: }
      self.authorize = -> { policy.new(current_user).moderate? }
    end
  end

  def handle(query:, current_user:, **)
    status, policy, label = self.class.outcome.values_at(:status, :policy, :label)
    decided = query.select { |record| policy.new(current_user, record).moderate? }
                   .count { |record| Decisions.moderate(record, status, by: current_user) }
    succeed I18n.t("admin.#{label}.#{status}", count: decided)
  end
end
