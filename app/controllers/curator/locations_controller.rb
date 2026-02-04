# frozen_string_literal: true

module Curator
  class LocationsController < BaseController
    before_action :set_location, only: [ :show, :edit, :update, :destroy ]
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
      # Instead of creating directly, create a proposal for admin review
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

    def edit
      @pending_proposal = pending_proposal_for(@location)
    end

    def update
      Rails.logger.info "[Curator::Locations] Update called for location #{@location.id} by user #{current_user.id}"
      Rails.logger.info "[Curator::Locations] Params: #{params.inspect}"
      Rails.logger.info "[Curator::Locations] Proposal data: #{proposal_data_from_params.inspect}"

      # Use find_or_create to ensure only one pending proposal per resource
      # This allows multiple curators to contribute to the same proposal
      proposal = ContentChange.find_or_create_for_update(
        changeable: @location,
        user: current_user,
        original_data: build_original_data,
        proposed_data: proposal_data_from_params
      )

      Rails.logger.info "[Curator::Locations] Proposal created: persisted=#{proposal.persisted?}, errors=#{proposal.errors.full_messages}"

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

    def destroy
      # Use find_or_create to ensure only one pending proposal per resource
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

    private

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
