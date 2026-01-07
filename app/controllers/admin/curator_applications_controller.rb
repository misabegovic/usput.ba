module Admin
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
        @application.approve!(current_user)
        redirect_to admin_curator_applications_path,
          notice: t("admin.curator_applications.approved", username: @application.user.username)
      else
        redirect_to admin_curator_applications_path,
          alert: t("admin.curator_applications.already_reviewed")
      end
    end

    def reject
      if @application.pending?
        @application.reject!(current_user, params[:admin_notes])
        redirect_to admin_curator_applications_path,
          notice: t("admin.curator_applications.rejected", username: @application.user.username)
      else
        redirect_to admin_curator_applications_path,
          alert: t("admin.curator_applications.already_reviewed")
      end
    end

    private

    def set_application
      @application = CuratorApplication.find_by_public_id!(params[:id])
    end
  end
end
