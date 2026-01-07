# frozen_string_literal: true

module Admin
  module Ai
    # Controller za upravljanje generiranjem audio tura
    # Odvojeno od glavnog AI generatora zbog troškova ElevenLabs API-ja
    class AudioToursController < Admin::BaseController
      # GET /admin/ai/audio_tours
      # Lista lokacija koje nemaju audio ture
      def index
        # Lokacije koje nemaju audio ture ili imaju audio ture bez audio fajla
        # Active Storage koristi audio_file_attachment tabelu
        locations_with_complete_audio = Location.joins(audio_tours: :audio_file_attachment).distinct

        @locations_without_audio = Location.with_coordinates
                                           .where.not(id: locations_with_complete_audio)
                                           .distinct
                                           .order(:city, :name)

        # Grupiši po gradu
        @locations_by_city = @locations_without_audio.group_by(&:city)

        # Statistika
        total_locations = Location.count
        locations_with_audio = Location.joins(:audio_tours)
                                       .merge(AudioTour.with_audio)
                                       .distinct.count

        @stats = {
          total_locations: total_locations,
          with_audio: locations_with_audio,
          without_audio: total_locations - locations_with_audio,
          coverage_percent: total_locations > 0 ? (locations_with_audio.to_f / total_locations * 100).round(1) : 0
        }

        # Procjena troška (ElevenLabs: ~$0.30 per 1000 characters)
        @cost_estimate = estimate_cost(@locations_without_audio)
      end

      # POST /admin/ai/audio_tours/generate
      # Generiše audio ture za odabrane lokacije
      def generate
        location_ids = params[:location_ids] || []
        locale = params[:locale] || "bs"
        force = params[:force] == "1"

        if location_ids.empty?
          redirect_to admin_ai_audio_tours_path, alert: t("admin.ai.audio_tours.no_locations_selected")
          return
        end

        locations = Location.where(id: location_ids)

        # Pokreni job za generiranje
        AudioTourGenerationJob.perform_later(
          location_ids: locations.pluck(:id),
          locale: locale,
          force: force
        )

        redirect_to admin_ai_audio_tours_path,
                    notice: t("admin.ai.audio_tours.generation_started", count: locations.count)
      end

      # GET /admin/ai/audio_tours/estimate (AJAX)
      # Procjena troška za odabrane lokacije
      def estimate
        location_ids = params[:location_ids] || []
        locations = Location.where(id: location_ids)

        estimate = estimate_cost(locations)

        render json: estimate
      end

      private

      def estimate_cost(locations)
        return { characters: 0, cost_usd: 0, cost_display: "$0.00" } if locations.empty?

        # Procjena: prosječno 2000 karaktera po lokaciji za audio script
        avg_chars_per_location = 2000
        total_chars = locations.count * avg_chars_per_location

        # ElevenLabs cijena: ~$0.30 per 1000 characters (Creator plan)
        # https://elevenlabs.io/pricing
        cost_per_1000_chars = 0.30
        cost_usd = (total_chars / 1000.0 * cost_per_1000_chars).round(2)

        {
          locations_count: locations.count,
          characters: total_chars,
          cost_usd: cost_usd,
          cost_display: "$#{format('%.2f', cost_usd)}"
        }
      end
    end
  end
end
