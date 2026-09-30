module Authenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?, :current_user_can_curate?, :current_user_admin?
  end

  private

  SESSION_COOKIE = :session_id
  SESSION_LIFETIME = 2.weeks
  # Kept across the reset at sign-in and sign-out; everything else the
  # session held belonged to whoever used the browser before.
  CARRIED_SESSION_KEYS = %w[return_to locale].freeze

  def current_user
    resume_session&.user
  end

  def resume_session
    return Current.session if @session_resumed

    @session_resumed = true
    Current.session = find_session_by_cookie&.tap(&:touch_seen!)
  end

  def find_session_by_cookie
    id = cookies.signed[SESSION_COOKIE]
    Session.includes(:user).find_by(id: id) if id
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    unless logged_in?
      remember_where_we_were
      respond_to do |format|
        format.html { redirect_to login_path, alert: t("auth.login_required") }
        # 303, because Turbo only follows a redirect out of a write with one.
        # Without it the control the request was aimed at reads "Content missing".
        format.turbo_stream do
          redirect_to login_path, alert: t("auth.login_required"), status: :see_other
        end
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
    reset_session_keeping_carried_keys
    new_session = user.sessions.create!(user_agent: request.user_agent.to_s[0, 255], ip_address: request.remote_ip)
    cookies.signed[SESSION_COOKIE] = {
      value: new_session.id,
      expires: SESSION_LIFETIME.from_now,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
    Current.session = new_session
    @session_resumed = true
  end

  def log_out
    resume_session&.destroy
    cookies.delete(SESSION_COOKIE)
    reset_session_keeping_carried_keys
    Current.session = nil
  end

  def refuse_too_many_attempts
    respond_to do |format|
      format.html { redirect_to request.path, alert: t("auth.too_many_attempts"), status: :see_other }
      format.json { render json: { success: false, error: t("auth.too_many_attempts") }, status: :too_many_requests }
    end
  end

  def reset_session_keeping_carried_keys
    carried = CARRIED_SESSION_KEYS.to_h { |key| [ key, session[key] ] }.compact
    reset_session
    carried.each { |key, value| session[key] = value }
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
