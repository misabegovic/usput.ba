class Avo::Actions::RejectMoment < Avo::Actions::Moderate
  self.name = -> { I18n.t("admin.moments.reject") }
  decides :rejected, policy: MomentPolicy, label: "moments"
end
