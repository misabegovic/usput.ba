class Avo::Filters::PlanOwnership < Avo::Filters::SelectFilter
  self.name = -> { I18n.t("admin.plans.ownership") }

  def apply(_request, query, value)
    case value
    when "curated" then query.where(user_id: nil)
    when "travellers" then query.where.not(user_id: nil)
    else query
    end
  end

  def options
    %w[curated travellers].index_with { |kind| I18n.t("admin.plans.ownerships.#{kind}") }
  end
end
