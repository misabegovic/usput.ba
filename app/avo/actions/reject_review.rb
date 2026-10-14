class Avo::Actions::RejectReview < Avo::Actions::Moderate
  self.name = -> { I18n.t("admin.reviews.reject") }
  decides :rejected, policy: ReviewPolicy, label: "reviews"
end
