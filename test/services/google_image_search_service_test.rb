# frozen_string_literal: true

require "test_helper"

class GoogleImageSearchServiceTest < ActiveSupport::TestCase
  # === Configuration tests ===

  test "raises ConfigurationError when GOOGLE_API_KEY is not set" do
    with_env("GOOGLE_API_KEY" => nil, "SEARCH_ENGINE_CX" => "test_cx") do
      assert_raises(GoogleImageSearchService::ConfigurationError) do
        GoogleImageSearchService.new
      end
    end
  end

  test "raises ConfigurationError when GOOGLE_API_KEY is blank" do
    with_env("GOOGLE_API_KEY" => "", "SEARCH_ENGINE_CX" => "test_cx") do
      assert_raises(GoogleImageSearchService::ConfigurationError) do
        GoogleImageSearchService.new
      end
    end
  end

  test "raises ConfigurationError when SEARCH_ENGINE_CX is not set" do
    with_env("GOOGLE_API_KEY" => "test_key", "SEARCH_ENGINE_CX" => nil) do
      assert_raises(GoogleImageSearchService::ConfigurationError) do
        GoogleImageSearchService.new
      end
    end
  end

  test "raises ConfigurationError when SEARCH_ENGINE_CX is blank" do
    with_env("GOOGLE_API_KEY" => "test_key", "SEARCH_ENGINE_CX" => "") do
      assert_raises(GoogleImageSearchService::ConfigurationError) do
        GoogleImageSearchService.new
      end
    end
  end

  test "initializes successfully with valid configuration" do
    with_env("GOOGLE_API_KEY" => "test_key", "SEARCH_ENGINE_CX" => "test_cx") do
      service = GoogleImageSearchService.new
      assert_instance_of GoogleImageSearchService, service
    end
  end

  # === search method tests ===

  test "search returns array of parsed image results" do
    mock_response = mock_api_response([
      { link: "https://example.com/image1.jpg", title: "Test Image 1" },
      { link: "https://example.com/image2.jpg", title: "Test Image 2" }
    ])

    service = build_service_with_stubbed_connection(mock_response, status: 200)

    results = service.search("Baščaršija Sarajevo")

    assert_kind_of Array, results
    assert_equal 2, results.count
    assert_equal "https://example.com/image1.jpg", results.first[:url]
    assert_equal "Test Image 1", results.first[:title]
  end

  test "search returns empty array when no items in response" do
    mock_response = { "items" => nil }
    service = build_service_with_stubbed_connection(mock_response, status: 200)

    results = service.search("nonexistent query")

    assert_equal [], results
  end

  test "search raises ArgumentError when query is blank" do
    service = build_service

    assert_raises(ArgumentError, "Query cannot be blank") do
      service.search("")
    end

    assert_raises(ArgumentError, "Query cannot be blank") do
      service.search(nil)
    end
  end

  test "search parses all image fields correctly" do
    mock_response = mock_api_response([
      {
        link: "https://example.com/full.jpg",
        title: "Full Image",
        snippet: "A beautiful image",
        mime: "image/jpeg",
        image: {
          thumbnailLink: "https://example.com/thumb.jpg",
          thumbnailWidth: 150,
          thumbnailHeight: 100,
          width: 1920,
          height: 1080,
          contextLink: "https://example.com/page"
        }
      }
    ])

    service = build_service_with_stubbed_connection(mock_response, status: 200)

    results = service.search("test query")

    result = results.first
    assert_equal "https://example.com/full.jpg", result[:url]
    assert_equal "Full Image", result[:title]
    assert_equal "A beautiful image", result[:snippet]
    assert_equal "https://example.com/thumb.jpg", result[:thumbnail]
    assert_equal 150, result[:thumbnail_width]
    assert_equal 100, result[:thumbnail_height]
    assert_equal 1920, result[:width]
    assert_equal 1080, result[:height]
    assert_equal "https://example.com/page", result[:source]
    assert_equal "image/jpeg", result[:mime_type]
  end

  test "search respects num parameter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", num: 3)

    assert_equal 3, params_captured[:num]
  end

  test "search caps num parameter at 10" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", num: 20)

    assert_equal 10, params_captured[:num]
  end

  test "search includes img_size parameter when valid" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", img_size: "huge")

    assert_equal "huge", params_captured[:imgSize]
  end

  test "search excludes invalid img_size parameter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", img_size: "invalid_size")

    assert_nil params_captured[:imgSize]
  end

  test "search includes img_type parameter when valid" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", img_type: "photo")

    assert_equal "photo", params_captured[:imgType]
  end

  test "search excludes invalid img_type parameter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", img_type: "invalid_type")

    assert_nil params_captured[:imgType]
  end

  test "search includes rights parameter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", rights: "cc_publicdomain")

    assert_equal "cc_publicdomain", params_captured[:rights]
  end

  test "search includes safe parameter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test", safe: "off")

    assert_equal "off", params_captured[:safe]
  end

  test "search uses default parameters" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("test")

    assert_equal 5, params_captured[:num]
    assert_equal "large", params_captured[:imgSize]
    assert_equal "active", params_captured[:safe]
    assert_equal "image", params_captured[:searchType]
  end

  # === search_creative_commons tests ===

  test "search_creative_commons includes CC rights filter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search_creative_commons("test query")

    assert_equal "cc_publicdomain,cc_attribute,cc_sharealike,cc_noncommercial", params_captured[:rights]
  end

  test "search_creative_commons respects num parameter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search_creative_commons("test query", num: 3)

    assert_equal 3, params_captured[:num]
  end

  # === search_location tests ===

  test "search_location appends Bosnia Herzegovina to query" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search_location("Stari Most")

    assert_equal "Stari Most Bosnia Herzegovina", params_captured[:q]
  end

  test "search_location includes city in query" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search_location("Stari Most", city: "Mostar")

    assert_equal "Stari Most Mostar Bosnia Herzegovina", params_captured[:q]
  end

  test "search_location uses photo img_type by default" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search_location("Stari Most")

    assert_equal "photo", params_captured[:imgType]
  end

  test "search_location uses CC filter when creative_commons_only is true" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search_location("Stari Most", creative_commons_only: true)

    assert_equal "cc_publicdomain,cc_attribute,cc_sharealike,cc_noncommercial", params_captured[:rights]
  end

  test "search_location respects num parameter" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search_location("Stari Most", num: 8)

    assert_equal 8, params_captured[:num]
  end

  # === quota_status tests ===

  test "quota_status returns available true when API responds with 200" do
    service = build_service_with_stubbed_connection({ "items" => [] }, status: 200)

    result = service.quota_status

    assert_equal true, result[:available]
    assert_equal "API available", result[:message]
  end

  test "quota_status returns available false when API responds with 429" do
    service = build_service_with_stubbed_connection({}, status: 429)

    result = service.quota_status

    assert_equal false, result[:available]
    assert_equal "Quota exceeded", result[:message]
  end

  test "quota_status returns available false on other error status" do
    service = build_service_with_stubbed_connection({}, status: 500)

    result = service.quota_status

    assert_equal false, result[:available]
    assert_equal "API error: 500", result[:message]
  end

  test "quota_status handles connection errors" do
    service = build_service

    mock_connection = Object.new
    mock_connection.define_singleton_method(:get) do |_path, _params|
      raise Faraday::ConnectionFailed, "Connection refused"
    end
    service.instance_variable_set(:@connection, mock_connection)

    result = service.quota_status

    assert_equal false, result[:available]
    assert_includes result[:message], "Connection error"
  end

  # === Error handling tests ===

  test "raises ApiError on 400 bad request" do
    mock_response = {
      "error" => {
        "message" => "Invalid value for parameter"
      }
    }
    service = build_service_with_stubbed_connection(mock_response, status: 400)

    error = assert_raises(GoogleImageSearchService::ApiError) do
      service.search("test")
    end

    assert_includes error.message, "Bad request"
    assert_includes error.message, "Invalid value for parameter"
  end

  test "raises QuotaExceededError on 403 with quota message" do
    mock_response = {
      "error" => {
        "message" => "Daily quota for Unauthenticated Use Exceeded. Continued use requires signup."
      }
    }
    service = build_service_with_stubbed_connection(mock_response, status: 403)

    error = assert_raises(GoogleImageSearchService::QuotaExceededError) do
      service.search("test")
    end

    assert_includes error.message, "Daily quota exceeded"
  end

  test "raises QuotaExceededError on 403 with limit message" do
    mock_response = {
      "error" => {
        "message" => "User Rate limit Exceeded"
      }
    }
    service = build_service_with_stubbed_connection(mock_response, status: 403)

    error = assert_raises(GoogleImageSearchService::QuotaExceededError) do
      service.search("test")
    end

    assert_includes error.message, "Daily quota exceeded"
  end

  test "raises ApiError on 403 without quota message" do
    mock_response = {
      "error" => {
        "message" => "API key not valid"
      }
    }
    service = build_service_with_stubbed_connection(mock_response, status: 403)

    error = assert_raises(GoogleImageSearchService::ApiError) do
      service.search("test")
    end

    assert_includes error.message, "Access denied"
    assert_includes error.message, "API key not valid"
  end

  test "raises QuotaExceededError on 429 rate limit" do
    service = build_service_with_stubbed_connection({}, status: 429)

    error = assert_raises(GoogleImageSearchService::QuotaExceededError) do
      service.search("test")
    end

    assert_includes error.message, "Rate limited"
  end

  test "raises ApiError on unexpected status codes" do
    mock_response = {
      "error" => {
        "message" => "Internal server error"
      }
    }
    service = build_service_with_stubbed_connection(mock_response, status: 500)

    error = assert_raises(GoogleImageSearchService::ApiError) do
      service.search("test")
    end

    assert_includes error.message, "API error (500)"
    assert_includes error.message, "Internal server error"
  end

  test "handles error response without proper structure" do
    mock_response = "Something went wrong"
    service = build_service_with_stubbed_connection(mock_response, status: 500)

    error = assert_raises(GoogleImageSearchService::ApiError) do
      service.search("test")
    end

    assert_includes error.message, "Unknown error"
  end

  test "handles error response with nested error message" do
    mock_response = {
      "error" => {
        "message" => "Detailed error message from API"
      }
    }
    service = build_service_with_stubbed_connection(mock_response, status: 400)

    error = assert_raises(GoogleImageSearchService::ApiError) do
      service.search("test")
    end

    assert_includes error.message, "Detailed error message from API"
  end

  # === Constants tests ===

  test "IMAGE_SIZES contains valid sizes" do
    assert_equal %w[huge large medium small icon], GoogleImageSearchService::IMAGE_SIZES
  end

  test "IMAGE_TYPES contains valid types" do
    assert_equal %w[clipart face lineart stock photo], GoogleImageSearchService::IMAGE_TYPES
  end

  test "default constants are set correctly" do
    assert_equal 5, GoogleImageSearchService::DEFAULT_NUM_RESULTS
    assert_equal "large", GoogleImageSearchService::DEFAULT_IMAGE_SIZE
    assert_equal "active", GoogleImageSearchService::DEFAULT_SAFE_SEARCH
  end

  test "API_URL is correct" do
    assert_equal "https://www.googleapis.com/customsearch/v1", GoogleImageSearchService::API_URL
  end

  # === Edge cases ===

  test "search handles empty items array" do
    mock_response = { "items" => [] }
    service = build_service_with_stubbed_connection(mock_response, status: 200)

    results = service.search("test")

    assert_equal [], results
  end

  test "search handles image with missing nested fields" do
    mock_response = mock_api_response([
      {
        link: "https://example.com/image.jpg",
        title: "Image without nested data"
        # No image, snippet, or mime fields
      }
    ])

    service = build_service_with_stubbed_connection(mock_response, status: 200)

    results = service.search("test")

    result = results.first
    assert_equal "https://example.com/image.jpg", result[:url]
    assert_equal "Image without nested data", result[:title]
    assert_nil result[:thumbnail]
    assert_nil result[:thumbnail_width]
    assert_nil result[:thumbnail_height]
    assert_nil result[:width]
    assert_nil result[:height]
    assert_nil result[:source]
    assert_nil result[:mime_type]
    assert_nil result[:snippet]
  end

  test "search handles Unicode characters in query" do
    service = build_service
    params_captured = nil

    mock_connection = build_mock_connection(status: 200, body: { "items" => [] }) do |params|
      params_captured = params
    end
    service.instance_variable_set(:@connection, mock_connection)

    service.search("Baščaršija Sarajevo")

    assert_equal "Baščaršija Sarajevo", params_captured[:q]
  end

  test "QuotaExceededError inherits from ApiError" do
    assert GoogleImageSearchService::QuotaExceededError < GoogleImageSearchService::ApiError
  end

  private

  def with_env(env_vars)
    original_values = {}
    env_vars.each do |key, value|
      original_values[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    original_values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  def build_service
    with_env("GOOGLE_API_KEY" => "test_api_key", "SEARCH_ENGINE_CX" => "test_search_cx") do
      return GoogleImageSearchService.new
    end
  end

  def build_service_with_stubbed_connection(mock_body, status:)
    with_env("GOOGLE_API_KEY" => "test_api_key", "SEARCH_ENGINE_CX" => "test_search_cx") do
      service = GoogleImageSearchService.new

      mock_response = Object.new
      mock_response.define_singleton_method(:status) { status }
      mock_response.define_singleton_method(:body) { mock_body }

      mock_connection = Object.new
      mock_connection.define_singleton_method(:get) do |_path, _params|
        mock_response
      end

      service.instance_variable_set(:@connection, mock_connection)
      return service
    end
  end

  def build_mock_connection(status:, body:, &block)
    mock_response = Object.new
    mock_response.define_singleton_method(:status) { status }
    mock_response.define_singleton_method(:body) { body }

    mock_connection = Object.new
    mock_connection.define_singleton_method(:get) do |_path, params|
      block.call(params) if block
      mock_response
    end

    mock_connection
  end

  def mock_api_response(items)
    parsed_items = items.map do |item|
      result = {
        "link" => item[:link],
        "title" => item[:title]
      }

      result["snippet"] = item[:snippet] if item[:snippet]
      result["mime"] = item[:mime] if item[:mime]

      if item[:image]
        result["image"] = {
          "thumbnailLink" => item[:image][:thumbnailLink],
          "thumbnailWidth" => item[:image][:thumbnailWidth],
          "thumbnailHeight" => item[:image][:thumbnailHeight],
          "width" => item[:image][:width],
          "height" => item[:image][:height],
          "contextLink" => item[:image][:contextLink]
        }
      end

      result
    end

    { "items" => parsed_items }
  end
end
