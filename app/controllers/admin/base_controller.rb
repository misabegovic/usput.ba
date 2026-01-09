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

    # Require re-authentication with admin credentials for sensitive actions.
    # This provides an additional layer of security beyond the session check.
    # Controllers should apply this as a before_action on destructive endpoints.
    def require_admin_credentials
      # First verify session exists
      unless admin_logged_in?
        reject_unauthorized(t("admin.session.login_required"))
        return
      end

      # Verify Flipper flag is still enabled
      unless Flipper.enabled?(:admin_dashboard)
        reject_service_unavailable(t("admin.dashboard_disabled"))
        return
      end

      # Require credentials in request
      username = params[:admin_username].presence
      password = params[:admin_password].presence

      unless username && password
        reject_credentials_required(t("admin.credentials.required", default: "Admin credentials required for this action"))
        return
      end

      # Validate credentials
      unless valid_admin_credentials?(username, password)
        reject_invalid_credentials(t("admin.credentials.invalid", default: "Invalid admin credentials"))
        return
      end
    end

    def valid_admin_credentials?(username, password)
      admin_username = ENV["ADMIN_USERNAME"]
      admin_password = ENV["ADMIN_PASSWORD"]

      return false if admin_username.blank? || admin_password.blank?

      ActiveSupport::SecurityUtils.secure_compare(username.to_s, admin_username) &&
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, admin_password)
    end

    def reject_unauthorized(message)
      respond_to do |format|
        format.html { redirect_to admin_login_path, alert: message }
        format.json { render json: { error: message }, status: :unauthorized }
      end
    end

    def reject_service_unavailable(message)
      respond_to do |format|
        format.html { redirect_to root_path, alert: message }
        format.json { render json: { error: message }, status: :service_unavailable }
      end
    end

    def reject_credentials_required(message)
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_root_path, alert: message }
        format.json { render json: { error: message }, status: :forbidden }
      end
    end

    def reject_invalid_credentials(message)
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_root_path, alert: message }
        format.json { render json: { error: message }, status: :forbidden }
      end
    end

    def admin_logged_in?
      session[:admin_authenticated] == true
    end
    helper_method :admin_logged_in?
  end
end
