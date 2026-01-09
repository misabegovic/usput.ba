# frozen_string_literal: true

# Service for interacting with Flickr API to fetch Creative Commons licensed photos
# for locations based on coordinates and search terms.
#
# Usage:
#   service = FlickrService.new
#   photos = service.search_photos(lat: 43.8563, lng: 18.4131, text: "Sarajevo cafe")
#   service.download_and_attach_photos(location, photos, max: 5)
#
class FlickrService
  class ApiError < StandardError; end
  class ConfigurationError < StandardError; end
  class DownloadError < StandardError; end

  BASE_URL = "https://www.flickr.com/services/rest/"

  def initialize
    @api_key = Rails.application.config.flickr.api_key
    raise ConfigurationError, "FLICKR_API_KEY is not configured" if @api_key.blank?

    @connection = Faraday.new(url: BASE_URL) do |faraday|
      faraday.request :url_encoded
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = 30
      faraday.options.open_timeout = 10
    end
  end

  # Search for photos near a location
  #
  # @param lat [Float] Latitude
  # @param lng [Float] Longitude
  # @param text [String, nil] Search text (location name, description)
  # @param radius [Integer] Search radius in km (default: 5)
  # @param per_page [Integer] Number of results (default: 10)
  # @return [Array<Hash>] Array of photo data with URLs and attribution
  def search_photos(lat:, lng:, text: nil, radius: nil, per_page: 10)
    radius ||= config.default_radius

    params = {
      method: "flickr.photos.search",
      api_key: @api_key,
      lat: lat,
      lon: lng,
      radius: radius,
      radius_units: "km",
      license: config.allowed_licenses,
      content_type: 1, # Photos only
      media: "photos",
      per_page: per_page,
      sort: "relevance",
      extras: "url_l,url_c,url_z,url_m,owner_name,license,geo,description",
      format: "json",
      nojsoncallback: 1
    }

    # Add text search if provided
    params[:text] = text if text.present?

    response = @connection.get("", params)
    handle_response(response)
  end

  # Search photos with multiple strategies to maximize results
  #
  # @param location [Location] The location to search photos for
  # @param max_results [Integer] Maximum photos to return
  # @return [Array<Hash>] Combined unique photos from all strategies
  def search_photos_for_location(location, max_results: 10)
    return [] unless location.geocoded?

    all_photos = []

    # Strategy 1: Search by coordinates + location name
    if location.name.present?
      photos = search_photos(
        lat: location.lat,
        lng: location.lng,
        text: location.name,
        per_page: max_results
      )
      all_photos.concat(photos)
    end

    # Strategy 2: Search by coordinates + city (if we don't have enough)
    if all_photos.size < max_results && location.city.present?
      search_term = build_search_term(location)
      photos = search_photos(
        lat: location.lat,
        lng: location.lng,
        text: search_term,
        per_page: max_results
      )
      all_photos.concat(photos)
    end

    # Strategy 3: Search by coordinates only (wider net)
    if all_photos.size < max_results
      photos = search_photos(
        lat: location.lat,
        lng: location.lng,
        radius: 2, # Smaller radius without text
        per_page: max_results
      )
      all_photos.concat(photos)
    end

    # Remove duplicates by photo ID and limit results
    all_photos.uniq { |p| p[:id] }.first(max_results)
  end

  # Download photos and attach them to a location
  #
  # @param location [Location] The location to attach photos to
  # @param photos [Array<Hash>] Photos from search_photos
  # @param max [Integer] Maximum photos to attach
  # @return [Hash] Result with :attached count and :errors array
  def download_and_attach_photos(location, photos, max: 5)
    result = { attached: 0, errors: [], skipped: 0 }

    photos.first(max).each do |photo|
      begin
        url = extract_photo_url(photo)
        next unless url

        if download_and_attach_photo(location, url, photo)
          result[:attached] += 1
          Rails.logger.info("[FlickrService] Attached photo #{photo[:id]} to location #{location.id}")
        else
          result[:skipped] += 1
        end
      rescue DownloadError => e
        result[:errors] << { photo_id: photo[:id], error: e.message }
        Rails.logger.warn("[FlickrService] Failed to download photo #{photo[:id]}: #{e.message}")
      rescue StandardError => e
        result[:errors] << { photo_id: photo[:id], error: e.message }
        Rails.logger.error("[FlickrService] Error attaching photo #{photo[:id]}: #{e.message}")
      end
    end

    result
  end

  private

  def config
    Rails.application.config.flickr
  end

  def handle_response(response)
    unless response.success?
      raise ApiError, "Flickr API request failed with status #{response.status}"
    end

    data = response.body

    if data["stat"] == "fail"
      raise ApiError, "Flickr API error: #{data['message']} (code: #{data['code']})"
    end

    parse_photos(data.dig("photos", "photo") || [])
  end

  def parse_photos(photos)
    photos.map do |photo|
      {
        id: photo["id"],
        title: photo["title"],
        description: photo.dig("description", "_content"),
        owner_name: photo["ownername"],
        owner_id: photo["owner"],
        license: photo["license"],
        lat: photo["latitude"],
        lng: photo["longitude"],
        url_l: photo["url_l"],
        url_c: photo["url_c"],
        url_z: photo["url_z"],
        url_m: photo["url_m"],
        flickr_url: "https://www.flickr.com/photos/#{photo['owner']}/#{photo['id']}"
      }
    end
  end

  def extract_photo_url(photo)
    config.fallback_sizes.each do |size_key|
      url = photo[size_key.to_sym]
      return url if url.present?
    end
    nil
  end

  def build_search_term(location)
    terms = []

    # Add category-based keywords
    if location.respond_to?(:primary_category) && location.primary_category
      category_keywords = category_to_keywords(location.primary_category.key)
      terms << category_keywords if category_keywords
    end

    # Add city
    terms << location.city if location.city.present?

    terms.compact.join(" ")
  end

  def category_to_keywords(category_key)
    keywords = {
      "restaurant" => "restaurant food dining",
      "cafe" => "cafe coffee",
      "bar" => "bar nightlife",
      "museum" => "museum art culture",
      "park" => "park nature green",
      "hotel" => "hotel accommodation",
      "monument" => "monument landmark",
      "church" => "church architecture",
      "mosque" => "mosque architecture",
      "market" => "market bazaar shopping"
    }
    keywords[category_key]
  end

  def download_and_attach_photo(location, url, photo_data)
    # Build attribution filename
    filename = build_filename(photo_data)

    # Download the image
    image_data = download_image(url)
    return false unless image_data

    content_type = detect_content_type(url, image_data)

    # Attach to location
    location.photos.attach(
      io: StringIO.new(image_data),
      filename: filename,
      content_type: content_type,
      metadata: {
        flickr_id: photo_data[:id],
        flickr_url: photo_data[:flickr_url],
        owner_name: photo_data[:owner_name],
        license: photo_data[:license],
        source: "flickr"
      }
    )

    true
  end

  def build_filename(photo_data)
    safe_title = (photo_data[:title] || "photo").to_s
                   .gsub(/[^a-zA-Z0-9\-_]/, "_")
                   .truncate(50, omission: "")

    "flickr_#{photo_data[:id]}_#{safe_title}.jpg"
  end

  def download_image(url, redirect_count = 0)
    raise DownloadError, "Too many redirects" if redirect_count > 5

    download_connection = Faraday.new do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = config.download_timeout
      faraday.options.open_timeout = 5
    end

    response = download_connection.get(url)

    # Handle redirects manually
    if response.status.in?([ 301, 302, 303, 307, 308 ])
      redirect_url = response.headers["location"]
      return download_image(redirect_url, redirect_count + 1) if redirect_url.present?
    end

    unless response.success?
      raise DownloadError, "Failed to download image: HTTP #{response.status}"
    end

    if response.body.bytesize > config.max_file_size
      raise DownloadError, "Image too large: #{response.body.bytesize} bytes"
    end

    unless valid_image_content_type?(response.headers["content-type"])
      raise DownloadError, "Invalid content type: #{response.headers['content-type']}"
    end

    response.body
  end

  def valid_image_content_type?(content_type)
    return false if content_type.blank?

    content_type.start_with?("image/")
  end

  def detect_content_type(url, _image_data)
    case url.downcase
    when /\.png/ then "image/png"
    when /\.gif/ then "image/gif"
    when /\.webp/ then "image/webp"
    else "image/jpeg"
    end
  end
end
