# Rollbar Error Monitoring Configuration
# https://docs.rollbar.com/docs/ruby

Rollbar.configure do |config|
  # Access token from environment variable
  config.access_token = ENV.fetch("ROLLBAR_ACCESS_TOKEN", nil)

  # Disable Rollbar if no access token is provided (development/test)
  config.enabled = config.access_token.present?

  # Environment name
  config.environment = ENV.fetch("ROLLBAR_ENV", Rails.env)

  # Use async reporting in production for better performance
  config.use_async = Rails.env.production?

  # Person tracking - get user info from controller's rollbar_person method
  config.person_method = "rollbar_person"
  config.person_id_method = "id"
  config.person_email_method = "email"

  # Scrub sensitive fields from reports
  # Uses the same fields as Rails filter_parameters plus additional ones
  config.scrub_fields = [
    :passw,
    :secret,
    :token,
    :_key,
    :crypt,
    :salt,
    :certificate,
    :otp,
    :ssn,
    :cvv,
    :cvc,
    :authorization,
    :api_key,
    :access_token,
    :password,
    :password_confirmation
  ]

  # Don't report these exception classes
  config.exception_level_filters.merge!(
    "ActionController::RoutingError" => "ignore",
    "ActionController::InvalidAuthenticityToken" => "ignore"
  )

  # Add custom data to all reports
  config.custom_data_method = lambda do
    {
      rails_version: Rails::VERSION::STRING,
      ruby_version: RUBY_VERSION
    }
  end
end
