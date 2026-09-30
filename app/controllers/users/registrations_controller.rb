class Users::RegistrationsController < Devise::RegistrationsController
  include SyncsLocalData

  rate_limit to: 10, within: 1.hour, only: :create, store: RateLimitStore, with: -> { refuse_too_many_attempts }
  before_action :remember_origin_for_sign_in, only: :new
  before_action :permit_username, only: %i[create update]

  def create
    super do |user|
      if user.persisted?
        merge_local_profile(user, params[:travel_profile_data])
        sync_local_plans(user, params[:plans_data])
      end
    end
  end

  # Deleting an account has to decide what happens to its reviews, moments and
  # curator history first; until then Devise's route answers not found.
  def destroy
    head :not_found
  end

  private

  def permit_username
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end
end
