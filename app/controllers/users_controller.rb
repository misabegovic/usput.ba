class UsersController < ApplicationController
  include SyncsLocalData

  before_action :require_login, only: [ :update_avatar, :remove_avatar ]

  def new
    return redirect_to root_path if logged_in?

    remember_origin_for_sign_in
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      log_in(@user)

      merge_local_profile(@user, params[:travel_profile_data])
      synced_plans = sync_local_plans(@user, params[:plans_data])

      respond_to do |format|
        format.html { redirect_to session.delete(:return_to) || root_path, notice: t("auth.registration_success") }
        format.json { render json: { success: true, user: user_json(@user), plans: synced_plans } }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update_avatar
    if params[:avatar].present?
      current_user.avatar.attach(params[:avatar])

      if current_user.save
        respond_to do |format|
          format.html { redirect_to profile_page_path, notice: t("profile.avatar.updated", default: "Profilna slika je uspješno postavljena!") }
          format.json { render json: { success: true, avatar_url: avatar_url_for(current_user) } }
        end
      else
        respond_to do |format|
          format.html { redirect_to profile_page_path, alert: current_user.errors.full_messages.join(", ") }
          format.json { render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to profile_page_path, alert: t("profile.avatar.no_file", default: "Molimo odaberite sliku.") }
        format.json { render json: { success: false, errors: [ "No file provided" ] }, status: :unprocessable_entity }
      end
    end
  end

  def remove_avatar
    if current_user.avatar.attached?
      current_user.avatar.purge
      respond_to do |format|
        format.html { redirect_to profile_page_path, notice: t("profile.avatar.removed", default: "Profilna slika je uklonjena.") }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to profile_page_path }
        format.json { render json: { success: true } }
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation)
  end

  def user_json(user)
    {
      id: user.uuid,
      username: user.username,
      travel_profile_data: user.travel_profile_data,
      avatar_url: avatar_url_for(user)
    }
  end

  def avatar_url_for(user)
    return nil unless user.avatar.attached?
    Rails.application.routes.url_helpers.rails_blob_url(user.avatar, only_path: true)
  end
end
