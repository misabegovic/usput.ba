class Avo::Filters::LocationCity < Avo::Filters::SelectFilter
  self.name = -> { I18n.t("admin.locations.city") }

  def apply(_request, query, value)
    value.present? ? query.where(city: value) : query
  end

  def options
    Location.where.not(city: [ nil, "" ]).distinct.order(:city).pluck(:city).index_with(&:itself)
  end
end
