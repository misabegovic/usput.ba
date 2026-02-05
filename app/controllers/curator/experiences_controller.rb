# frozen_string_literal: true

module Curator
  class ExperiencesController < BaseController
    before_action :set_experience, only: [ :show, :edit, :update, :destroy ]
    before_action :load_form_options, only: [ :new, :create, :edit, :update ]

    def index
      @experiences = Experience.includes(:experience_category, :locations).order(created_at: :desc)
      @experiences = @experiences.by_city_name(params[:city_name]) if params[:city_name].present?
      @experiences = @experiences.by_category(params[:category_id]) if params[:category_id].present?
      @experiences = @experiences.where("experiences.title ILIKE ?", "%#{params[:search]}%") if params[:search].present?

      page = params[:items_page] || params[:page] || 1
      @experiences = @experiences.page(page).per(3)

      if params[:partial] == "items" && request.xhr?
        return render partial: "curator/experiences/experience_items", locals: { experiences: @experiences }, layout: false
      end

      @city_names = Location.joins(:experiences).where.not(city: [ nil, "" ]).distinct.pluck(:city).sort
      @experience_categories = ExperienceCategory.all

      # Show pending proposals for this curator
      @pending_proposals = current_user.content_changes
        .where(changeable_type: "Experience")
        .or(current_user.content_changes.where(changeable_class: "Experience"))
        .pending
        .order(created_at: :desc)
    end

    def show
      @pending_proposal = pending_proposal_for(@experience)
    end

    def new
      @experience = Experience.new
    end

    def create
      if admin_direct_crud?
        create_directly
      else
        create_proposal
      end
    end

    def edit
      @pending_proposal = pending_proposal_for(@experience)
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

    private

    # === Admin direct CRUD ===

    def create_directly
      @experience = Experience.new(experience_params)

      if @experience.save
        update_experience_locations(@experience)
        record_activity("resource_created", recordable: @experience, metadata: { type: "Experience", title: @experience.title })
        redirect_to curator_experience_path(@experience), notice: t("curator.experiences.created", default: "Iskustvo kreirano."), status: :see_other
      else
        flash.now[:alert] = @experience.errors.full_messages.join(", ")
        render :new, status: :unprocessable_entity
      end
    end

    def update_directly
      if @experience.update(experience_params)
        update_experience_locations(@experience)
        record_activity("resource_updated", recordable: @experience, metadata: { type: "Experience", title: @experience.title })
        redirect_to curator_experience_path(@experience), notice: t("curator.experiences.updated", default: "Iskustvo ažurirano."), status: :see_other
      else
        flash.now[:alert] = @experience.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy_directly
      title = @experience.title
      @experience.destroy!
      record_activity("resource_deleted", recordable: nil, metadata: { type: "Experience", title: title })
      redirect_to curator_experiences_path, notice: t("curator.experiences.deleted", default: "Iskustvo obrisano."), status: :see_other
    end

    def update_experience_locations(experience)
      if params[:experience][:location_uuids].present?
        uuids = params[:experience][:location_uuids].reject(&:blank?)
        experience.location_uuids = uuids
      end
    end

    # === Curator proposal workflow ===

    def create_proposal
      proposal = current_user.content_changes.build(
        change_type: :create_content,
        changeable_class: "Experience",
        proposed_data: proposal_data_from_params
      )

      if proposal.save
        record_activity("proposal_created", recordable: proposal, metadata: { type: "Experience", title: proposal_data_from_params["title"] })
        redirect_to curator_experiences_path, notice: t("curator.proposals.submitted_for_review"), status: :see_other
      else
        @experience = Experience.new(experience_params)
        flash.now[:alert] = t("curator.proposals.failed_to_submit")
        render :new, status: :unprocessable_entity
      end
    end

    def update_proposal
      proposal = ContentChange.find_or_create_for_update(
        changeable: @experience,
        user: current_user,
        original_data: build_original_data,
        proposed_data: proposal_data_from_params
      )

      if proposal.persisted?
        action = proposal.contributions.exists?(user: current_user) ? "proposal_contributed" : "proposal_updated"
        record_activity(action, recordable: @experience, metadata: { type: "Experience", title: @experience.title })
        redirect_to curator_experience_path(@experience), notice: t("curator.proposals.submitted_for_review"), status: :see_other
      else
        flash.now[:alert] = t("curator.proposals.failed_to_submit")
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy_proposal
      proposal = ContentChange.find_or_create_for_delete(
        changeable: @experience,
        user: current_user,
        original_data: build_original_data
      )

      if proposal.persisted?
        record_activity("proposal_deleted", recordable: @experience, metadata: { type: "Experience", title: @experience.title })
        redirect_to curator_experiences_path, notice: t("curator.proposals.delete_submitted_for_review"), status: :see_other
      else
        redirect_to curator_experiences_path, alert: t("curator.proposals.failed_to_submit"), status: :see_other
      end
    end

    def set_experience
      @experience = Experience.find_by_public_id!(params[:id])
    end

    def editable_attributes
      %w[title description experience_category_id estimated_duration contact_name contact_email contact_phone contact_website seasons]
    end

    def build_original_data
      data = @experience.attributes.slice(*editable_attributes)
      # Include association data that isn't in attributes
      data["location_uuids"] = @experience.location_uuids
      data
    end

    def proposal_data_from_params
      data = experience_params.to_h

      # Include location UUIDs for association
      if params[:experience][:location_uuids].present?
        data["location_uuids"] = params[:experience][:location_uuids].reject(&:blank?)
      end

      # Note: Cover photo is not included in proposals
      # It would need to be added after approval

      data
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
  end
end
