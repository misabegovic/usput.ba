# frozen_string_literal: true

# Background job za autonomno AI generiranje sadržaja
# Admin samo pokrene ovaj job - AI odlučuje SVE
#
# Koristi Ai::ContentOrchestrator za:
# - Analizu šta nedostaje u sistemu
# - Odlučivanje koje gradove obraditi
# - Prikupljanje lokacija putem Geoapify
# - Kreiranje Experience-a i Plan-ova
#
# NAPOMENA: Audio ture se NE generišu ovdje - pokreću se odvojeno
class ContentGenerationJob < ApplicationJob
  queue_as :ai_generation

  # Retry na privremene greške
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Ne retry-aj na konfiguracijse greške
  discard_on GeoapifyService::ConfigurationError
  discard_on RubyLLM::ConfigurationError if defined?(RubyLLM::ConfigurationError)
  discard_on Ai::ContentOrchestrator::GenerationError

  # @param max_locations [Integer, nil] Maksimalan broj lokacija za kreirati (nil = default 100, 0 = unlimited)
  # @param max_experiences [Integer, nil] Maksimalan broj Experience-a za kreirati (nil = default 200, 0 = unlimited)
  # @param max_plans [Integer, nil] Maksimalan broj planova za kreirati (nil = default 50, 0 = unlimited)
  # @param skip_locations [Boolean] Preskoči dohvat/kreiranje lokacija
  # @param skip_experiences [Boolean] Preskoči kreiranje iskustava
  # @param skip_plans [Boolean] Preskoči kreiranje planova
  def perform(max_locations: nil, max_experiences: nil, max_plans: nil, skip_locations: false, skip_experiences: false, skip_plans: false)
    Rails.logger.info "[ContentGenerationJob] Starting autonomous content generation"
    Rails.logger.info "[ContentGenerationJob] Max: locations=#{max_locations || 'default (100)'}, experiences=#{max_experiences || 'default (200)'}, plans=#{max_plans || 'default (50)'}"
    Rails.logger.info "[ContentGenerationJob] Skip: locations=#{skip_locations}, experiences=#{skip_experiences}, plans=#{skip_plans}"

    # Provjeri da li je već u toku generiranje
    current_status = Ai::ContentOrchestrator.current_status
    if current_status[:status] == "in_progress"
      Rails.logger.warn "[ContentGenerationJob] Generation already in progress, skipping"
      return
    end

    begin
      orchestrator = Ai::ContentOrchestrator.new(
        max_locations: max_locations,
        max_experiences: max_experiences,
        max_plans: max_plans,
        skip_locations: skip_locations,
        skip_experiences: skip_experiences,
        skip_plans: skip_plans
      )
      results = orchestrator.generate

      Rails.logger.info "[ContentGenerationJob] Generation complete!"
      Rails.logger.info "[ContentGenerationJob] Results: #{results.slice(:locations_created, :experiences_created, :plans_created)}"

      # Pošalji notifikaciju ako je konfigurisano
      notify_completion(results) if should_notify?

      results
    rescue Ai::ContentOrchestrator::GenerationError => e
      Rails.logger.error "[ContentGenerationJob] Generation failed: #{e.message}"
      notify_failure(e) if should_notify?
      raise
    end
  end

  private

  def should_notify?
    Setting.get("ai.notify_on_completion", default: false)
  end

  def notify_completion(results)
    # Placeholder za notifikacije (email, Slack, etc.)
    # Implementiraj prema potrebi
    Rails.logger.info "[ContentGenerationJob] Would notify completion: #{results}"
  end

  def notify_failure(error)
    # Placeholder za notifikacije o greškama
    Rails.logger.error "[ContentGenerationJob] Would notify failure: #{error.message}"
  end
end
