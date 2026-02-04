# frozen_string_literal: true

module Curator
  module Admin
    # Photo suggestions approval controller for admin users.
    # Allows admins to approve or reject photo suggestions from curators.
    class PhotoSuggestionsController < BaseController
      before_action :set_photo_suggestion, only: [ :show, :approve, :reject ]

      def index
        @photo_suggestions = PhotoSuggestion.includes(:user, :location).order(created_at: :desc)
        @photo_suggestions = @photo_suggestions.where(status: params[:status]) if params[:status].present?

        @stats = {
          pending: PhotoSuggestion.pending.count,
          approved: PhotoSuggestion.approved.count,
          rejected: PhotoSuggestion.rejected.count
        }
      end

      def show
      end

      def approve
        if @photo_suggestion.pending?
          if @photo_suggestion.approve!(current_user, notes: params[:admin_notes])
            record_activity(:approve_photo_suggestion, recordable: @photo_suggestion)
            redirect_to curator_admin_photo_suggestions_path,
              notice: t("curator.admin.photo_suggestions.approved")
          else
            redirect_to curator_admin_photo_suggestion_path(@photo_suggestion),
              alert: t("curator.admin.photo_suggestions.approval_failed")
          end
        else
          redirect_to curator_admin_photo_suggestions_path,
            alert: t("curator.admin.photo_suggestions.already_reviewed")
        end
      end

      def reject
        if @photo_suggestion.pending?
          if @photo_suggestion.reject!(current_user, notes: params[:admin_notes])
            record_activity(:reject_photo_suggestion, recordable: @photo_suggestion)
            redirect_to curator_admin_photo_suggestions_path,
              notice: t("curator.admin.photo_suggestions.rejected")
          else
            redirect_to curator_admin_photo_suggestion_path(@photo_suggestion),
              alert: t("curator.admin.photo_suggestions.rejection_failed")
          end
        else
          redirect_to curator_admin_photo_suggestions_path,
            alert: t("curator.admin.photo_suggestions.already_reviewed")
        end
      end

      private

      def set_photo_suggestion
        @photo_suggestion = PhotoSuggestion.find(params[:id])
      end
    end
  end
end
