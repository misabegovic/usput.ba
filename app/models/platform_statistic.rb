# frozen_string_literal: true

# PlatformStatistic - Cached statistike za Platform Knowledge Layer 0
#
# Čuva pre-computed statistike koje se refreshaju periodično.
# Ovo omogućava brz pristup statistikama bez računanja svaki put.
#
# Ključevi:
#   - "content_counts" - broj lokacija, iskustava, planova
#   - "by_city" - statistike po gradovima
#   - "coverage" - coverage metrrike
#   - "health" - health check rezultati
#   - "layer_zero" - kompletni Layer 0 za system prompt
#
class PlatformStatistic < ApplicationRecord
  # Validacije
  validates :key, presence: true, uniqueness: true

  # Scopes
  scope :fresh, ->(max_age = 5.minutes) { where("computed_at > ?", max_age.ago) }
  scope :stale, ->(max_age = 5.minutes) { where("computed_at <= ? OR computed_at IS NULL", max_age.ago) }

  class << self
    # Dohvati statistiku po ključu, računaj ako nije fresh
    def get(key, max_age: 5.minutes)
      stat = find_by(key: key)

      if stat&.fresh?(max_age)
        stat.value
      else
        # Lazy compute ako je stale
        compute_and_store(key)
      end
    end

    # Forsiraj recompute statistike
    def refresh(key)
      compute_and_store(key)
    end

    # Refreshaj sve statistike
    def refresh_all
      %w[content_counts by_city coverage health layer_zero].each do |key|
        compute_and_store(key)
      end
    end

    # Invalidate content-related stats (call when content changes)
    def invalidate_content_stats
      where(key: %w[content_counts by_city coverage layer_zero]).update_all(computed_at: nil)
    end

    # Dohvati kompletan Layer 0 za system prompt
    def layer_zero(max_age: 5.minutes)
      get("layer_zero", max_age: max_age)
    end

    private

    def compute_and_store(key)
      value = compute(key)
      stat = find_or_initialize_by(key: key)
      stat.update!(value: value, computed_at: Time.current)
      value
    end

    def compute(key)
      case key
      when "content_counts"
        compute_content_counts
      when "by_city"
        compute_by_city
      when "coverage"
        compute_coverage
      when "health"
        compute_health
      when "layer_zero"
        compute_layer_zero
      else
        {}
      end
    end

    def compute_content_counts
      {
        locations: Location.count,
        experiences: Experience.count,
        plans: Plan.count,
        audio_tours: AudioTour.count,
        reviews: Review.count,
        users: User.count,
        curators: User.curator.count
      }
    end

    def compute_by_city
      # Top 15 gradova po broju lokacija
      Location.group(:city)
              .count
              .sort_by { |_, v| -v }
              .first(15)
              .to_h
    end

    def compute_coverage
      total_locations = Location.count
      {
        cities_with_content: Location.distinct.pluck(:city).compact.size,
        locations_with_audio: Location.with_audio.count,
        locations_with_description: Location.where.not(description: [nil, ""]).count,
        locations_ai_generated: Location.ai_generated.count,
        locations_human_made: Location.human_made.count,
        audio_coverage_percent: total_locations > 0 ? (Location.with_audio.count * 100.0 / total_locations).round(1) : 0,
        description_coverage_percent: total_locations > 0 ? (Location.where.not(description: [nil, ""]).count * 100.0 / total_locations).round(1) : 0
      }
    end

    def compute_health
      {
        database: check_database,
        api_keys: check_api_keys,
        queues: check_queues,
        storage: check_storage,
        last_activity: check_last_activity
      }
    end

    def compute_layer_zero
      # Kompletni Layer 0 za system prompt (~2K tokena)
      {
        computed_at: Time.current.iso8601,
        stats: compute_content_counts,
        by_city: compute_by_city,
        coverage: compute_coverage,
        health: {
          api_keys: check_api_keys,
          queues: check_queues
        },
        top_rated: top_rated_content,
        recent_changes: recent_changes
      }
    end

    def check_database
      ActiveRecord::Base.connection.execute("SELECT 1")
      { status: "ok" }
    rescue => e
      { status: "error", message: e.message }
    end

    def check_api_keys
      {
        anthropic: ENV["ANTHROPIC_API_KEY"].present?,
        openai: ENV["OPENAI_API_KEY"].present?,
        geoapify: ENV["GEOAPIFY_API_KEY"].present?,
        elevenlabs: ENV["ELEVENLABS_API_KEY"].present?
      }
    end

    def check_queues
      {
        pending: SolidQueue::Job.where(finished_at: nil).count,
        failed_24h: SolidQueue::Job.where("created_at > ?", 24.hours.ago)
                                   .where.not(finished_at: nil)
                                   .count
      }
    rescue => e
      { status: "error", message: e.message }
    end

    def check_storage
      { service: ActiveStorage::Blob.service.class.name }
    rescue => e
      { status: "error", message: e.message }
    end

    def check_last_activity
      {
        last_location_update: Location.maximum(:updated_at)&.iso8601,
        last_experience_update: Experience.maximum(:updated_at)&.iso8601,
        last_review: Review.maximum(:created_at)&.iso8601
      }
    end

    def top_rated_content
      {
        locations: Location.where("average_rating > ?", 4.0)
                          .order(average_rating: :desc)
                          .limit(5)
                          .pluck(:id, :name, :city, :average_rating)
                          .map { |id, name, city, rating| { id: id, name: name, city: city, rating: rating } },
        experiences: Experience.where("average_rating > ?", 4.0)
                              .order(average_rating: :desc)
                              .limit(5)
                              .pluck(:id, :title, :average_rating)
                              .map { |id, title, rating| { id: id, title: title, rating: rating } }
      }
    end

    def recent_changes
      {
        new_locations_7d: Location.where("created_at > ?", 7.days.ago).count,
        new_reviews_7d: Review.where("created_at > ?", 7.days.ago).count,
        updated_locations_7d: Location.where("updated_at > ?", 7.days.ago)
                                      .where("updated_at != created_at")
                                      .count
      }
    end
  end

  # Instance metoda za provjeru freshness
  def fresh?(max_age = 5.minutes)
    computed_at.present? && computed_at > max_age.ago
  end

  def stale?(max_age = 5.minutes)
    !fresh?(max_age)
  end

  # Formatiranje za prikaz
  def to_formatted_s
    JSON.pretty_generate(value)
  end
end
