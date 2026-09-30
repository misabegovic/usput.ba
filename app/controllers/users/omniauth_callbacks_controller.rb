class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include SyncsLocalData

  def google_oauth2
    payload = GuestPayloadStash.take(session)
    user = GoogleAccount.new(request.env["omniauth.auth"]).user
    return redirect_to(new_user_session_path, alert: t("auth.google.refused")) unless user

    sign_in(user, event: :authentication)
    merge_local_profile(user, payload["travel_profile_data"])
    sync_local_plans(user, payload["plans_data"])
    set_flash_message!(:notice, :success, kind: "Google")
    redirect_to after_sign_in_path_for(user)
  end
end
