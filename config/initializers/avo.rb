# Avo Community is usput's admin. Who may enter is decided here and in the
# route constraint in config/routes.rb, twice on purpose: a missing check in one
# place must not open the admin. What each role may do inside is decided by
# usput's own policies, not by Avo (docs/decisions: admin-through-avo).
Avo.configure do |config|
  config.root_path = "/admin"
  config.current_user_method = :current_user
  config.sign_out_path_name = :destroy_user_session_path
  config.authorization_client = nil
  config.click_row_to_view_record = true
  config.home_path = -> { avo.welcome_path }

  config.authenticate_with do
    redirect_to main_app.root_path, alert: t("auth.curator_required") unless current_user&.can_curate?
  end
end
