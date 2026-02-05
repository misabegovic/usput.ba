# frozen_string_literal: true

module Curator
  class PlanSuggestionsController < BaseController
    before_action :set_plan

    def new
      @suggestion = PlanSuggestion.find_or_create_pending!(
        @plan,
        user: current_user,
        change_type: @plan ? :update_resource : :create_resource,
        origin: :human
      )
      redirect_to edit_curator_plan_plan_suggestion_path(@plan, @suggestion)
    end

    def create
      @suggestion = PlanSuggestion.find_or_create_pending!(
        @plan,
        user: current_user,
        change_type: @plan ? :update_resource : :create_resource,
        origin: :human
      )

      if @suggestion.user == current_user
        # Original creator, update directly
        if @suggestion.update(suggestion_params)
          attach_cover_photo if params[:plan_suggestion]&.dig(:proposed_cover_photo).present?
          record_activity("suggestion_created", recordable: @suggestion)
          redirect_to curator_plan_path(@plan), notice: "Prijedlog uspješno kreiran."
        else
          render :edit, status: :unprocessable_entity
        end
      else
        # Different curator, add contribution
        contribution_params = suggestion_params.except(:contribution_notes).to_h.symbolize_keys
        @suggestion.add_contribution(
          user: current_user,
          notes: params[:plan_suggestion][:contribution_notes],
          **contribution_params
        )
        record_activity("suggestion_contributed", recordable: @suggestion)
        redirect_to curator_plan_path(@plan), notice: "Doprinos prijedlogu uspješno dodan."
      end
    end

    def edit
      @suggestion = PlanSuggestion.find(params[:id])
    end

    def update
      @suggestion = PlanSuggestion.find(params[:id])

      if @suggestion.user == current_user
        if @suggestion.update(suggestion_params)
          attach_cover_photo if params[:plan_suggestion]&.dig(:proposed_cover_photo).present?
          record_activity("suggestion_created", recordable: @suggestion)
          redirect_to curator_plan_path(@plan), notice: "Prijedlog ažuriran.", status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      else
        contribution_params = suggestion_params.except(:contribution_notes).to_h.symbolize_keys
        @suggestion.add_contribution(
          user: current_user,
          notes: params[:plan_suggestion][:contribution_notes],
          **contribution_params
        )
        record_activity("suggestion_contributed", recordable: @suggestion)
        redirect_to curator_plan_path(@plan), notice: "Doprinos prijedlogu uspješno dodan.", status: :see_other
      end
    end

    private

    def set_plan
      @plan = Plan.find_by_public_id!(params[:plan_id])
    end

    def suggestion_params
      params.require(:plan_suggestion).permit(
        :proposed_title, :proposed_notes, :proposed_city_name,
        :proposed_visibility, :contribution_notes,
        proposed_experience_days: {}, proposed_preferences: {}
      )
    end

    def attach_cover_photo
      @suggestion.proposed_cover_photo.attach(params[:plan_suggestion][:proposed_cover_photo])
    end
  end
end
