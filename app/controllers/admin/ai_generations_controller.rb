module Admin
  # Controller for viewing AI generation history
  class AiGenerationsController < BaseController
    # GET /admin/ai_generations
    # List all AI generation jobs with their status
    def index
      @generations = AiGeneration.recent.page(params[:page]).per(20)

      @stats = {
        pending: AiGeneration.pending.count,
        processing: AiGeneration.processing.count,
        completed: AiGeneration.completed.count,
        failed: AiGeneration.failed.count
      }

      @content_stats = {
        total_locations: Location.count,
        locations_with_audio: Location.joins(:audio_tours).distinct.count,
        distinct_cities: Location.where.not(city: [nil, ""]).distinct.pluck(:city).count,
        total_experiences: Experience.count
      }
    end

    # POST /admin/ai_generations/:id/retry
    # Retry a failed generation
    def retry
      generation = AiGeneration.failed.find(params[:id])

      generation.update!(status: :pending, error_message: nil, started_at: nil, completed_at: nil)
      AiGenerationJob.perform_later(generation.city_name, generation_type: generation.generation_type)

      redirect_to admin_ai_generations_path,
        notice: "Retrying generation for #{generation.city_name}"
    end
  end
end
