class SessionsController < ApplicationController
  include SyncsLocalData

  rate_limit to: 10, within: 3.minutes, only: :create, store: RateLimitStore, with: -> { refuse_too_many_attempts }

  def new
    return redirect_to root_path if logged_in?

    remember_origin_for_sign_in
  end

  def create
    user = User.authenticate_by(username: params[:username].to_s.downcase, password: params[:password].to_s)

    if user
      log_in(user)

      merge_local_profile(user, params[:travel_profile_data])
      sync_local_plans(user, params[:plans_data])

      respond_to do |format|
        format.html { redirect_to session.delete(:return_to) || root_path, notice: t("auth.login_success") }
        format.json { render json: { success: true, user: user_json(user) } }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t("auth.invalid_credentials")
          render :new, status: :unprocessable_entity
        end
        format.json { render json: { success: false, error: t("auth.invalid_credentials") }, status: :unauthorized }
      end
    end
  end

  def destroy
    log_out
    respond_to do |format|
      format.html { redirect_to root_path, notice: t("auth.logout_success") }
      format.json { render json: { success: true } }
    end
  end

  private

  def user_json(user)
    {
      id: user.uuid,
      username: user.username,
      travel_profile_data: user.travel_profile_data
    }
  end
end
