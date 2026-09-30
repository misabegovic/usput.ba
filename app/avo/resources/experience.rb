class Avo::Resources::Experience < Avo::BaseResource
  include Avo::TranslatedFields

  self.icon = "tabler/outline/route"
  self.title = :title
  self.includes = [ :translations ]
  self.find_record_method = -> { id.is_a?(Array) ? query.where(uuid: id) : query.find_by!(uuid: id) }
  self.search = {
    query: -> { query.where("experiences.title ILIKE :q", q: "%#{params[:q]}%") }
  }

  def fields
    field :title, as: :text, required: true, sortable: true, link_to_record: true
    field :experience_category_id, as: :select, name: I18n.t("admin.experiences.category"), include_blank: true,
      options: -> { ExperienceCategory.order(:name).map { |category| [ category.name, category.id ] }.to_h }
    field :estimated_duration, as: :number, name: I18n.t("admin.experiences.duration"), hide_on: :index
    field :cover_photo, as: :file, is_image: true, hide_on: :index
    field :contact_name, as: :text, hide_on: :index
    field :contact_phone, as: :text, hide_on: :index
    field :contact_email, as: :text, hide_on: :index
    field :contact_website, as: :text, hide_on: :index
    field :ai_generated, as: :boolean, readonly: true, hide_on: :forms
    field :average_rating, as: :number, readonly: true, hide_on: :forms
    translation_tabs :title, :description, long: %i[description]
    field :locations, as: :has_many, through: :experience_locations, name: I18n.t("admin.experiences.places"),
      attach_fields: -> { field :position, as: :number, default: 0 }
  end
end
