class Avo::Resources::AudioTour < Avo::BaseResource
  self.icon = "tabler/outline/headphones"
  self.title = :display_title
  self.includes = [ :location ]
  self.find_record_method = -> { id.is_a?(Array) ? query.where(uuid: id) : query.find_by!(uuid: id) }
  self.search = {
    query: -> { query.joins(:location).where("locations.name ILIKE :q", q: "%#{params[:q]}%") }
  }

  def fields
    field :location, as: :belongs_to, name: I18n.t("admin.audio_tours.place"), searchable: false
    field :locale, as: :select, name: I18n.t("admin.audio_tours.language"),
      options: -> { ::AudioTour::SUPPORTED_LOCALES.to_h { |code, name| [ name, code.to_s ] } }
    field :audio_file, as: :file, name: I18n.t("admin.audio_tours.audio"), accept: "audio/*"
    field :script, as: :textarea, name: I18n.t("admin.audio_tours.script"), rows: 16, hide_on: :index
    field :duration, as: :text, hide_on: :index
    field :voice_id, as: :text, hide_on: :index
    field :tts_provider, as: :text, hide_on: :index
    field :word_count, as: :number, readonly: true, hide_on: :forms
  end
end
