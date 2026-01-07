module Curator
  class DashboardController < BaseController
    def index
      @stats = {
        # Basic counts
        locations_count: Location.count,
        experiences_count: Experience.count,
        cities_count: Location.distinct.count(:city),
        plans_count: Plan.public_plans.count,

        # Reviews stats
        reviews_count: Review.count,
        average_rating: Review.average(:rating)&.round(2) || 0,
        pending_reviews: Review.where("created_at > ?", 7.days.ago).count,

        # Audio tours stats
        audio_tours_count: AudioTour.count,
        audio_tours_with_audio: AudioTour.with_audio.count,
        locations_with_audio: AudioTour.distinct.count(:location_id),
        audio_coverage_percent: calculate_audio_coverage,

        # Recent items
        recent_locations: Location.order(created_at: :desc).limit(5),
        recent_experiences: Experience.order(created_at: :desc).limit(5),
        recent_reviews: Review.includes(:reviewable, :user).order(created_at: :desc).limit(5),
        recent_plans: Plan.public_plans.includes(:user).order(created_at: :desc).limit(5)
      }
    end

    private

    def calculate_audio_coverage
      total_locations = Location.count
      return 0 if total_locations.zero?

      locations_with_audio = AudioTour.distinct.count(:location_id)
      ((locations_with_audio.to_f / total_locations) * 100).round(1)
    end
  end
end
