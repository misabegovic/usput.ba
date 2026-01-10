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

  # ----------------------------------------------------------------------------
  # Throttle: Login/Authentication endpoints (stricter)
  # ----------------------------------------------------------------------------
  # Limit login attempts to 5 per 20 seconds per IP
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/session" && req.post?
      req.ip
    end
  end

  # Limit login attempts to 5 per minute per email
  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/session" && req.post?
      # Normalize email to prevent case-based bypass
      req.params.dig("session", "email")&.downcase&.strip
    end
  end

  # ----------------------------------------------------------------------------
  # Throttle: Registration endpoint
  # ----------------------------------------------------------------------------
  # Limit signup attempts to 3 per minute per IP
  throttle("signups/ip", limit: 3, period: 1.minute) do |req|
    if req.path == "/users" && req.post?
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # Throttle: Password reset requests
  # ----------------------------------------------------------------------------
  # Limit password reset requests to 3 per 15 minutes per IP
  throttle("password_reset/ip", limit: 3, period: 15.minutes) do |req|
    if req.path == "/password_resets" && req.post?
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # Throttle: API endpoints (if any)
  # ----------------------------------------------------------------------------
  # Limit API requests to 60 per minute per IP
  throttle("api/ip", limit: 60, period: 1.minute) do |req|
    if req.path.start_with?("/api/")
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # Throttle: Admin endpoints
  # ----------------------------------------------------------------------------
  # Limit admin requests to 100 per minute per IP
  throttle("admin/ip", limit: 100, period: 1.minute) do |req|
    if req.path.start_with?("/admin")
      req.ip
    end
  end

  # ----------------------------------------------------------------------------
  # Throttle: AI generation status polling
  # ----------------------------------------------------------------------------
  # Limit status checks to 30 per minute (allows 2 second polling interval)
  throttle("ai_status/ip", limit: 30, period: 1.minute) do |req|
    if req.path == "/admin/ai/status"
      req.ip
    end
  end

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
  # Limit search requests to 30 per minute per IP
  throttle("search/ip", limit: 30, period: 1.minute) do |req|
    if req.path.include?("/search") || req.path.include?("/cities")
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
      [{ error: "Rate limit exceeded. Retry in #{retry_after} seconds." }.to_json]
    ]
  end

  # ----------------------------------------------------------------------------
  # Blocklist response: Return 403 Forbidden (not 404, to not reveal app structure)
  # ----------------------------------------------------------------------------
  self.blocklisted_responder = lambda do |request|
    [
      403,
      { "Content-Type" => "text/plain" },
      ["Forbidden"]
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
end
