class Avo::Filters::UserRole < Avo::Filters::SelectFilter
  self.name = -> { I18n.t("admin.users.role") }

  def apply(_request, query, value)
    value.present? ? query.where(user_type: value) : query
  end

  def options
    User.user_types.keys.index_with { |role| I18n.t("admin.users.roles.#{role}") }
  end
end
