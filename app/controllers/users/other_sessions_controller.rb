class Users::OtherSessionsController < ApplicationController
  before_action :require_login

  def destroy
    current_user.end_sessions
    bypass_sign_in(current_user)
    redirect_to edit_user_registration_path, notice: t("auth.other_sessions_ended"), status: :see_other
  end
end
