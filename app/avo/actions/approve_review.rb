class Avo::Actions::ApproveReview < Avo::Actions::Moderate
  self.name = -> { I18n.t("admin.reviews.approve") }
  decides :approved, event: ReviewApproved, policy: ReviewPolicy, label: "reviews"
end
