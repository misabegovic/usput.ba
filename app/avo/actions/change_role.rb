class Avo::Actions::ChangeRole < Avo::BaseAction
  self.name = -> { I18n.t("admin.users.change_role") }
  self.authorize = -> { UserPolicy.new(current_user).index? }

  def fields
    field :role, as: :select, options: -> { User.user_types.keys.index_by { |role| I18n.t("admin.users.roles.#{role}") } }
  end

  def handle(query:, fields:, current_user:, **)
    role = fields[:role].to_s
    return error(I18n.t("admin.users.unknown_role")) unless User.user_types.key?(role)

    changed, refused = query.partition { |user| UserPolicy.new(current_user, user).change_role? }
    changed.each { |user| user.update!(user_type: role) }
    succeed I18n.t("admin.users.role_changed", count: changed.size) if changed.any?
    warn I18n.t("admin.users.refused", names: refused.map(&:username).to_sentence) if refused.any?
  end
end
