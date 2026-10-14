# The queue opens on the reviews Jev held for a curator.
class Avo::Filters::ReviewStatus < Avo::Filters::SelectFilter
  self.name = -> { I18n.t("admin.reviews.status") }

  def apply(_request, query, value)
    value == "all" ? query : query.where(moderation_status: value)
  end

  def default
    "held"
  end

  def options
    %w[held pending approved rejected all].index_with { |status| I18n.t("admin.reviews.statuses.#{status}") }
  end
end
