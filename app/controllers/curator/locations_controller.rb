# frozen_string_literal: true

module Curator
  class LocationsController < BaseController
    before_action :set_location, only: [ :show, :edit, :update, :destroy, :generate_audio_tour ]
    before_action :load_form_options, only: [ :new, :create, :edit, :update ]

    def index
      @locations = Location.order(created_at: :desc)
      @locations = @locations.by_city(params[:city_name]) if params[:city_name].present?
      @locations = @locations.by_category(params[:category]) if params[:category].present?
      @locations = @locations.where("locations.name ILIKE ?", "%#{params[:search]}%") if params[:search].present?

      page = params[:items_page] || params[:page] || 1
      @locations = @locations.page(page).per(3)

      if params[:partial] == "items" && request.xhr?
        return render partial: "curator/locations/location_items", locals: { locations: @locations }, layout: false
      end

      @city_names = Location.where.not(city: [ nil, "" ]).distinct.pluck(:city).sort
      @location_categories = LocationCategory.active.ordered

      # Show pending proposals for this curator
      @pending_proposals = current_user.content_changes
        .where(changeable_type: "Location")
        .or(current_user.content_changes.where(changeable_class: "Location"))
        .pending
        .order(created_at: :desc)
    end

    def needs_photos
      # Get locations sorted by photo count (ascending)
      @locations = Location
        .left_joins(:photos_attachments)
        .group("locations.id")
        .select("locations.*, COUNT(active_storage_attachments.id) AS photos_count")
        .order("photos_count ASC, locations.name ASC")

      # Filter by city if provided
      @locations = @locations.where(city: params[:city]) if params[:city].present?

      # Filter by max photos count
      if params[:max_photos].present?
        @locations = @locations.having("COUNT(active_storage_attachments.id) <= ?", params[:max_photos].to_i)
      end

      page = params[:items_page] || params[:page] || 1
      @locations = @locations.page(page).per(12)

      # Handle partial loading for load-more
      if params[:partial] == "items" && request.xhr?
        return render partial: "curator/locations/needs_photo_items", locals: { locations: @locations }, layout: false
      end

      @city_names = Location.where.not(city: [ nil, "" ]).distinct.pluck(:city).sort
    end

    def show
      @pending_proposal = pending_proposal_for(@location)
    end

    def new
      @location = Location.new
    end

    def create
      if admin_direct_crud?
        create_directly
      else
        create_proposal
      end
    end

    def edit
      @pending_proposal = pending_proposal_for(@location)
    end

    def update
      if admin_direct_crud?
        update_directly
      else
        update_proposal
      end
    end

    def destroy
      if admin_direct_crud?
        destroy_directly
      else
        destroy_proposal
      end
    end

    def generate_audio_tour
      unless current_user.admin?
        redirect_to curator_location_path(@location), alert: "Samo admin može generisati audio ture."
        return
      end

      locale = params[:locale] || "bs"

      # Check for recent generation request to prevent duplicate jobs
      recent_request = CuratorActivity
        .where(action: "audio_tour_generation_requested")
        .where(recordable: @location)
        .where("created_at > ?", 10.minutes.ago)
        .exists?

      if recent_request
        redirect_to curator_location_path(@location), alert: "Generisanje je već pokrenuto. Sačekajte da se završi."
        return
      end

      AudioTourGenerateJob.perform_later(
        location_id: @location.id,
        locale: locale,
        requested_by_id: current_user.id
      )

      record_activity("audio_tour_generation_requested",
        recordable: @location,
        metadata: { locale: locale }
      )

      redirect_to curator_location_path(@location),
        notice: "Audio tura za #{locale.upcase} se generise u pozadini."
    end

    private

    # === Admin direct CRUD ===

    def create_directly
      result = LocationCreator.new(location_params.to_h).call

      if result.success?
        record_activity("resource_created", recordable: result.location, metadata: { type: "Location", name: result.location.name })
        redirect_to curator_location_path(result.location), notice: t("curator.locations.created", default: "Lokacija kreirana."), status: :see_other
      else
        @location = Location.new(location_params)
        flash.now[:alert] = result.errors.join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    def update_directly
      result = LocationUpdater.new(@location, location_params.to_h).call

      if result.success?
        record_activity("resource_updated", recordable: @location, metadata: { type: "Location", name: @location.name })
        redirect_to curator_location_path(@location), notice: t("curator.locations.updated", default: "Lokacija ažurirana."), status: :see_other
      else
        flash.now[:alert] = result.errors.join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy_directly
      name = @location.name
      @location.destroy!
      record_activity("resource_deleted", recordable: nil, metadata: { type: "Location", name: name })
      redirect_to curator_locations_path, notice: t("curator.locations.deleted", default: "Lokacija obrisana."), status: :see_other
    end

    # === Curator proposal workflow ===

    def create_proposal
      proposal = current_user.content_changes.build(
        change_type: :create_content,
        changeable_class: "Location",
        proposed_data: proposal_data_from_params
      )

      if proposal.save
        record_activity("proposal_created", recordable: proposal, metadata: { type: "Location", name: proposal_data_from_params["name"] })
        redirect_to curator_locations_path, notice: t("curator.proposals.submitted_for_review"), status: :see_other
      else
        @location = Location.new(location_params)
        flash.now[:alert] = t("curator.proposals.failed_to_submit")
        render :new, status: :unprocessable_entity
      end
    end

    def update_proposal
      proposal = ContentChange.find_or_create_for_update(
        changeable: @location,
        user: current_user,
        original_data: build_original_data,
        proposed_data: proposal_data_from_params
      )

      if proposal.persisted?
        action = proposal.contributions.exists?(user: current_user) ? "proposal_contributed" : "proposal_updated"
        record_activity(action, recordable: @location, metadata: { type: "Location", name: @location.name })
        redirect_to curator_location_path(@location), notice: t("curator.proposals.submitted_for_review"), status: :see_other
      else
        error_message = proposal.errors.full_messages.any? ? proposal.errors.full_messages.join(", ") : t("curator.proposals.failed_to_submit")
        flash.now[:alert] = error_message
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end

    def destroy_proposal
      proposal = ContentChange.find_or_create_for_delete(
        changeable: @location,
        user: current_user,
        original_data: build_original_data
      )

      if proposal.persisted?
        record_activity("proposal_deleted", recordable: @location, metadata: { type: "Location", name: @location.name })
        redirect_to curator_locations_path, notice: t("curator.proposals.delete_submitted_for_review"), status: :see_other
      else
        redirect_to curator_locations_path, alert: t("curator.proposals.failed_to_submit"), status: :see_other
      end
    end

    def set_location
      @location = Location.find_by_public_id!(params[:id])
    end

    def editable_attributes
      %w[name description historical_context city lat lng budget phone email website video_url tags suitable_experiences social_links]
    end

    def build_original_data
      data = @location.attributes.slice(*editable_attributes)
      # Include association IDs that aren't in attributes
      data["location_category_ids"] = @location.location_category_ids
      data
    end

    def proposal_data_from_params
      data = location_params.to_h

      # Include category IDs
      if params[:location][:location_category_ids].present?
        data["location_category_ids"] = params[:location][:location_category_ids].reject(&:blank?).map(&:to_i)
      end

      # Include experience type keys (for proposal system compatibility)
      # Note: The actual sync happens via set_experience_types when proposal is applied
      if params[:location][:suitable_experiences].present?
        data["suitable_experiences"] = params[:location][:suitable_experiences].reject(&:blank?)
      end

      # Note: File attachments (photos, audio) are not included in proposals
      # They would need to be added after approval or handled separately

      data
    end

    def location_params
      permitted = params.require(:location).permit(
        :name, :description, :historical_context, :city,
        :lat, :lng, :budget,
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
      @city_names = Location.where.not(city: [ nil, "" ]).distinct.pluck(:city).sort
      @experience_types = ExperienceType.where(active: true).order(:position)
      @location_categories = LocationCategory.active.ordered
    end
  end
end
