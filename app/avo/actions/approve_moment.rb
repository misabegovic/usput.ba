class Avo::Actions::ApproveMoment < Avo::Actions::Moderate
  self.name = -> { I18n.t("admin.moments.approve") }
  decides :approved, event: MomentApproved, policy: MomentPolicy, label: "moments", activity: :approve_moment
end
