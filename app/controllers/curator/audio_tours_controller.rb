module Curator
  class AudioToursController < BaseController
    before_action :set_audio_tour, only: [ :show, :edit, :update, :destroy ]
    before_action :load_form_options, only: [ :new, :create, :edit, :update ]

    def index
      @audio_tours = AudioTour.includes(:location).order(created_at: :desc)
      @audio_tours = @audio_tours.by_locale(params[:locale]) if params[:locale].present?

      if params[:location_id].present?
        @audio_tours = @audio_tours.where(location_id: params[:location_id])
      end

      if params[:search].present?
        @audio_tours = @audio_tours.joins(:location).where("locations.name ILIKE ?", "%#{params[:search]}%")
      end

      @stats = {
        total: AudioTour.count,
        with_audio: AudioTour.with_audio.count,
        by_locale: AudioTour.group(:locale).count,
        locations_with_tours: AudioTour.distinct.count(:location_id),
        locations_total: Location.count
      }
    end

    def show
    end

    def new
      @audio_tour = AudioTour.new
      @audio_tour.location_id = params[:location_id] if params[:location_id].present?
    end

    def create
      @audio_tour = AudioTour.new(audio_tour_params)

      if @audio_tour.save
        attach_audio_file
        redirect_to curator_audio_tour_path(@audio_tour), notice: t("curator.audio_tours.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      remove_audio_file if params[:audio_tour][:remove_audio_file] == "1"

      if @audio_tour.update(audio_tour_params)
        attach_audio_file
        redirect_to curator_audio_tour_path(@audio_tour), notice: t("curator.audio_tours.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @audio_tour.destroy
      redirect_to curator_audio_tours_path, notice: t("curator.audio_tours.deleted")
    end

    private

    def set_audio_tour
      @audio_tour = AudioTour.find(params[:id])
    end

    def audio_tour_params
      params.require(:audio_tour).permit(:location_id, :locale, :script, :word_count, :duration)
    end

    def load_form_options
      @locations = Location.order(:name)
      @locales = AudioTour.locale_options
    end

    def attach_audio_file
      return unless params[:audio_tour][:audio_file].present?
      return if params[:audio_tour][:audio_file].blank?
      @audio_tour.audio_file.attach(params[:audio_tour][:audio_file])
    end

    def remove_audio_file
      @audio_tour.audio_file.purge if @audio_tour.audio_file.attached?
    end
  end
end
