module Admin
  class SessionsController < ApplicationController
    layout "admin_login"

    before_action :check_admin_dashboard_enabled, except: :destroy

    def new
      redirect_to admin_root_path if admin_logged_in?
    end

    def create
      username = params[:username]
      password = params[:password]

      if valid_admin_credentials?(username, password)
        session[:admin_authenticated] = true
        redirect_to admin_root_path, notice: t("admin.session.login_success")
      else
        flash.now[:alert] = t("admin.session.invalid_credentials")
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session.delete(:admin_authenticated)
      redirect_to admin_login_path, notice: t("admin.session.logged_out")
    end

    private

    def valid_admin_credentials?(username, password)
      return false if admin_username.blank? || admin_password.blank?

      ActiveSupport::SecurityUtils.secure_compare(username.to_s, admin_username) &&
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, admin_password)
    end

    def admin_username
      ENV["ADMIN_USERNAME"]
    end

    def admin_password
      ENV["ADMIN_PASSWORD"]
    end

    def admin_logged_in?
      session[:admin_authenticated] == true
    end

    def check_admin_dashboard_enabled
      unless Flipper.enabled?(:admin_dashboard)
        redirect_to root_path, alert: t("admin.dashboard_disabled")
      end
    end
  end
end
