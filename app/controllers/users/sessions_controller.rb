class Users::SessionsController < Devise::SessionsController
  include SyncsLocalData

  rate_limit to: 10, within: 3.minutes, only: :create, store: RateLimitStore, with: -> { refuse_too_many_attempts }
  before_action :remember_origin_for_sign_in, only: :new

  def create
    super do |user|
      merge_local_profile(user, params[:travel_profile_data])
      sync_local_plans(user, params[:plans_data])
    end
  end

  # Signing out clears the whole session; the language the visitor chose is not
  # the account's to take with it.
  def destroy
    locale = session[:locale]
    super { session[:locale] = locale if locale }
  end
end
