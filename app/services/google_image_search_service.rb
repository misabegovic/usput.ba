# frozen_string_literal: true

# Service for searching images using Google Custom Search API
#
# Google Custom Search provides web-wide image search with various filters.
# Free tier: 100 queries/day, then $5/1000 queries.
#
# Usage:
#   service = GoogleImageSearchService.new
#   results = service.search("Baščaršija Sarajevo")
#   # => [{ url: "...", title: "...", thumbnail: "...", source: "..." }, ...]
#
# With rights filter (Creative Commons):
#   results = service.search("Stari Most Mostar", rights: "cc_publicdomain,cc_attribute")
#
class GoogleImageSearchService
  class ConfigurationError < StandardError; end
  class ApiError < StandardError; end
  class QuotaExceededError < ApiError; end

  API_URL = "https://www.googleapis.com/customsearch/v1"

  # Valid image sizes for Google Custom Search
  IMAGE_SIZES = %w[huge large medium small icon].freeze

  # Valid image types
  IMAGE_TYPES = %w[clipart face lineart stock photo].freeze

  # Default search parameters
  DEFAULT_NUM_RESULTS = 5
  DEFAULT_IMAGE_SIZE = "large"
  DEFAULT_SAFE_SEARCH = "active"

  def initialize
    @api_key = ENV.fetch("GOOGLE_API_KEY", nil)
    @search_engine_id = ENV.fetch("SEARCH_ENGINE_CX", nil)

    validate_configuration!

    @connection = Faraday.new(url: API_URL) do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = 30
      faraday.options.open_timeout = 10
    end
  end

  # Search for images
  #
  # @param query [String] Search query (e.g., "Baščaršija Sarajevo")
  # @param num [Integer] Number of results (1-10, default 5)
  # @param img_size [String] Image size filter (huge, large, medium, small, icon)
  # @param img_type [String] Image type filter (clipart, face, lineart, stock, photo)
  # @param rights [String] Usage rights filter (e.g., "cc_publicdomain,cc_attribute,cc_sharealike")
  # @param safe [String] Safe search level (active, moderate, off)
  # @return [Array<Hash>] Array of image results
  #
  def search(query, num: DEFAULT_NUM_RESULTS, img_size: DEFAULT_IMAGE_SIZE, img_type: nil, rights: nil, safe: DEFAULT_SAFE_SEARCH)
    raise ArgumentError, "Query cannot be blank" if query.blank?

    params = build_params(query, num: num, img_size: img_size, img_type: img_type, rights: rights, safe: safe)

    response = @connection.get("", params)
    handle_response(response)
  end

  # Search for images with Creative Commons license only
  # This returns images that can be legally used and stored
  #
  # @param query [String] Search query
  # @param num [Integer] Number of results
  # @return [Array<Hash>] Array of CC-licensed image results
  #
  def search_creative_commons(query, num: DEFAULT_NUM_RESULTS)
    search(
      query,
      num: num,
      rights: "cc_publicdomain,cc_attribute,cc_sharealike,cc_noncommercial"
    )
  end

  # Search for location images specifically
  # Adds "Bosnia Herzegovina" to improve relevance for local places
  #
  # @param location_name [String] Name of the location
  # @param city [String] City name (optional)
  # @param num [Integer] Number of results
  # @param creative_commons_only [Boolean] Whether to filter by CC license
  # @return [Array<Hash>] Array of image results
  #
  def search_location(location_name, city: nil, num: DEFAULT_NUM_RESULTS, creative_commons_only: false)
    query_parts = [location_name]
    query_parts << city if city.present?
    query_parts << "Bosnia Herzegovina"

    query = query_parts.join(" ")

    if creative_commons_only
      search_creative_commons(query, num: num)
    else
      search(query, num: num, img_type: "photo")
    end
  end

  # Check remaining quota (approximate based on response headers)
  # Note: Google doesn't provide exact quota info in headers
  #
  def quota_status
    # Make a minimal query to check if we're over quota
    response = @connection.get("", build_params("test", num: 1))

    if response.status == 429
      { available: false, message: "Quota exceeded" }
    elsif response.status == 200
      { available: true, message: "API available" }
    else
      { available: false, message: "API error: #{response.status}" }
    end
  rescue Faraday::Error => e
    { available: false, message: "Connection error: #{e.message}" }
  end

  private

  def validate_configuration!
    if @api_key.blank?
      raise ConfigurationError, "GOOGLE_API_KEY environment variable is not set"
    end

    if @search_engine_id.blank?
      raise ConfigurationError, "SEARCH_ENGINE_CX environment variable is not set"
    end
  end

  def build_params(query, num:, img_size: nil, img_type: nil, rights: nil, safe: nil)
    params = {
      key: @api_key,
      cx: @search_engine_id,
      q: query,
      searchType: "image",
      num: [num.to_i, 10].min  # Google max is 10 per request
    }

    params[:imgSize] = img_size if img_size.present? && IMAGE_SIZES.include?(img_size)
    params[:imgType] = img_type if img_type.present? && IMAGE_TYPES.include?(img_type)
    params[:rights] = rights if rights.present?
    params[:safe] = safe if safe.present?

    params
  end

  def handle_response(response)
    case response.status
    when 200
      parse_results(response.body)
    when 400
      error_message = extract_error_message(response.body)
      Rails.logger.error "[GoogleImageSearch] Bad request: #{error_message}"
      raise ApiError, "Bad request: #{error_message}"
    when 403
      error_message = extract_error_message(response.body)
      if error_message.include?("quota") || error_message.include?("limit")
        Rails.logger.warn "[GoogleImageSearch] Quota exceeded"
        raise QuotaExceededError, "Daily quota exceeded. Try again tomorrow or upgrade your plan."
      else
        Rails.logger.error "[GoogleImageSearch] Forbidden: #{error_message}"
        raise ApiError, "Access denied: #{error_message}"
      end
    when 429
      Rails.logger.warn "[GoogleImageSearch] Rate limited"
      raise QuotaExceededError, "Rate limited. Please wait before making more requests."
    else
      error_message = extract_error_message(response.body)
      Rails.logger.error "[GoogleImageSearch] API error (#{response.status}): #{error_message}"
      raise ApiError, "API error (#{response.status}): #{error_message}"
    end
  end

  def extract_error_message(body)
    return "Unknown error" unless body.is_a?(Hash)

    body.dig("error", "message") || body["error"] || "Unknown error"
  end

  def parse_results(body)
    items = body["items"] || []

    items.map do |item|
      {
        url: item["link"],
        title: item["title"],
        snippet: item["snippet"],
        thumbnail: item.dig("image", "thumbnailLink"),
        thumbnail_width: item.dig("image", "thumbnailWidth"),
        thumbnail_height: item.dig("image", "thumbnailHeight"),
        width: item.dig("image", "width"),
        height: item.dig("image", "height"),
        source: item.dig("image", "contextLink"),
        mime_type: item["mime"]
      }
    end
  end
end
