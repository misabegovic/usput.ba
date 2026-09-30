# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and blocking abusive requests
# Documentation: https://github.com/rack/rack-attack

class Rack::Attack
  # Use Rails cache for storing request counts
  Rack::Attack.cache.store = Rails.cache

  # ----------------------------------------------------------------------------
  # Safelist: Allow all requests from localhost in development
  # ----------------------------------------------------------------------------
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # ----------------------------------------------------------------------------
  # Throttle: General request limit per IP
  # ----------------------------------------------------------------------------
  # Limit all requests to 300 per 5 minutes (60 req/min average)
  # This prevents aggressive scraping while allowing normal browsing
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/packs")
  end

  # Sign-in, registration, password reset and confirmation requests are
  # limited in their controllers with `rate_limit`, which counts in the shared
  # Solid Cache store. Every throttle below names a path the app routes; the
  # test in test/integration/rack_attack_test.rb holds them to that.

  # ----------------------------------------------------------------------------
  # Throttle: Plan sync endpoint
  # ----------------------------------------------------------------------------
  # Limit plan sync to 20 per minute per IP
  throttle("plan_sync/ip", limit: 20, period: 1.minute) do |req|
    if req.path == "/user/plans/sync" && req.post?
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # Throttle: Search endpoints
  # ----------------------------------------------------------------------------
  # Limit the city lookup behind the plan wizard to 30 per minute per IP. Explore
  # search is covered by the general limit.
  throttle("search/ip", limit: 30, period: 1.minute) do |req|
    if req.path == "/plans/search_cities"
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # Throttle: Public mine-proximity check
  # ----------------------------------------------------------------------------
  # Limit mine checks to 30 per minute per IP — also hampers anyone trying to
  # reconstruct area boundaries by sweeping coordinates
  throttle("mine-check/ip", limit: 30, period: 1.minute) do |req|
    if req.path == "/mine-check/check" && req.post?
      req.ip
    end
  end

  # Overlay tiles of generalized area boundaries — map panning is chatty,
  # but sustained sweeping (bulk boundary scraping) gets cut off
  throttle("mine-areas/ip", limit: 60, period: 1.minute) do |req|
    if req.path == "/mine-check/areas"
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # Blocklist: Exploit probes and malicious requests
  # ----------------------------------------------------------------------------

  # Block PHP/ASP/JSP file requests (common injection attempts)
  blocklist("block-executable-extensions") do |req|
    req.path =~ /\.(php|phtml|php3|php4|php5|php7|phps|asp|aspx|jsp|cgi|pl)$/i
  end

  # Block WordPress/CMS probes
  blocklist("block-cms-probes") do |req|
    req.path =~ %r{(wp-admin|wp-login|wp-content|wp-includes|xmlrpc\.php|wordpress)}i
  end

  # Block sensitive file access attempts
  blocklist("block-sensitive-files") do |req|
    req.path =~ %r{(\.env|\.git|\.htaccess|\.htpasswd|\.ssh|\.aws|config\.php|web\.config)}i
  end

  # Block common vulnerability scanners paths
  blocklist("block-scanner-paths") do |req|
    req.path =~ %r{(phpMyAdmin|phpmyadmin|pma|adminer|mysql|solr|elasticsearch|_profiler)}i
  end

  # Block path traversal attempts
  blocklist("block-path-traversal") do |req|
    req.path.include?("..") ||
    req.path.include?("%2e%2e") ||
    CGI.unescape(req.path).include?("..")
  end

  # Block null byte injection attempts
  blocklist("block-null-byte") do |req|
    req.path.include?("%00") || req.query_string&.include?("%00")
  end

  # Fail2Ban: Auto-ban repeat offenders
  blocklist("fail2ban-pentesters") do |req|
    Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
      # Trigger on any suspicious pattern
      CGI.unescape(req.query_string.to_s) =~ %r{(/etc/passwd|/proc/|union\s+select|<script)}i ||
      req.path =~ %r{(shell|cmd|exec|system|eval|base64)}i
    end
  end

  # ----------------------------------------------------------------------------
  # Custom responses
  # ----------------------------------------------------------------------------
  # Return 429 Too Many Requests with Retry-After header
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [ { error: "Rate limit exceeded. Retry in #{retry_after} seconds." }.to_json ]
    ]
  end

  # ----------------------------------------------------------------------------
  # Blocklist response: Return 403 Forbidden (not 404, to not reveal app structure)
  # ----------------------------------------------------------------------------
  self.blocklisted_responder = lambda do |request|
    [
      403,
      { "Content-Type" => "text/plain" },
      [ "Forbidden" ]
    ]
  end

  # ----------------------------------------------------------------------------
  # Logging (for monitoring throttled and blocked requests)
  # ----------------------------------------------------------------------------
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn("[Rack::Attack] Throttled #{req.ip} for #{req.path}")
  end

  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn("[Rack::Attack] Blocked #{req.ip} for #{req.path} (#{payload[:match_type]})")
  end

  # Limit route lookups to 30 per minute per IP — a cache miss is an outbound
  # call to the routing engine on our API key, and the key rounds coordinates to
  # ~110 m, so an unthrottled caller can force misses indefinitely
  throttle("map-route/ip", limit: 30, period: 1.minute) do |req|
    if req.path == "/route"
      req.ip
    end
  end
end
