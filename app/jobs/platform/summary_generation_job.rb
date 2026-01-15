# frozen_string_literal: true

module Platform
  # SummaryGenerationJob - Generiše Knowledge Layer 1 summary-je
  #
  # Može generisati summary za:
  # - Specifičan grad: SummaryGenerationJob.perform_later(dimension: "city", value: "Mostar")
  # - Sve gradove: SummaryGenerationJob.perform_later(dimension: "city")
  # - Sve kategorije: SummaryGenerationJob.perform_later(dimension: "category")
  # - Sve dimenzije: SummaryGenerationJob.perform_later
  #
  class SummaryGenerationJob < ApplicationJob
    queue_as :default

    # Ne retry-aj previše - summary generacija nije kritična
    retry_on StandardError, wait: 5.minutes, attempts: 2

    def perform(dimension: nil, value: nil)
      Rails.logger.info "[SummaryGenerationJob] Starting summary generation..."

      if dimension.present? && value.present?
        # Generiši samo jedan summary
        generate_single(dimension, value)
      elsif dimension.present?
        # Generiši sve summary-je za dimenziju
        generate_for_dimension(dimension)
      else
        # Generiši sve summary-je za sve dimenzije
        generate_all
      end

      Rails.logger.info "[SummaryGenerationJob] Summary generation complete."
    end

    private

    def generate_single(dimension, value)
      Rails.logger.info "[SummaryGenerationJob] Generating summary for #{dimension}=#{value}"

      summary = Knowledge::LayerOne.generate_summary(dimension, value)

      if summary
        Rails.logger.info "[SummaryGenerationJob] Generated: #{summary.to_short_format}"
      else
        Rails.logger.warn "[SummaryGenerationJob] No data for #{dimension}=#{value}"
      end
    end

    def generate_for_dimension(dimension)
      Rails.logger.info "[SummaryGenerationJob] Generating all summaries for dimension=#{dimension}"

      case dimension.to_s
      when "city"
        cities = Location.distinct.pluck(:city).compact
        Rails.logger.info "[SummaryGenerationJob] Found #{cities.size} cities"

        cities.each do |city|
          generate_single("city", city)
        end
      when "category"
        categories = LocationCategory.pluck(:key)
        Rails.logger.info "[SummaryGenerationJob] Found #{categories.size} categories"

        categories.each do |category|
          generate_single("category", category)
        end
      else
        Rails.logger.warn "[SummaryGenerationJob] Unknown dimension: #{dimension}"
      end
    end

    def generate_all
      Rails.logger.info "[SummaryGenerationJob] Generating all summaries for all dimensions"

      generate_for_dimension("city")
      generate_for_dimension("category")

      log_summary
    end

    def log_summary
      total = KnowledgeSummary.count
      with_issues = KnowledgeSummary.with_issues.count

      Rails.logger.info "[SummaryGenerationJob] Total summaries: #{total}, with issues: #{with_issues}"
    end
  end
end
