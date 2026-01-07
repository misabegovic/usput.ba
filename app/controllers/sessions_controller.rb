class SessionsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
  end

  def create
    user = User.find_by("lower(username) = ?", params[:username].to_s.downcase)

    if user&.authenticate(params[:password])
      log_in(user)

      # Merge travel profile from localStorage if provided
      if params[:travel_profile_data].present?
        begin
          profile_data = JSON.parse(params[:travel_profile_data])
          user.merge_travel_profile(profile_data)
        rescue JSON::ParserError
          # Ignore invalid JSON
        end
      end

      respond_to do |format|
        format.html { redirect_to root_path, notice: t("auth.login_success") }
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
