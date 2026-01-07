module Curator
  class ExperiencesController < BaseController
    before_action :set_experience, only: [ :show, :edit, :update, :destroy ]
    before_action :load_form_options, only: [ :new, :create, :edit, :update ]

    def index
      @experiences = Experience.includes(:experience_category, :locations).order(created_at: :desc)
      @experiences = @experiences.by_city_name(params[:city_name]) if params[:city_name].present?
      @experiences = @experiences.by_category(params[:category_id]) if params[:category_id].present?
      @experiences = @experiences.where("experiences.title ILIKE ?", "%#{params[:search]}%") if params[:search].present?
      @city_names = Location.joins(:experiences).where.not(city: [nil, ""]).distinct.pluck(:city).sort
      @experience_categories = ExperienceCategory.all
    end

    def show
    end

    def new
      @experience = Experience.new
    end

    def create
      @experience = Experience.new(experience_params)

      if @experience.save
        update_locations
        attach_cover_photo
        redirect_to curator_experience_path(@experience), notice: t("curator.experiences.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      remove_cover_photo if params[:experience][:remove_cover_photo] == "1"

      if @experience.update(experience_params)
        update_locations
        attach_cover_photo
        redirect_to curator_experience_path(@experience), notice: t("curator.experiences.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @experience.destroy
      redirect_to curator_experiences_path, notice: t("curator.experiences.deleted")
    end

    private

    def set_experience
      @experience = Experience.find_by_public_id!(params[:id])
    end

    def experience_params
      params.require(:experience).permit(
        :title, :description, :experience_category_id, :estimated_duration,
        :contact_name, :contact_email, :contact_phone, :contact_website,
        seasons: []
      )
    end

    def load_form_options
      @experience_categories = ExperienceCategory.all
      @locations = Location.order(:name)
    end

    def attach_cover_photo
      return unless params[:experience][:cover_photo].present?
      return if params[:experience][:cover_photo].blank?
      @experience.cover_photo.attach(params[:experience][:cover_photo])
    end

    def remove_cover_photo
      @experience.cover_photo.purge if @experience.cover_photo.attached?
    end

    def update_locations
      return unless params[:experience][:location_uuids].present?

      location_uuids = params[:experience][:location_uuids].reject(&:blank?)

      # Convert UUIDs to database IDs
      locations = Location.where(uuid: location_uuids).index_by(&:uuid)
      location_ids = location_uuids.filter_map { |uuid| locations[uuid]&.id }

      # Remove existing locations not in the new list
      @experience.experience_locations.where.not(location_id: location_ids).destroy_all

      # Add/update locations with positions (preserving order from form)
      location_uuids.each_with_index do |uuid, index|
        location = locations[uuid]
        next unless location

        exp_loc = @experience.experience_locations.find_or_initialize_by(location_id: location.id)
        exp_loc.position = index + 1
        exp_loc.save
      end
    end
  end
end
