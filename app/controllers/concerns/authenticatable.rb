module Authenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?, :current_user_can_curate?
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    unless logged_in?
      respond_to do |format|
        format.html { redirect_to login_path, alert: t("auth.login_required") }
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      end
    end
  end

  def log_in(user)
    session[:user_id] = user.id
  end

  def log_out
    session.delete(:user_id)
    @current_user = nil
  end

  # Permission helpers
  def current_user_can_curate?
    current_user&.can_curate?
  end

  # Authorization filters
  def require_curator
    unless current_user_can_curate?
      respond_to do |format|
        format.html { redirect_to root_path, alert: t("auth.curator_required") }
        format.json { render json: { error: "Forbidden" }, status: :forbidden }
      end
    end
  end
end
