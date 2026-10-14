# Approving and rejecting a moment are one decision with two outcomes: the
# status it lands in, the event recorded and the curator activity logged.
class Avo::Actions::ModerateMoment < Avo::BaseAction
  self.authorize = -> { MomentPolicy.new(current_user).moderate? }

  class << self
    attr_reader :outcome

    def decides(status, event:, activity:)
      @outcome = { status:, event:, activity: }
    end
  end

  def handle(query:, current_user:, **)
    status, event, activity = self.class.outcome.values_at(:status, :event, :activity)
    moments = query.select { |moment| MomentPolicy.new(current_user, moment).moderate? && moment.moderation_status != status.to_s }
    moments.each do |moment|
      ActiveRecord::Base.transaction do
        moment.update!(moderation_status: status)
        DecisionLog.publish(event, moment, by: current_user)
      end
      CuratorActivity.record(user: current_user, action: activity, recordable: moment)
    end
    succeed I18n.t("admin.moments.#{status}", count: moments.size)
  end
end
