# Approving and rejecting are one decision with two outcomes, for moments and
# for reviews alike: the status a record lands in, the event recorded in its
# stream, and for moments the curator activity logged. A review also records
# whether the curator overturned the band Jev gave it.
class Avo::Actions::Moderate < Avo::BaseAction
  class << self
    attr_reader :outcome

    def decides(status, event:, policy:, label:, activity: nil)
      @outcome = { status:, event:, policy:, label:, activity: }
      self.authorize = -> { policy.new(current_user).moderate? }
    end
  end

  def handle(query:, current_user:, **)
    status, event, policy, label, activity = self.class.outcome.values_at(:status, :event, :policy, :label, :activity)
    records = query.select { |record| policy.new(current_user, record).moderate? && record.moderation_status != status.to_s }
    records.each do |record|
      ActiveRecord::Base.transaction do
        context = decision_context(record, status)
        record.update!(moderation_status: status)
        DecisionLog.publish(event, record, by: current_user, **context)
      end
      CuratorActivity.record(user: current_user, action: activity, recordable: record) if activity
    end
    succeed I18n.t("admin.#{label}.#{status}", count: records.size)
  end

  private

  def decision_context(record, status)
    return {} unless record.respond_to?(:jev_band)

    { decided_by: "curator", overturned: record.jev_band.present? && record.jev_band != status.to_s }
  end
end
