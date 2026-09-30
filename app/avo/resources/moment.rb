class Avo::Resources::Moment < Avo::BaseResource
  self.icon = "tabler/outline/camera"
  self.title = :note
  self.includes = [ :user, :location ]
  # Public moments only; a private one is not found even by its link.
  self.index_query = -> { MomentPolicy.visible(query).order(created_at: :desc) }
  self.find_record_method = -> {
    scope = MomentPolicy.visible(query)
    id.is_a?(Array) ? scope.where(uuid: id) : scope.find_by!(uuid: id)
  }

  def fields
    field :photo_preview, as: :external_image, name: I18n.t("admin.moments.photo"), width: 96, height: 96, radius: 8,
      link_to_record: true, only_on: :index do
      main_app.admin_moment_photo_path(record, size: "thumb")
    end
    field :photo_full, as: :external_image, name: I18n.t("admin.moments.photo"), only_on: :show do
      main_app.admin_moment_photo_path(record, size: "story")
    end
    field :moderation_status, as: :badge, name: I18n.t("admin.moments.status"),
      options: { warning: "pending", success: "approved", danger: "rejected" }
    field :note, as: :text, name: I18n.t("admin.moments.note")
    field :author, as: :text, name: I18n.t("admin.moments.author") do
      record.user&.username
    end
    field :location, as: :belongs_to, name: I18n.t("admin.moments.place")
    field :created_at, as: :date_time, name: I18n.t("admin.moments.shared_at"), sortable: true
  end

  def filters
    filter Avo::Filters::MomentStatus
  end

  def actions
    action Avo::Actions::ApproveMoment
    action Avo::Actions::RejectMoment
  end
end
