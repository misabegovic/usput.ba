# frozen_string_literal: true

Rails.application.config.flickr = ActiveSupport::OrderedOptions.new
Rails.application.config.flickr.api_key = ENV.fetch("FLICKR_API_KEY", nil)

# API settings
Rails.application.config.flickr.base_url = "https://www.flickr.com/services/rest/"

# Search defaults
Rails.application.config.flickr.default_radius = 5 # km
Rails.application.config.flickr.max_photos_per_location = 5

# Only fetch Creative Commons licensed photos
# License IDs: 1=CC BY-NC-SA, 2=CC BY-NC, 3=CC BY-NC-ND, 4=CC BY, 5=CC BY-SA, 6=CC BY-ND
# We use 4,5,6 which allow commercial use
Rails.application.config.flickr.allowed_licenses = "4,5,6"

# Photo size to download (url_l = large 1024, url_o = original)
Rails.application.config.flickr.preferred_size = "url_l"
Rails.application.config.flickr.fallback_sizes = %w[url_l url_c url_z url_m].freeze

# Download settings
Rails.application.config.flickr.download_timeout = 15 # seconds
Rails.application.config.flickr.max_file_size = 10.megabytes
