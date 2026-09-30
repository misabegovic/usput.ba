# The queue opens on the moments waiting for a decision.
class Avo::Filters::MomentStatus < Avo::Filters::SelectFilter
  self.name = -> { I18n.t("admin.moments.status") }

  def apply(_request, query, value)
    value == "all" ? query : query.where(moderation_status: value)
  end

  def default
    "pending"
  end

  def options
    %w[pending approved rejected all].index_with { |status| I18n.t("admin.moments.statuses.#{status}") }
  end
end
