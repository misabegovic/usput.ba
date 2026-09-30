# Signing in with Google leaves the site and comes back, and a guest's walk can
# be larger than the session cookie holds. So what the device sent with the
# button waits in the cache, under a token the session carries, until the
# traveller returns signed in.
module GuestPayloadStash
  SESSION_KEY = "guest_payload_token"
  FIELDS = %w[travel_profile_data plans_data].freeze
  LIFETIME = 15.minutes

  def self.store(request)
    payload = FIELDS.to_h { |field| [ field, request.params[field] ] }.select { |_, value| value.is_a?(String) && value.present? }
    return if payload.empty?

    token = SecureRandom.urlsafe_base64(24)
    Rails.cache.write(cache_key(token), payload, expires_in: LIFETIME)
    request.session[SESSION_KEY] = token
  end

  def self.take(session)
    token = session.delete(SESSION_KEY)
    return {} unless token

    payload = Rails.cache.read(cache_key(token))
    Rails.cache.delete(cache_key(token))
    payload || {}
  end

  def self.cache_key(token)
    "guest_payload/#{token}"
  end
end
