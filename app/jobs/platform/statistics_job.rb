# frozen_string_literal: true

module Platform
  # StatisticsJob - Periodično osvježava Platform statistike
  #
  # Koristi PlatformStatistic model za caching statistika.
  # Pokreće se svakih 5 minuta kroz Solid Queue recurring.
  #
  # Manual trigger:
  #   Platform::StatisticsJob.perform_now
  #   Platform::StatisticsJob.perform_later
  #
  class StatisticsJob < ApplicationJob
    queue_as :default

    # Ne retry-aj previše često - statistike nisu kritične
    retry_on StandardError, wait: 1.minute, attempts: 3

    def perform(keys: nil)
      Rails.logger.info "[Platform::StatisticsJob] Refreshing statistics..."

      if keys.present?
        # Refresh specific keys
        Array(keys).each do |key|
          PlatformStatistic.refresh(key)
          Rails.logger.info "[Platform::StatisticsJob] Refreshed: #{key}"
        end
      else
        # Refresh all statistics
        PlatformStatistic.refresh_all
        Rails.logger.info "[Platform::StatisticsJob] Refreshed all statistics"
      end

      log_summary
    end

    private

    def log_summary
      stats = PlatformStatistic.find_by(key: "content_counts")
      return unless stats

      counts = stats.value || {}
      Rails.logger.info "[Platform::StatisticsJob] Current counts: " \
                        "locations=#{counts['locations'] || counts[:locations]}, " \
                        "experiences=#{counts['experiences'] || counts[:experiences]}, " \
                        "reviews=#{counts['reviews'] || counts[:reviews]}"
    end
  end
end
