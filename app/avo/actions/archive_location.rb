class Avo::Actions::ArchiveLocation < Avo::BaseAction
  self.name = -> { I18n.t("admin.locations.archive") }
  self.message = -> { I18n.t("admin.locations.archive_message") }
  self.authorize = -> { AdminPolicy.new(current_user).update? }

  def handle(query:, current_user:, **)
    archived = query.select { |location| AdminPolicy.new(current_user, location).update? }
                    .count { |location| Decisions.archive(location, by: current_user) }
    succeed I18n.t("admin.locations.archived", count: archived)
  end
end
