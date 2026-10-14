class Avo::Actions::RestoreLocation < Avo::BaseAction
  self.name = -> { I18n.t("admin.locations.restore") }
  self.authorize = -> { AdminPolicy.new(current_user).update? }

  def handle(query:, current_user:, **)
    restored = query.select { |location| AdminPolicy.new(current_user, location).update? }
                    .count { |location| Decisions.restore(location, by: current_user) }
    succeed I18n.t("admin.locations.restored", count: restored)
  end
end
