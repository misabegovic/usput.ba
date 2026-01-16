# frozen_string_literal: true

module Curator
  module Admin
    # Content changes approval controller for admin users.
    # Allows admins to approve or reject content change proposals from curators.
    class ContentChangesController < BaseController
      before_action :set_content_change, only: [:show, :approve, :reject]

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
            record_activity(:approve_content_change, recordable: @content_change)
            redirect_to curator_admin_content_changes_path,
              notice: t("curator.admin.content_changes.approved")
          else
            redirect_to curator_admin_content_change_path(@content_change),
              alert: t("curator.admin.content_changes.approval_failed")
          end
        else
          redirect_to curator_admin_content_changes_path,
            alert: t("curator.admin.content_changes.already_reviewed")
        end
      end

      def reject
        if @content_change.pending?
          if @content_change.reject!(current_user, notes: params[:admin_notes])
            record_activity(:reject_content_change, recordable: @content_change)
            redirect_to curator_admin_content_changes_path,
              notice: t("curator.admin.content_changes.rejected")
          else
            redirect_to curator_admin_content_change_path(@content_change),
              alert: t("curator.admin.content_changes.rejection_failed")
          end
        else
          redirect_to curator_admin_content_changes_path,
            alert: t("curator.admin.content_changes.already_reviewed")
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
end
