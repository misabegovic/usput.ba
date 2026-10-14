# Approving and rejecting are one decision with two outcomes, for moments and
# for reviews alike: the status a record lands in and the event recorded in its
# stream. A review also records whether the curator overturned the band Jev
# gave it.
class Avo::Actions::Moderate < Avo::BaseAction
  class << self
    attr_reader :outcome

    def decides(status, event:, policy:, label:)
      @outcome = { status:, event:, policy:, label: }
      self.authorize = -> { policy.new(current_user).moderate? }
    end
  end

  def handle(query:, current_user:, **)
    status, event, policy, label = self.class.outcome.values_at(:status, :event, :policy, :label)
    records = query.select { |record| policy.new(current_user, record).moderate? && record.moderation_status != status.to_s }
    records.each do |record|
      ActiveRecord::Base.transaction do
        context = decision_context(record, status)
        record.update!(moderation_status: status)
        DecisionLog.publish(event, record, by: current_user, **context)
      end
    end
    succeed I18n.t("admin.#{label}.#{status}", count: records.size)
  end

  private

  def decision_context(record, status)
    return {} unless record.respond_to?(:jev_band)

    { decided_by: "curator", overturned: record.jev_band.present? && record.jev_band != status.to_s }
  end
end
