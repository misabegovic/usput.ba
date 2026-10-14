class Avo::Actions::RejectMoment < Avo::BaseAction
  self.name = -> { I18n.t("admin.moments.reject") }
  self.authorize = -> { MomentPolicy.new(current_user).moderate? }

  def handle(query:, current_user:, **)
    moments = query.select { |moment| MomentPolicy.new(current_user, moment).moderate? && !moment.rejected? }
    moments.each do |moment|
      moment.update!(moderation_status: :rejected)
      CuratorActivity.record(user: current_user, action: :reject_moment, recordable: moment)
    end
    succeed I18n.t("admin.moments.rejected", count: moments.size)
  end
end
