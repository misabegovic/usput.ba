# frozen_string_literal: true

module Curator
  module Admin
    # Curator applications approval controller for admin users.
    # Allows admins to approve or reject curator applications.
    class CuratorApplicationsController < BaseController
      before_action :set_application, only: [ :show, :approve, :reject ]

      def index
        @applications = CuratorApplication.includes(:user, :reviewed_by).recent
        @applications = @applications.where(status: params[:status]) if params[:status].present?

        @stats = {
          pending: CuratorApplication.pending.count,
          approved: CuratorApplication.approved.count,
          rejected: CuratorApplication.rejected.count
        }
      end

      def show
      end

      def approve
        if @application.pending?
          if @application.approve!(current_user)
            record_activity(:approve_curator_application, recordable: @application)
            redirect_to curator_admin_curator_applications_path,
              notice: t("curator.admin.curator_applications.approved", username: @application.user.username)
          else
            redirect_to curator_admin_curator_application_path(@application),
              alert: t("curator.admin.curator_applications.approval_failed")
          end
        else
          redirect_to curator_admin_curator_applications_path,
            alert: t("curator.admin.curator_applications.already_reviewed")
        end
      end

      def reject
        if @application.pending?
          if @application.reject!(current_user, params[:admin_notes])
            record_activity(:reject_curator_application, recordable: @application)
            redirect_to curator_admin_curator_applications_path,
              notice: t("curator.admin.curator_applications.rejected", username: @application.user.username)
          else
            redirect_to curator_admin_curator_application_path(@application),
              alert: t("curator.admin.curator_applications.rejection_failed")
          end
        else
          redirect_to curator_admin_curator_applications_path,
            alert: t("curator.admin.curator_applications.already_reviewed")
        end
      end

      private

      def set_application
        @application = CuratorApplication.find_by_public_id!(params[:id])
      end
    end
  end
end
