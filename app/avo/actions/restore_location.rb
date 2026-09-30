class Avo::Actions::RestoreLocation < Avo::BaseAction
  self.name = -> { I18n.t("admin.locations.restore") }
  self.authorize = -> { AdminPolicy.new(current_user).update? }

  def handle(query:, current_user:, **)
    restored = query.select(&:archived?).select { |location| AdminPolicy.new(current_user, location).update? }
    restored.each(&:restore!)
    succeed I18n.t("admin.locations.restored", count: restored.size)
  end
end
