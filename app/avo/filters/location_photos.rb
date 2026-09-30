# Places that still need photos, the old curator area's "needs photos" list.
class Avo::Filters::LocationPhotos < Avo::Filters::SelectFilter
  self.name = -> { I18n.t("admin.locations.photos") }

  def apply(_request, query, value)
    return query if value.blank?

    counts = ActiveStorage::Attachment.where(record_type: "Location", name: "photos")
                                      .group(:record_id).select(:record_id)
    case value
    when "none" then query.where.not(id: counts)
    when "few" then query.where.not(id: counts.having("COUNT(*) >= 3"))
    else query
    end
  end

  def options
    %w[none few].index_with { |bucket| I18n.t("admin.locations.photo_buckets.#{bucket}") }
  end
end
