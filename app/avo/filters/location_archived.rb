class Avo::Filters::LocationArchived < Avo::Filters::SelectFilter
  self.name = -> { I18n.t("admin.locations.status") }

  def apply(_request, query, value)
    case value
    when "archived" then query.archived
    when "all" then query
    else query.not_archived
    end
  end

  def default
    "active"
  end

  def options
    %w[active archived all].index_with { |status| I18n.t("admin.locations.statuses.#{status}") }
  end
end
