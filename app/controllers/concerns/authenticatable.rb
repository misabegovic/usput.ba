module Authenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?, :current_user_can_curate?, :current_user_admin?
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
      remember_where_we_were
      respond_to do |format|
        format.html { redirect_to login_path, alert: t("auth.login_required") }
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      end
    end
  end

  def remember_where_we_were(path = request.fullpath)
    session[:return_to] = path if request.get? && internal_path?(path) && !auth_path?(path)
  end

  # A visitor who reaches sign-in through an ordinary link carries no return_to,
  # so the referring page is the only record of where they were.
  def remember_origin_for_sign_in
    remember_where_we_were(params[:return_to].presence || referring_path)
  end

  def internal_path?(path)
    path.to_s.match?(%r{\A/(?!/)})
  end

  # Remembering an auth page would bounce the visitor between login and register
  # instead of back to the page they left.
  def auth_path?(path)
    [ login_path, register_path ].include?(path.to_s.split("?").first)
  end

  def referring_path
    URI.parse(request.referer.to_s).path.presence
  rescue URI::InvalidURIError
    nil
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

  # Admin permission helpers
  def current_user_admin?
    current_user&.admin?
  end

  def require_admin
    unless current_user_admin?
      respond_to do |format|
        format.html { redirect_to curator_root_path, alert: t("auth.admin_required") }
        format.json { render json: { error: "Forbidden" }, status: :forbidden }
      end
    end
  end
end
