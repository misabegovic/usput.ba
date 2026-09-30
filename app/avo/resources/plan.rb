class Avo::Resources::Plan < Avo::BaseResource
  include Avo::TranslatedFields

  self.icon = "tabler/outline/map"
  self.title = :title
  self.includes = [ :translations, :user ]
  # Curated plans and travellers' public plans only; a private plan is not
  # found even by its link (PlanPolicy.visible).
  self.index_query = -> { PlanPolicy.visible(query) }
  self.find_record_method = -> {
    scope = PlanPolicy.visible(query)
    id.is_a?(Array) ? scope.where(uuid: id) : scope.find_by!(uuid: id)
  }
  self.search = {
    query: -> { PlanPolicy.visible(query).where("plans.title ILIKE :q OR plans.city_name ILIKE :q", q: "%#{params[:q]}%") }
  }

  def fields
    field :title, as: :text, required: true, sortable: true, link_to_record: true
    field :city_name, as: :text, name: I18n.t("admin.plans.city"), sortable: true
    field :visibility, as: :select, enum: ::Plan.visibilities, hide_on: :index
    field :owner, as: :text, name: I18n.t("admin.plans.owner"), readonly: true, hide_on: :forms,
      format_using: -> { record.user&.username || I18n.t("admin.plans.curated") }
    field :ai_generated, as: :boolean, readonly: true, hide_on: :forms
    translation_tabs :title, :notes, long: %i[notes]
    field :experiences, as: :has_many, through: :plan_experiences, name: I18n.t("admin.plans.experiences"),
      attach_fields: -> {
        field :day_number, as: :number, default: 1, name: I18n.t("admin.plans.day")
        field :position, as: :number, default: 0
      }
    field :location_items, as: :has_many, through: :plan_locations, name: I18n.t("admin.plans.places"),
      use_resource: Avo::Resources::Location,
      attach_fields: -> {
        field :day_number, as: :number, default: 1, name: I18n.t("admin.plans.day")
        field :position, as: :number, default: 0
      }
  end

  def filters
    filter Avo::Filters::PlanOwnership
  end
end
