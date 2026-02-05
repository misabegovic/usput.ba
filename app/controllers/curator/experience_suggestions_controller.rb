# frozen_string_literal: true

module Curator
  class ExperienceSuggestionsController < BaseController
    before_action :set_experience

    def new
      @suggestion = ExperienceSuggestion.find_or_create_pending!(
        @experience,
        user: current_user,
        change_type: @experience ? :update_resource : :create_resource,
        origin: :human
      )
      redirect_to edit_curator_experience_experience_suggestion_path(@experience, @suggestion)
    end

    def create
      @suggestion = ExperienceSuggestion.find_or_create_pending!(
        @experience,
        user: current_user,
        change_type: @experience ? :update_resource : :create_resource,
        origin: :human
      )

      if @suggestion.user == current_user
        # Original creator, update directly
        if @suggestion.update(suggestion_params)
          attach_cover_photo if params[:experience_suggestion]&.dig(:proposed_cover_photo).present?
          record_activity("suggestion_created", recordable: @suggestion)
          redirect_to curator_experience_path(@experience), notice: "Prijedlog uspješno kreiran."
        else
          render :edit, status: :unprocessable_entity
        end
      else
        # Different curator, add contribution
        contribution_params = suggestion_params.except(:contribution_notes).to_h.symbolize_keys
        @suggestion.add_contribution(
          user: current_user,
          notes: params[:experience_suggestion][:contribution_notes],
          **contribution_params
        )
        record_activity("suggestion_contributed", recordable: @suggestion)
        redirect_to curator_experience_path(@experience), notice: "Doprinos prijedlogu uspješno dodan."
      end
    end

    def edit
      @suggestion = ExperienceSuggestion.find(params[:id])
    end

    def update
      @suggestion = ExperienceSuggestion.find(params[:id])

      if @suggestion.user == current_user
        if @suggestion.update(suggestion_params)
          attach_cover_photo if params[:experience_suggestion]&.dig(:proposed_cover_photo).present?
          record_activity("suggestion_created", recordable: @suggestion)
          redirect_to curator_experience_path(@experience), notice: "Prijedlog ažuriran.", status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      else
        contribution_params = suggestion_params.except(:contribution_notes).to_h.symbolize_keys
        @suggestion.add_contribution(
          user: current_user,
          notes: params[:experience_suggestion][:contribution_notes],
          **contribution_params
        )
        record_activity("suggestion_contributed", recordable: @suggestion)
        redirect_to curator_experience_path(@experience), notice: "Doprinos prijedlogu uspješno dodan.", status: :see_other
      end
    end

    private

    def set_experience
      @experience = Experience.find_by_public_id!(params[:experience_id])
    end

    def suggestion_params
      params.require(:experience_suggestion).permit(
        :proposed_title, :proposed_description, :proposed_contact_name,
        :proposed_contact_email, :proposed_contact_phone,
        :proposed_contact_website, :contribution_notes,
        proposed_seasons: [], proposed_location_uuids: [],
        proposed_video_urls: []
      )
    end

    def attach_cover_photo
      @suggestion.proposed_cover_photo.attach(params[:experience_suggestion][:proposed_cover_photo])
    end
  end
end
