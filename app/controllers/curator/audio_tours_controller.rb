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

      @audio_tours = @audio_tours.page(params[:page]).per(20)

      @stats = {
        total: AudioTour.count,
        with_audio: AudioTour.with_audio.count,
        by_locale: AudioTour.group(:locale).count,
        locations_with_tours: AudioTour.distinct.count(:location_id),
        locations_total: Location.count
      }

      # Show pending proposals for this curator
      @pending_proposals = current_user.content_changes
        .where(changeable_type: "AudioTour")
        .or(current_user.content_changes.where(changeable_class: "AudioTour"))
        .pending
        .order(created_at: :desc)
    end

    def show
      @pending_proposal = pending_proposal_for(@audio_tour)
    end

    def new
      @audio_tour = AudioTour.new
      @audio_tour.location_id = params[:location_id] if params[:location_id].present?
    end

    def create
      # Instead of creating directly, create a proposal for admin review
      # Note: Audio file attachments cannot be included in proposals
      proposal = current_user.content_changes.build(
        change_type: :create_content,
        changeable_class: "AudioTour",
        proposed_data: proposal_data_from_params
      )

      if proposal.save
        location = Location.find_by(id: proposal_data_from_params["location_id"])
        record_activity("proposal_created", recordable: proposal, metadata: { type: "AudioTour", location_name: location&.name })
        redirect_to curator_audio_tours_path, notice: t("curator.proposals.submitted_for_review")
      else
        @audio_tour = AudioTour.new(audio_tour_params)
        flash.now[:alert] = t("curator.proposals.failed_to_submit")
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @pending_proposal = pending_proposal_for(@audio_tour)
    end

    def update
      # Use find_or_create to ensure only one pending proposal per resource
      # Note: Audio file changes cannot be included in proposals
      proposal = ContentChange.find_or_create_for_update(
        changeable: @audio_tour,
        user: current_user,
        original_data: @audio_tour.attributes.slice(*editable_attributes),
        proposed_data: proposal_data_from_params
      )

      if proposal.persisted?
        action = proposal.contributions.exists?(user: current_user) ? "proposal_contributed" : "proposal_updated"
        record_activity(action, recordable: @audio_tour, metadata: { type: "AudioTour", location_name: @audio_tour.location&.name })
        redirect_to curator_audio_tour_path(@audio_tour), notice: t("curator.proposals.submitted_for_review")
      else
        flash.now[:alert] = t("curator.proposals.failed_to_submit")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Use find_or_create to ensure only one pending proposal per resource
      proposal = ContentChange.find_or_create_for_delete(
        changeable: @audio_tour,
        user: current_user,
        original_data: @audio_tour.attributes.slice(*editable_attributes)
      )

      if proposal.persisted?
        record_activity("proposal_deleted", recordable: @audio_tour, metadata: { type: "AudioTour", location_name: @audio_tour.location&.name })
        redirect_to curator_audio_tours_path, notice: t("curator.proposals.delete_submitted_for_review")
      else
        redirect_to curator_audio_tours_path, alert: t("curator.proposals.failed_to_submit")
      end
    end

    private

    def set_audio_tour
      @audio_tour = AudioTour.find(params[:id])
    end

    def editable_attributes
      %w[location_id locale script word_count duration]
    end

    def proposal_data_from_params
      audio_tour_params.to_h
    end

    def audio_tour_params
      params.require(:audio_tour).permit(:location_id, :locale, :script, :word_count, :duration)
    end

    def load_form_options
      @locations = Location.order(:name)
      @locales = AudioTour.locale_options
    end
  end
end
