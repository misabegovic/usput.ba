# Background job for country-wide AI location and experience generation
# Uses the CountryWideLocationGenerator service
class CountryWideGenerationJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on GeoapifyService::ConfigurationError
  discard_on RubyLLM::ConfigurationError if defined?(RubyLLM::ConfigurationError)

  # @param mode [String] Generation mode: "all", "region", "category", "hidden_gems",
  #                      "experiences", "experiences_region", "experiences_cross_region"
  # @param options [Hash] Additional options depending on mode
  def perform(mode:, **options)
    generator = Ai::CountryWideLocationGenerator.new(
      generate_audio: options[:generate_audio] || false,
      audio_locale: options[:audio_locale] || "bs",
      generate_experiences: options[:generate_experiences] || false
    )

    result = case mode
    when "all"
      Rails.logger.info "[CountryWideGenerationJob] Starting generation for all regions"
      generator.generate_all
    when "region"
      region = options[:region]
      Rails.logger.info "[CountryWideGenerationJob] Starting generation for region: #{region}"
      generator.generate_for_region(region)
    when "category"
      category = options[:category]
      Rails.logger.info "[CountryWideGenerationJob] Starting generation for category: #{category}"
      generator.generate_by_category(category)
    when "hidden_gems"
      count = options[:count] || 15
      Rails.logger.info "[CountryWideGenerationJob] Starting hidden gems discovery: #{count} locations"
      generator.discover_hidden_gems(count: count)
    when "experiences"
      Rails.logger.info "[CountryWideGenerationJob] Starting country-wide experience generation"
      generator.generate_experiences
    when "experiences_region"
      region = options[:region]
      Rails.logger.info "[CountryWideGenerationJob] Starting experience generation for region: #{region}"
      generator.generate_experiences_for_region(region)
    when "experiences_cross_region"
      Rails.logger.info "[CountryWideGenerationJob] Starting cross-region experience generation"
      generator.generate_cross_region_experiences
    else
      raise ArgumentError, "Unknown generation mode: #{mode}"
    end

    log_completion(result)
    result
  end

  private

  def log_completion(result)
    parts = []
    parts << "#{result[:locations_created]} locations" if result[:locations_created]&.positive?
    parts << "#{result[:cities_created]} cities" if result[:cities_created]&.positive?
    parts << "#{result[:experiences_created]} experiences" if result[:experiences_created]&.positive?

    Rails.logger.info "[CountryWideGenerationJob] Completed: #{parts.join(", ")} created"
  end
end
