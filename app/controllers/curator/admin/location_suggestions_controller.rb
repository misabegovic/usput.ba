# frozen_string_literal: true

module Curator
  module Admin
    # Location suggestions approval controller for admin users.
    # Allows admins to approve or reject location suggestions from curators.
    class LocationSuggestionsController < BaseController
      before_action :set_suggestion, only: [ :show, :approve, :reject ]

      def show
      end

      def approve
        if @suggestion.pending?
          if @suggestion.approve!(current_user, notes: params[:admin_notes])
            record_activity(:approve_suggestion, recordable: @suggestion, metadata: { type: "LocationSuggestion" })
            redirect_to curator_admin_suggestions_path,
              notice: "Prijedlog odobren."
          else
            redirect_to curator_admin_location_suggestion_path(@suggestion),
              alert: "Greška pri odobravanju prijedloga."
          end
        else
          redirect_to curator_admin_suggestions_path,
            alert: "Prijedlog je već pregledan."
        end
      rescue => e
        redirect_to curator_admin_location_suggestion_path(@suggestion),
          alert: "Greška: #{e.message}"
      end

      def reject
        if @suggestion.pending?
          if @suggestion.reject!(current_user, notes: params[:admin_notes])
            record_activity(:reject_suggestion, recordable: @suggestion, metadata: { type: "LocationSuggestion" })
            redirect_to curator_admin_suggestions_path,
              notice: "Prijedlog odbijen."
          else
            redirect_to curator_admin_location_suggestion_path(@suggestion),
              alert: "Greška pri odbijanju prijedloga."
          end
        else
          redirect_to curator_admin_suggestions_path,
            alert: "Prijedlog je već pregledan."
        end
      end

      private

      def set_suggestion
        @suggestion = LocationSuggestion.find(params[:id])
      end
    end
  end
end
