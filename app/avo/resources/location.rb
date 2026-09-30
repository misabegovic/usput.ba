class Avo::Resources::Location < Avo::BaseResource
  include Avo::TranslatedFields

  self.icon = "tabler/outline/map-pin"
  self.title = :name
  self.includes = [ :translations ]
  self.attachments = [ :photos ]
  # URLs carry the public uuid (Identifiable#to_param), never the database id.
  self.find_record_method = -> { id.is_a?(Array) ? query.where(uuid: id) : query.find_by!(uuid: id) }
  self.search = {
    query: -> { query.where("locations.name ILIKE :q OR locations.city ILIKE :q", q: "%#{params[:q]}%") }
  }

  def fields
    main_panel
    field :photos, as: :files, is_image: true, hide_on: :index, name: I18n.t("admin.locations.photos")
    translation_tabs :name, :description, :historical_context, long: %i[description historical_context]
  end

  def filters
    filter Avo::Filters::LocationCity
    filter Avo::Filters::LocationArchived
    filter Avo::Filters::LocationPhotos
  end

  def actions
    action Avo::Actions::ArchiveLocation
    action Avo::Actions::RestoreLocation
  end

  private

  def main_panel
    field :name, as: :text, required: true, sortable: true, link_to_record: true
    field :city, as: :text, sortable: true
    field :lat, as: :number, step: 0.000001, hide_on: :index, help: I18n.t("admin.locations.coordinates_help")
    field :lng, as: :number, step: 0.000001, hide_on: :index
    field :budget, as: :select, enum: ::Location.budgets, hide_on: :index
    field :short_description, as: :textarea, hide_on: :index
    field :phone, as: :text, hide_on: :index
    field :email, as: :text, hide_on: :index
    field :website, as: :text, hide_on: :index
    field :video_url, as: :text, hide_on: :index
    field :photo_count, as: :number, name: I18n.t("admin.locations.photo_count"), only_on: :index,
      format_using: -> { record.photos.size }
    field :archived_at, as: :date_time, readonly: true, hide_on: :forms
    field :ai_generated, as: :boolean, readonly: true, hide_on: :forms
    field :average_rating, as: :number, readonly: true, hide_on: :forms
  end
end
