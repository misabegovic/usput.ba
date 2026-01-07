module Admin
  class BaseController < ApplicationController
    before_action :check_admin_dashboard_enabled
    before_action :require_admin_auth

    layout "admin"

    private

    def check_admin_dashboard_enabled
      unless ENV["ADMIN_DASHBOARD"] == "true" && Flipper.enabled?(:admin_dashboard)
        respond_to do |format|
          format.html { redirect_to root_path, alert: t("admin.dashboard_disabled") }
          format.json { render json: { error: "Admin dashboard is disabled" }, status: :service_unavailable }
        end
      end
    end

    def require_admin_auth
      unless admin_logged_in?
        respond_to do |format|
          format.html { redirect_to admin_login_path, alert: t("admin.session.login_required") }
          format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
        end
      end
    end

    def admin_logged_in?
      session[:admin_authenticated] == true
    end
    helper_method :admin_logged_in?
  end
end
