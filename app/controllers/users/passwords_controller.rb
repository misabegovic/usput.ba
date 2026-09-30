class Users::PasswordsController < Devise::PasswordsController
  # Each request sends an email, so a script must not be able to flood an inbox.
  rate_limit to: 5, within: 1.hour, only: :create, store: RateLimitStore, with: -> { refuse_too_many_attempts }
end
