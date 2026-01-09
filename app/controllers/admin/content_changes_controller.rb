# frozen_string_literal: true

module Admin
  class ContentChangesController < BaseController
    before_action :set_content_change, only: [ :show, :approve, :reject ]
    before_action :require_admin_credentials, only: [ :approve, :reject ]

    def index
      @content_changes = ContentChange.includes(:user, :changeable, :reviewed_by).order(created_at: :desc)
      @content_changes = @content_changes.where(status: params[:status]) if params[:status].present?
      @content_changes = @content_changes.where(change_type: params[:type]) if params[:type].present?
      @content_changes = filter_by_content_type(@content_changes) if params[:content_type].present?

      @stats = {
        pending: ContentChange.pending.count,
        approved: ContentChange.approved.count,
        rejected: ContentChange.rejected.count
      }
    end

    def show
    end

    def approve
      if @content_change.pending?
        if @content_change.approve!(current_user, notes: params[:admin_notes])
          redirect_to admin_content_changes_path,
            notice: t("admin.content_changes.approved")
        else
          redirect_to admin_content_change_path(@content_change),
            alert: "Failed to apply changes. Please check the logs."
        end
      else
        redirect_to admin_content_changes_path,
          alert: t("admin.content_changes.already_reviewed")
      end
    end

    def reject
      if @content_change.pending?
        @content_change.reject!(current_user, notes: params[:admin_notes])
        redirect_to admin_content_changes_path,
          notice: t("admin.content_changes.rejected")
      else
        redirect_to admin_content_changes_path,
          alert: t("admin.content_changes.already_reviewed")
      end
    end

    private

    def set_content_change
      @content_change = ContentChange.find(params[:id])
    end

    def filter_by_content_type(scope)
      content_type = params[:content_type]
      scope.where(changeable_type: content_type)
        .or(scope.where(changeable_class: content_type))
    end
  end
end
