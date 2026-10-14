class Avo::Actions::RejectMoment < Avo::Actions::ModerateMoment
  self.name = -> { I18n.t("admin.moments.reject") }
  decides :rejected, event: MomentRejected, activity: :reject_moment
end
