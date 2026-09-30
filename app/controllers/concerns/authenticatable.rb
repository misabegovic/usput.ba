module Authenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :logged_in?, :current_user_can_curate?, :current_user_admin?
  end

  private

  def logged_in?
    user_signed_in?
  end

  def require_login
    unless logged_in?
      remember_where_we_were
      respond_to do |format|
        format.html { redirect_to new_user_session_path, alert: t("auth.login_required") }
        # 303, because Turbo only follows a redirect out of a write with one.
        # Without it the control the request was aimed at reads "Content missing".
        format.turbo_stream do
          redirect_to new_user_session_path, alert: t("auth.login_required"), status: :see_other
        end
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      end
    end
  end

  def remember_where_we_were(path = request.fullpath)
    store_location_for(:user, path) if request.get? && internal_path?(path) && !auth_path?(path)
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
    [ new_user_session_path, new_user_registration_path ].include?(path.to_s.split("?").first)
  end

  def referring_path
    URI.parse(request.referer.to_s).path.presence
  rescue URI::InvalidURIError
    nil
  end

  def refuse_too_many_attempts
    respond_to do |format|
      format.html { redirect_back_or_to new_user_session_path, alert: t("auth.too_many_attempts"), status: :see_other }
      format.json { render json: { success: false, error: t("auth.too_many_attempts") }, status: :too_many_requests }
    end
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
