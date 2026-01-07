module Curator
  class LocationsController < BaseController
    before_action :set_location, only: [ :show, :edit, :update, :destroy ]
    before_action :load_form_options, only: [ :new, :create, :edit, :update ]

    def index
      @locations = Location.order(created_at: :desc)
      @locations = @locations.by_city(params[:city_name]) if params[:city_name].present?
      @locations = @locations.by_category(params[:category]) if params[:category].present?
      @locations = @locations.where("locations.name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
      @city_names = Location.where.not(city: [nil, ""]).distinct.pluck(:city).sort
      @location_categories = LocationCategory.active.ordered
    end

    def show
    end

    def new
      @location = Location.new
    end

    def create
      @location = Location.new(location_params)

      if @location.save
        attach_photos
        attach_audio_file
        redirect_to curator_location_path(@location), notice: t("curator.locations.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      remove_photos if params[:location][:remove_photo_ids].present?
      remove_audio_file if params[:location][:remove_audio_file] == "1"

      if @location.update(location_params)
        attach_photos
        attach_audio_file
        redirect_to curator_location_path(@location), notice: t("curator.locations.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @location.destroy
      redirect_to curator_locations_path, notice: t("curator.locations.deleted")
    end

    private

    def set_location
      @location = Location.find_by_public_id!(params[:id])
    end

    def location_params
      permitted = params.require(:location).permit(
        :name, :description, :historical_context, :city,
        :lat, :lng, :location_type, :budget,
        :phone, :email, :website, :video_url,
        :tags_input,
        suitable_experiences: [],
        social_links: Location.supported_social_platforms,
        location_category_ids: []
      )

      # Process tags from comma-separated input
      if permitted[:tags_input].present?
        permitted[:tags] = permitted[:tags_input].split(",").map(&:strip).map(&:downcase).reject(&:blank?).uniq
      end
      permitted.delete(:tags_input)

      # Clean empty social links
      if permitted[:social_links].present?
        permitted[:social_links] = permitted[:social_links].reject { |_, v| v.blank? }
      end

      permitted
    end

    def load_form_options
      @city_names = Location.where.not(city: [nil, ""]).distinct.pluck(:city).sort
      @experience_types = ExperienceType.where(active: true).order(:position)
      @location_categories = LocationCategory.active.ordered
    end

    def attach_photos
      return unless params[:location][:photos].present?
      photos = params[:location][:photos].reject(&:blank?)
      @location.photos.attach(photos) if photos.any?
    end

    def remove_photos
      signed_ids = params[:location][:remove_photo_ids].reject(&:blank?)
      signed_ids.each do |signed_id|
        attachment = @location.photos.find { |p| p.signed_id == signed_id }
        attachment&.purge
      end
    end

    def attach_audio_file
      return unless params[:location][:audio_file].present?
      return if params[:location][:audio_file].blank?

      # Find or create audio tour for default locale (bs)
      audio_tour = @location.audio_tours.find_or_initialize_by(locale: "bs")
      audio_tour.save! if audio_tour.new_record?
      audio_tour.audio_file.attach(params[:location][:audio_file])
    end

    def remove_audio_file
      # Remove audio from the default locale audio tour
      audio_tour = @location.audio_tour_for("bs")
      audio_tour&.audio_file&.purge
    end
  end
end
