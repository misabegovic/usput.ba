# frozen_string_literal: true

# Service for fetching images from Wikimedia Commons API
# Uses the MediaWiki API to search for images related to locations in Bosnia & Herzegovina
#
# Documentation: https://www.mediawiki.org/wiki/API:Main_page
# Commons API: https://commons.wikimedia.org/w/api.php
#
# Example usage:
#   service = WikimediaService.new
#   results = service.search_images("Stari Most Mostar")
#   # => [{ title: "File:...", url: "https://...", thumb_url: "https://...", description: "..." }, ...]
#
class WikimediaService
  class Error < StandardError; end
  class RateLimitError < Error; end
  class ApiError < Error; end

  # Wikimedia Commons API endpoint
  API_ENDPOINT = "https://commons.wikimedia.org/w/api.php"

  # Rate limiting: Wikimedia requests max 200 requests/minute for unauthenticated
  # We'll be conservative with 1 request per second
  RATE_LIMIT_SLEEP = 1.0

  # Default search parameters
  DEFAULT_LIMIT = 10
  MAX_LIMIT = 50

  # Preferred image extensions (prioritize these)
  PREFERRED_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze

  # Minimum image dimensions (skip tiny images)
  MIN_WIDTH = 400
  MIN_HEIGHT = 300

  def initialize
    @last_request_time = nil
  end

  # Search for images related to a location
  # @param query [String] Search query (location name, city, etc.)
  # @param limit [Integer] Maximum number of results (default: 10, max: 50)
  # @return [Array<Hash>] Array of image results with :title, :url, :thumb_url, :description, :width, :height
  def search_images(query, limit: DEFAULT_LIMIT)
    limit = [limit, MAX_LIMIT].min

    # First, search for files matching the query
    search_results = search_files(query, limit: limit * 2) # Get more to filter later
    return [] if search_results.empty?

    # Get detailed info for each file
    images = []
    search_results.each do |result|
      break if images.length >= limit

      image_info = get_image_info(result[:title])
      next unless image_info && valid_image?(image_info)

      images << image_info
    end

    images
  end

  # Search for images by geographic coordinates (geosearch)
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @param radius [Integer] Search radius in meters (default: 1000, max: 10000)
  # @param limit [Integer] Maximum number of results
  # @return [Array<Hash>] Array of image results
  def search_by_coordinates(lat, lng, radius: 1000, limit: DEFAULT_LIMIT)
    return [] if lat.blank? || lng.blank?

    limit = [limit, MAX_LIMIT].min
    radius = [radius, 10_000].min

    rate_limit!

    params = {
      action: "query",
      format: "json",
      generator: "geosearch",
      ggscoord: "#{lat}|#{lng}",
      ggsradius: radius,
      ggslimit: limit * 2,
      ggsnamespace: 6, # File namespace
      prop: "imageinfo",
      iiprop: "url|size|extmetadata",
      iiurlwidth: 800 # Get thumbnail URL
    }

    response = make_request(params)
    pages = response.dig("query", "pages") || {}

    images = []
    pages.each_value do |page|
      next unless page["imageinfo"]&.any?

      image_info = parse_image_info(page)
      next unless image_info && valid_image?(image_info)

      images << image_info
      break if images.length >= limit
    end

    images
  end

  # Get detailed information about a specific image
  # @param title [String] Image title (including "File:" prefix)
  # @return [Hash, nil] Image info or nil if not found
  def get_image_info(title)
    rate_limit!

    params = {
      action: "query",
      format: "json",
      titles: title,
      prop: "imageinfo",
      iiprop: "url|size|extmetadata|mime",
      iiurlwidth: 1200 # Larger thumbnail for preview
    }

    response = make_request(params)
    pages = response.dig("query", "pages") || {}

    page = pages.values.first
    return nil unless page && page["imageinfo"]&.any?

    parse_image_info(page)
  end

  # Download image from URL and return IO object
  # @param url [String] Image URL
  # @param timeout [Integer] Download timeout in seconds
  # @return [IO, nil] IO object with image data or nil on failure
  def download_image(url, timeout: 30)
    return nil if url.blank?

    URI.parse(url).open(
      read_timeout: timeout,
      open_timeout: 10,
      "User-Agent" => user_agent
    )
  rescue OpenURI::HTTPError, SocketError, Timeout::Error => e
    Rails.logger.warn "[WikimediaService] Failed to download image from #{url}: #{e.message}"
    nil
  end

  private

  # Search for files using the search API
  def search_files(query, limit:)
    rate_limit!

    # Add Bosnia/Herzegovina context to improve relevance
    enhanced_query = "#{query} Bosnia Herzegovina"

    params = {
      action: "query",
      format: "json",
      list: "search",
      srsearch: enhanced_query,
      srnamespace: 6, # File namespace only
      srlimit: limit,
      srprop: "snippet|titlesnippet"
    }

    response = make_request(params)
    search_results = response.dig("query", "search") || []

    search_results.map do |result|
      {
        title: result["title"],
        snippet: result["snippet"]
      }
    end
  end

  # Parse image info from API response page
  def parse_image_info(page)
    info = page["imageinfo"]&.first
    return nil unless info

    metadata = info["extmetadata"] || {}

    {
      title: page["title"],
      url: info["url"],
      thumb_url: info["thumburl"] || info["url"],
      description: extract_description(metadata),
      license: extract_license(metadata),
      author: extract_author(metadata),
      width: info["width"],
      height: info["height"],
      mime: info["mime"],
      page_url: "https://commons.wikimedia.org/wiki/#{CGI.escape(page['title'].to_s.tr(' ', '_'))}"
    }
  end

  # Extract description from metadata
  def extract_description(metadata)
    desc = metadata.dig("ImageDescription", "value")
    return nil if desc.blank?

    # Strip HTML tags
    ActionController::Base.helpers.strip_tags(desc).truncate(500)
  end

  # Extract license info from metadata
  def extract_license(metadata)
    metadata.dig("LicenseShortName", "value") ||
      metadata.dig("License", "value") ||
      "Unknown"
  end

  # Extract author from metadata
  def extract_author(metadata)
    author = metadata.dig("Artist", "value")
    return nil if author.blank?

    ActionController::Base.helpers.strip_tags(author).truncate(200)
  end

  # Check if image meets quality requirements
  def valid_image?(image)
    return false unless image[:url].present?
    return false unless image[:width].to_i >= MIN_WIDTH
    return false unless image[:height].to_i >= MIN_HEIGHT

    # Check for preferred extensions
    extension = File.extname(image[:url]).downcase
    return false unless PREFERRED_EXTENSIONS.include?(extension) || image[:mime]&.start_with?("image/")

    # Skip SVG and other non-photo formats
    return false if image[:mime] == "image/svg+xml"

    true
  end

  # Make HTTP request to API
  def make_request(params)
    uri = URI(API_ENDPOINT)
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = user_agent

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError, "Wikimedia API returned #{response.code}: #{response.body}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise ApiError, "Failed to parse Wikimedia API response: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise ApiError, "Wikimedia API timeout: #{e.message}"
  end

  # Enforce rate limiting
  def rate_limit!
    if @last_request_time
      elapsed = Time.current - @last_request_time
      if elapsed < RATE_LIMIT_SLEEP
        sleep(RATE_LIMIT_SLEEP - elapsed)
      end
    end
    @last_request_time = Time.current
  end

  # User agent for API requests (required by Wikimedia)
  def user_agent
    "UsputBaBot/1.0 (https://usput.ba; contact@usput.ba) Ruby/#{RUBY_VERSION}"
  end
end
