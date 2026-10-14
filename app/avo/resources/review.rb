class Avo::Resources::Review < Avo::BaseResource
  self.icon = "tabler/outline/message-star"
  self.title = :comment
  self.includes = [ :user, :reviewable ]
  self.index_query = -> { query.order(created_at: :desc) }
  self.find_record_method = -> {
    id.is_a?(Array) ? query.where(uuid: id) : query.find_by!(uuid: id)
  }

  def fields
    field :moderation_status, as: :badge, name: I18n.t("admin.reviews.status"),
      options: { warning: %w[held pending], success: "approved", danger: "rejected" }
    field :rating, as: :number, name: I18n.t("admin.reviews.rating")
    field :comment, as: :textarea, name: I18n.t("admin.reviews.comment")
    # Avo leaves a textarea off the index; the queue is read there.
    field :excerpt, as: :text, name: I18n.t("admin.reviews.comment"), only_on: :index do
      record.comment.to_s.truncate(140)
    end
    field :author, as: :text, name: I18n.t("admin.reviews.author") do
      record.author_label
    end
    field :reviewable, as: :belongs_to, polymorphic_as: :reviewable, types: [ ::Location, ::Experience, ::Plan ],
      name: I18n.t("admin.reviews.about")
    field :jev_band, as: :text, name: I18n.t("admin.reviews.jev_band")
    field :jev_reading, as: :text, name: I18n.t("admin.reviews.jev_reading"), only_on: :show do
      record.jev_skip.presence || record.jev_answers&.map { |question, probability| "#{question} #{probability.round(2)}" }&.join(", ")
    end
    field :jev_model, as: :text, name: I18n.t("admin.reviews.jev_model"), only_on: :show
    field :created_at, as: :date_time, name: I18n.t("admin.reviews.written_at"), sortable: true
  end

  def filters
    filter Avo::Filters::ReviewStatus
  end

  def actions
    action Avo::Actions::ApproveReview
    action Avo::Actions::RejectReview
  end
end
