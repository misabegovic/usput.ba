class Avo::Actions::UnblockUser < Avo::BaseAction
  self.name = -> { I18n.t("admin.users.unblock") }
  self.authorize = -> { UserPolicy.new(current_user).index? }

  def handle(query:, current_user:, **)
    unblocked, refused = query.partition { |user| UserPolicy.new(current_user, user).unblock? }
    unblocked.each(&:unblock!)
    succeed I18n.t("admin.users.unblocked", count: unblocked.size) if unblocked.any?
    warn I18n.t("admin.users.refused", names: refused.map(&:username).to_sentence) if refused.any?
  end
end
