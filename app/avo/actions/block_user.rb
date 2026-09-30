class Avo::Actions::BlockUser < Avo::BaseAction
  self.name = -> { I18n.t("admin.users.block") }
  self.message = -> { I18n.t("admin.users.block_message") }
  self.authorize = -> { UserPolicy.new(current_user).index? }

  def handle(query:, current_user:, **)
    blocked, refused = query.partition { |user| UserPolicy.new(current_user, user).block? }
    blocked.each(&:block!)
    succeed I18n.t("admin.users.blocked", count: blocked.size) if blocked.any?
    warn I18n.t("admin.users.refused", names: refused.map(&:username).to_sentence) if refused.any?
  end
end
