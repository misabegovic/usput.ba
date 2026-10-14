class Avo::Actions::ApproveMoment < Avo::BaseAction
  self.name = -> { I18n.t("admin.moments.approve") }
  self.authorize = -> { MomentPolicy.new(current_user).moderate? }

  def handle(query:, current_user:, **)
    moments = query.select { |moment| MomentPolicy.new(current_user, moment).moderate? && !moment.approved? }
    moments.each do |moment|
      moment.update!(moderation_status: :approved)
      CuratorActivity.record(user: current_user, action: :approve_moment, recordable: moment)
    end
    succeed I18n.t("admin.moments.approved", count: moments.size)
  end
end
