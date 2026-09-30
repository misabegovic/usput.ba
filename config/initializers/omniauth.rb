# The Google button carries the guest's walk; keep it for the callback.
OmniAuth.config.before_request_phase = ->(env) { GuestPayloadStash.store(Rack::Request.new(env)) }

# The button is shown only where Google credentials exist.
Rails.configuration.x.google_sign_in = Rails.application.credentials.dig(:google, :client_id).present?
