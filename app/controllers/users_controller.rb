class UsersController < ApplicationController
  before_action :require_login, only: [ :update_avatar, :remove_avatar ]

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

  def avatar_url_for(user)
    return nil unless user.avatar.attached?
    Rails.application.routes.url_helpers.rails_blob_url(user.avatar, only_path: true)
  end
end
