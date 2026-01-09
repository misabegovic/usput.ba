# frozen_string_literal: true

module Ai
  # Service for finding YouTube videos for locations using Perplexity AI web search
  #
  # Perplexity AI has built-in web search capabilities which makes it ideal for
  # finding relevant YouTube videos for tourism locations.
  #
  # Usage:
  #   finder = Ai::LocationVideoFinder.new
  #   result = finder.find_video_for(location)
  #   # => { video_url: "https://www.youtube.com/watch?v=...", title: "...", reason: "..." }
  #
  class LocationVideoFinder
    include Concerns::ErrorReporting

    class ConfigurationError < StandardError; end
    class SearchError < StandardError; end

    # Perplexity model with web search capabilities
    # sonar-pro is optimized for search with citations
    PERPLEXITY_MODEL = "sonar-pro"

    # Maximum attempts for finding a valid video
    MAX_SEARCH_ATTEMPTS = 2

    def initialize
      validate_configuration!
      @chat = RubyLLM.chat(model: PERPLEXITY_MODEL)
    end

    # Find a YouTube video for a location
    # @param location [Location] The location to find a video for
    # @return [Hash, nil] Hash with video_url, title, reason or nil if not found
    def find_video_for(location)
      return nil if location.nil?

      Rails.logger.info "[LocationVideoFinder] Searching video for: #{location.name} (#{location.city})"

      prompt = build_search_prompt(location)

      begin
        response = @chat.ask(prompt)
        result = parse_video_response(response, location)

        if result && valid_youtube_url?(result[:video_url])
          Rails.logger.info "[LocationVideoFinder] Found video for #{location.name}: #{result[:video_url]}"
          result
        else
          Rails.logger.warn "[LocationVideoFinder] No valid video found for #{location.name}"
          nil
        end
      rescue RubyLLM::Error => e
        Rails.logger.error "[LocationVideoFinder] Perplexity API error: #{e.message}"
        raise SearchError, "Failed to search for video: #{e.message}"
      end
    end

    # Update location with found video
    # @param location [Location] The location to update
    # @return [Boolean] Whether the update was successful
    def update_location_video(location)
      result = find_video_for(location)
      return false unless result

      location.update(video_url: result[:video_url])
    end

    private

    def validate_configuration!
      api_key = ENV.fetch("PERPLEXITY_API_KEY", nil)
      if api_key.blank?
        raise ConfigurationError, "PERPLEXITY_API_KEY environment variable is not set"
      end
    end

    def build_search_prompt(location)
      location_details = build_location_details(location)

      <<~PROMPT
        Find the BEST YouTube video showcasing "#{location.name}" in #{location.city}, Bosnia and Herzegovina.

        #{location_details}

        SEARCH REQUIREMENTS:
        1. Search YouTube for videos about this specific location
        2. Prioritize videos that are:
           - High quality (HD/4K if available)
           - Beautiful cinematic/drone footage
           - Recent (within last 3-5 years preferred)
           - In Bosnian, English, or other languages (visuals matter more than language)
           - From reputable travel channels or official tourism accounts
        3. Avoid videos that are:
           - Poor quality or blurry
           - Too short (under 1 minute) or too long (over 15 minutes)
           - Primarily text/slideshow format
           - News clips or controversial content

        IMPORTANT: You MUST return the response in this EXACT JSON format:
        ```json
        {
          "video_url": "https://www.youtube.com/watch?v=VIDEO_ID",
          "video_title": "Title of the video",
          "channel_name": "Name of the YouTube channel",
          "reason": "Brief explanation of why this video was selected"
        }
        ```

        If you cannot find a suitable video, return:
        ```json
        {
          "video_url": null,
          "video_title": null,
          "channel_name": null,
          "reason": "Explanation of why no suitable video was found"
        }
        ```

        Search now and provide the best YouTube video URL for this location.
      PROMPT
    end

    def build_location_details(location)
      details = []

      if location.description.present?
        # Use first 200 chars of description
        desc = location.translate(:description, :en) || location.description
        details << "Description: #{desc.to_s.truncate(200)}"
      end

      if location.location_categories.any?
        categories = location.location_categories.pluck(:name).join(", ")
        details << "Categories: #{categories}"
      elsif location.location_type.present?
        details << "Type: #{location.location_type.titleize}"
      end

      if location.tags.any?
        details << "Tags: #{location.tags.join(', ')}"
      end

      details.any? ? "LOCATION DETAILS:\n#{details.join("\n")}" : ""
    end

    def parse_video_response(response, location)
      return nil if response.nil? || response.content.blank?

      content = response.content.to_s

      # Extract JSON from response
      json_match = content.match(/```(?:json)?\s*([\s\S]*?)```/) ||
                   content.match(/(\{[\s\S]*?\})/)

      return nil unless json_match

      json_str = json_match[1].strip
      result = JSON.parse(json_str, symbolize_names: true)

      return nil if result[:video_url].nil? || result[:video_url].to_s.downcase == "null"

      {
        video_url: normalize_youtube_url(result[:video_url]),
        title: result[:video_title],
        channel: result[:channel_name],
        reason: result[:reason]
      }
    rescue JSON::ParserError => e
      Rails.logger.warn "[LocationVideoFinder] Failed to parse JSON response: #{e.message}"

      # Try to extract YouTube URL directly from text
      extract_youtube_url_from_text(content)
    end

    def extract_youtube_url_from_text(text)
      # Match various YouTube URL formats
      youtube_patterns = [
        %r{https?://(?:www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})},
        %r{https?://youtu\.be/([a-zA-Z0-9_-]{11})},
        %r{https?://(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})}
      ]

      youtube_patterns.each do |pattern|
        match = text.match(pattern)
        if match
          video_id = match[1]
          return {
            video_url: "https://www.youtube.com/watch?v=#{video_id}",
            title: nil,
            channel: nil,
            reason: "Extracted from search results"
          }
        end
      end

      nil
    end

    def normalize_youtube_url(url)
      return nil if url.blank?

      url = url.to_s.strip

      # Extract video ID from various formats
      video_id = case url
                 when %r{youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})}
                   Regexp.last_match(1)
                 when %r{youtu\.be/([a-zA-Z0-9_-]{11})}
                   Regexp.last_match(1)
                 when %r{youtube\.com/embed/([a-zA-Z0-9_-]{11})}
                   Regexp.last_match(1)
                 when /^([a-zA-Z0-9_-]{11})$/
                   Regexp.last_match(1)
                 end

      video_id ? "https://www.youtube.com/watch?v=#{video_id}" : nil
    end

    def valid_youtube_url?(url)
      return false if url.blank?

      url.to_s.match?(%r{^https://www\.youtube\.com/watch\?v=[a-zA-Z0-9_-]{11}$})
    end
  end
end
