class Avo::Actions::ApproveMoment < Avo::Actions::ModerateMoment
  self.name = -> { I18n.t("admin.moments.approve") }
  decides :approved, event: MomentApproved, activity: :approve_moment
end
