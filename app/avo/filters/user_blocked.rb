class Avo::Filters::UserBlocked < Avo::Filters::BooleanFilter
  self.name = -> { I18n.t("admin.users.blocked_filter") }

  def apply(_request, query, values)
    values["blocked"] ? query.where.not(blocked_at: nil) : query
  end

  def options
    { blocked: I18n.t("admin.users.blocked_only") }
  end
end
