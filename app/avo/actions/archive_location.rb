class Avo::Actions::ArchiveLocation < Avo::BaseAction
  self.name = -> { I18n.t("admin.locations.archive") }
  self.message = -> { I18n.t("admin.locations.archive_message") }
  self.authorize = -> { AdminPolicy.new(current_user).update? }

  def handle(query:, current_user:, **)
    archived = query.reject(&:archived?).select { |location| AdminPolicy.new(current_user, location).update? }
    archived.each do |location|
      ActiveRecord::Base.transaction do
        location.archive!
        DecisionLog.publish(PlaceArchived, location, by: current_user)
      end
    end
    succeed I18n.t("admin.locations.archived", count: archived.size)
  end
end
