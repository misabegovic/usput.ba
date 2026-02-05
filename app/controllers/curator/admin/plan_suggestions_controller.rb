# frozen_string_literal: true

module Curator
  module Admin
    # Plan suggestions approval controller for admin users.
    # Allows admins to approve or reject plan suggestions from curators.
    class PlanSuggestionsController < BaseController
      before_action :set_suggestion, only: [ :show, :approve, :reject ]

      def show
      end

      def approve
        if @suggestion.pending?
          if @suggestion.approve!(current_user, notes: params[:admin_notes])
            record_activity(:approve_suggestion, recordable: @suggestion, metadata: { type: "PlanSuggestion" })
            redirect_to curator_admin_suggestions_path,
              notice: "Prijedlog odobren."
          else
            redirect_to curator_admin_plan_suggestion_path(@suggestion),
              alert: "Greška pri odobravanju prijedloga."
          end
        else
          redirect_to curator_admin_suggestions_path,
            alert: "Prijedlog je već pregledan."
        end
      rescue => e
        redirect_to curator_admin_plan_suggestion_path(@suggestion),
          alert: "Greška: #{e.message}"
      end

      def reject
        if @suggestion.pending?
          if @suggestion.reject!(current_user, notes: params[:admin_notes])
            record_activity(:reject_suggestion, recordable: @suggestion, metadata: { type: "PlanSuggestion" })
            redirect_to curator_admin_suggestions_path,
              notice: "Prijedlog odbijen."
          else
            redirect_to curator_admin_plan_suggestion_path(@suggestion),
              alert: "Greška pri odbijanju prijedloga."
          end
        else
          redirect_to curator_admin_suggestions_path,
            alert: "Prijedlog je već pregledan."
        end
      end

      private

      def set_suggestion
        @suggestion = PlanSuggestion.find(params[:id])
      end
    end
  end
end
