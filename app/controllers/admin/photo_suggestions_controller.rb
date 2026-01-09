# frozen_string_literal: true

module Admin
  class PhotoSuggestionsController < BaseController
    before_action :set_photo_suggestion, only: [ :show, :approve, :reject ]
    before_action :require_admin_credentials, only: [ :approve, :reject ]

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
          redirect_to admin_photo_suggestions_path,
            notice: t("admin.photo_suggestions.approved")
        else
          redirect_to admin_photo_suggestion_path(@photo_suggestion),
            alert: t("admin.photo_suggestions.approval_failed")
        end
      else
        redirect_to admin_photo_suggestions_path,
          alert: t("admin.photo_suggestions.already_reviewed")
      end
    end

    def reject
      if @photo_suggestion.pending?
        @photo_suggestion.reject!(current_user, notes: params[:admin_notes])
        redirect_to admin_photo_suggestions_path,
          notice: t("admin.photo_suggestions.rejected")
      else
        redirect_to admin_photo_suggestions_path,
          alert: t("admin.photo_suggestions.already_reviewed")
      end
    end

    private

    def set_photo_suggestion
      @photo_suggestion = PhotoSuggestion.find(params[:id])
    end

    def current_user
      # For admin actions, we need a user record to associate with the review
      # Use the first admin user or create a system user
      @current_user ||= User.find_by(user_type: :admin) || User.first
    end
  end
end
