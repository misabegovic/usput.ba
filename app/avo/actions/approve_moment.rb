class Avo::Actions::ApproveMoment < Avo::Actions::Moderate
  self.name = -> { I18n.t("admin.moments.approve") }
  decides :approved, policy: MomentPolicy, label: "moments"
end
