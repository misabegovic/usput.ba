# frozen_string_literal: true

module Curator
  class LocationSuggestionsController < BaseController
    before_action :set_location

    def new
      @suggestion = LocationSuggestion.find_or_create_pending!(
        @location,
        user: current_user,
        change_type: @location ? :update_resource : :create_resource,
        origin: :human
      )
      redirect_to edit_curator_location_location_suggestion_path(@location, @suggestion)
    end

    def create
      @suggestion = LocationSuggestion.find_or_create_pending!(
        @location,
        user: current_user,
        change_type: @location ? :update_resource : :create_resource,
        origin: :human
      )

      if @suggestion.user == current_user
        # Original creator, update directly
        if @suggestion.update(suggestion_params)
          attach_photos if params[:location_suggestion]&.dig(:proposed_photos).present?
          record_activity("suggestion_created", recordable: @suggestion)
          redirect_to curator_location_path(@location), notice: "Prijedlog uspješno kreiran."
        else
          render :edit, status: :unprocessable_entity
        end
      else
        # Different curator, add contribution
        contribution_params = suggestion_params.except(:contribution_notes).to_h.symbolize_keys
        @suggestion.add_contribution(
          user: current_user,
          notes: params[:location_suggestion][:contribution_notes],
          **contribution_params
        )
        record_activity("suggestion_contributed", recordable: @suggestion)
        redirect_to curator_location_path(@location), notice: "Doprinos prijedlogu uspješno dodan."
      end
    end

    def edit
      @suggestion = LocationSuggestion.find(params[:id])
    end

    def update
      @suggestion = LocationSuggestion.find(params[:id])

      if @suggestion.user == current_user
        if @suggestion.update(suggestion_params)
          attach_photos if params[:location_suggestion]&.dig(:proposed_photos).present?
          record_activity("suggestion_created", recordable: @suggestion)
          redirect_to curator_location_path(@location), notice: "Prijedlog ažuriran.", status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      else
        contribution_params = suggestion_params.except(:contribution_notes).to_h.symbolize_keys
        @suggestion.add_contribution(
          user: current_user,
          notes: params[:location_suggestion][:contribution_notes],
          **contribution_params
        )
        record_activity("suggestion_contributed", recordable: @suggestion)
        redirect_to curator_location_path(@location), notice: "Doprinos prijedlogu uspješno dodan.", status: :see_other
      end
    end

    private

    def set_location
      @location = Location.find_by_public_id!(params[:location_id])
    end

    def suggestion_params
      params.require(:location_suggestion).permit(
        :proposed_name, :proposed_city, :proposed_description,
        :proposed_historical_context, :proposed_lat, :proposed_lng,
        :proposed_budget, :proposed_phone, :proposed_email,
        :proposed_website, :contribution_notes,
        proposed_tags: [], proposed_social_links: {},
        proposed_experience_type_ids: []
      )
    end

    def attach_photos
      @suggestion.proposed_photos.attach(params[:location_suggestion][:proposed_photos])
    end
  end
end
